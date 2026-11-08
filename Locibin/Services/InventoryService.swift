import Foundation
import OSLog
import SwiftData

/// How much a location holds.
struct LocationContents: Equatable {
    /// Sub-locations. For a row this is the direct children; for deletion — every nested level.
    var locations: Int
    /// Items in the location and in every nested location.
    var items: Int
}

/// One line of the whole hierarchy flattened for a picker.
struct LocationTreeEntry {
    let location: StorageLocation
    let depth: Int
}

/// Result of a search over items and locations.
struct InventorySearchResults {
    var items: [Item]
    var locations: [StorageLocation]

    var isEmpty: Bool { items.isEmpty && locations.isEmpty }
}

/// All rules for places and items: creating, editing, moving, deleting, counting, paths and search.
/// ViewModels call it; it knows nothing about screens. Every change is saved explicitly,
/// and a failed save is rolled back so the store never stays half-changed.
final class InventoryService {
    /// Guards against corrupted data with a parent cycle; real hierarchies are a few levels deep.
    static let maxDepth = 64

    private let context: ModelContext
    private let now: () -> Date

    init(context: ModelContext, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.now = now
    }

    // MARK: - Reading

    /// Top-level locations, naturally sorted ("Shelf 2" before "Shelf 10").
    func rootLocations() throws -> [StorageLocation] {
        let descriptor = FetchDescriptor<StorageLocation>(predicate: #Predicate { $0.parent == nil })
        return Self.sortedNaturally(try context.fetch(descriptor))
    }

    func location(id: UUID) throws -> StorageLocation? {
        var descriptor = FetchDescriptor<StorageLocation>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func item(id: UUID) throws -> Item? {
        var descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Direct sub-locations, naturally sorted.
    func children(of location: StorageLocation) -> [StorageLocation] {
        Self.sortedNaturally(location.children ?? [])
    }

    /// Items directly in the location, in the order they were added — new items appear at the bottom.
    func items(in location: StorageLocation) -> [Item] {
        (location.items ?? []).sorted { lhs, rhs in
            lhs.createdAt == rhs.createdAt ? lhs.id.uuidString < rhs.id.uuidString : lhs.createdAt < rhs.createdAt
        }
    }

    /// Every location, depth-first in natural order: a parent is followed by its children.
    func locationTree() throws -> [LocationTreeEntry] {
        var entries: [LocationTreeEntry] = []
        var stack = try rootLocations().reversed().map { LocationTreeEntry(location: $0, depth: 0) }
        while let entry = stack.popLast() {
            entries.append(entry)
            guard entry.depth < Self.maxDepth else { continue }
            stack.append(contentsOf: children(of: entry.location).reversed().map { LocationTreeEntry(location: $0, depth: entry.depth + 1) })
        }
        return entries
    }

    /// Locations from the top level down to `location` itself.
    func path(to location: StorageLocation) -> [StorageLocation] {
        var path = [location]
        var current = location.parent
        while let parent = current, path.count < Self.maxDepth {
            path.insert(parent, at: 0)
            current = parent.parent
        }
        return path
    }

    /// For a list row: direct sub-locations and all items inside, at any depth.
    func rowContents(of location: StorageLocation) -> LocationContents {
        LocationContents(locations: location.children?.count ?? 0, items: totalContents(of: location).items)
    }

    /// For the delete confirmation: everything that will be deleted together with the location.
    func totalContents(of location: StorageLocation) -> LocationContents {
        var result = LocationContents(locations: 0, items: 0)
        var stack = [(location, 0)]
        while let (current, depth) = stack.popLast() {
            result.items += current.items?.count ?? 0
            guard depth < Self.maxDepth else { continue }
            for child in current.children ?? [] {
                result.locations += 1
                stack.append((child, depth + 1))
            }
        }
        return result
    }

    /// Case- and diacritic-insensitive search by name; "елка" also finds "Ёлка".
    func search(_ query: String) throws -> InventorySearchResults {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return InventorySearchResults(items: [], locations: []) }

        let items = try context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.name.localizedStandardContains(text) }))
        let locations = try context.fetch(FetchDescriptor<StorageLocation>(predicate: #Predicate { $0.name.localizedStandardContains(text) }))
        return InventorySearchResults(
            items: items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
            locations: Self.sortedNaturally(locations)
        )
    }

    /// Whether `location` may be moved under `newParentID` (`nil` = top level).
    func canMove(locationID: UUID, toParentID newParentID: UUID?) -> Bool {
        guard let newParentID else { return true }
        guard let target = try? location(id: newParentID) else { return false }
        return !isLocation(target, insideLocationWithID: locationID)
    }

    // MARK: - Locations

    @discardableResult
    func createLocation(name: String, kind: LocationKind, parentID: UUID?) throws -> StorageLocation {
        let name = try Self.validatedName(name)
        let parent = try parentID.map { try requireLocation(id: $0) }
        let location = StorageLocation(name: name, kind: kind, parent: parent, createdAt: now())
        context.insert(location)
        try save()
        return location
    }

    func updateLocation(id: UUID, name: String, kind: LocationKind) throws {
        let name = try Self.validatedName(name)
        let location = try requireLocation(id: id)
        location.name = name
        location.kind = kind
        location.updatedAt = now()
        try save()
    }

    func moveLocation(id: UUID, toParentID newParentID: UUID?) throws {
        let location = try requireLocation(id: id)
        let newParent = try newParentID.map { try requireLocation(id: $0) }
        if let newParent, isLocation(newParent, insideLocationWithID: id) {
            throw InventoryError.moveIntoItself
        }
        location.parent = newParent
        location.updatedAt = now()
        try save()
    }

    /// Deletes the location with everything inside. Show `totalContents(of:)` to the user first.
    func deleteLocation(id: UUID) throws {
        context.delete(try requireLocation(id: id))
        try save()
    }

    // MARK: - Items

    @discardableResult
    func addItem(name: String, quantity: Int? = nil, note: String? = nil, toLocationID locationID: UUID) throws -> Item {
        let name = try Self.validatedName(name)
        let quantity = try Self.validatedQuantity(quantity)
        let location = try requireLocation(id: locationID)
        let item = Item(name: name, quantity: quantity, note: Self.normalizedNote(note), location: location, createdAt: now())
        context.insert(item)
        try save()
        return item
    }

    func updateItem(id: UUID, name: String, quantity: Int?, note: String?) throws {
        let name = try Self.validatedName(name)
        let quantity = try Self.validatedQuantity(quantity)
        let item = try requireItem(id: id)
        item.name = name
        item.quantity = quantity
        item.note = Self.normalizedNote(note)
        item.updatedAt = now()
        try save()
    }

    func moveItem(id: UUID, toLocationID locationID: UUID) throws {
        let item = try requireItem(id: id)
        item.location = try requireLocation(id: locationID)
        item.updatedAt = now()
        try save()
    }

    func deleteItem(id: UUID) throws {
        context.delete(try requireItem(id: id))
        try save()
    }

    // MARK: - Helpers

    private func requireLocation(id: UUID) throws -> StorageLocation {
        guard let location = try location(id: id) else { throw InventoryError.locationNotFound }
        return location
    }

    private func requireItem(id: UUID) throws -> Item {
        guard let item = try item(id: id) else { throw InventoryError.itemNotFound }
        return item
    }

    /// True if `candidate` is the location with `id` or lies anywhere inside it.
    private func isLocation(_ candidate: StorageLocation, insideLocationWithID id: UUID) -> Bool {
        var current: StorageLocation? = candidate
        var depth = 0
        while let location = current, depth <= Self.maxDepth {
            if location.id == id { return true }
            current = location.parent
            depth += 1
        }
        return false
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            Logger.data.error("Save failed: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            throw InventoryError.saveFailed
        }
    }

    private static func validatedName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw InventoryError.emptyName }
        return trimmed
    }

    private static func validatedQuantity(_ quantity: Int?) throws -> Int? {
        guard let quantity else { return nil }
        guard quantity >= 1 else { throw InventoryError.invalidQuantity }
        return quantity
    }

    private static func normalizedNote(_ note: String?) -> String? {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func sortedNaturally(_ locations: [StorageLocation]) -> [StorageLocation] {
        locations.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
