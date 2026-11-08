import Foundation
import Observation

/// Global search on the main screen over item and place names.
/// Answers "where is it?": every result shows its full path.
@Observable
final class SearchViewModel {
    struct ItemResult: Identifiable, Equatable {
        let id: UUID
        let title: String
        /// "Garage › Rack 1 › Shelf 1" — where the item lies.
        let pathText: String
        let locationID: UUID
    }

    struct LocationResult: Identifiable, Equatable {
        let id: UUID
        let title: String
        /// Parent path, or the kind for a top-level place.
        let subtitle: String
        let kind: LocationKind
    }

    var query = "" {
        didSet { runSearch() }
    }
    private(set) var items: [ItemResult] = []
    private(set) var locations: [LocationResult] = []
    var alert: AlertState?

    private let inventory: InventoryService
    private let router: AppRouter
    @ObservationIgnored private var storeObservation: StoreObservation?

    init(inventory: InventoryService, router: AppRouter, storeChanges: StoreChanges) {
        self.inventory = inventory
        self.router = router
        storeObservation = storeChanges.observe { [weak self] in self?.runSearch() }
    }

    var isActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasNoResults: Bool {
        isActive && items.isEmpty && locations.isEmpty
    }

    /// Opens the item's location with the item highlighted.
    func select(_ item: ItemResult) {
        router.showLocation(id: item.locationID, highlightingItem: item.id)
    }

    func select(_ location: LocationResult) {
        router.showLocation(id: location.id)
    }

    private func runSearch() {
        guard isActive else {
            items = []
            locations = []
            return
        }
        do {
            let results = try inventory.search(query)
            items = results.items.compactMap { item in
                guard let location = item.location else { return nil }
                return ItemResult(id: item.id, title: item.name, pathText: pathText(to: location), locationID: location.id)
            }
            locations = results.locations.map { location in
                let parents = inventory.path(to: location).dropLast()
                let subtitle = parents.isEmpty ? String(localized: location.kind.title) : parents.map(\.name).joined(separator: " › ")
                return LocationResult(id: location.id, title: location.name, subtitle: subtitle, kind: location.kind)
            }
        } catch {
            alert = .error(error)
        }
    }

    private func pathText(to location: StorageLocation) -> String {
        inventory.path(to: location).map(\.name).joined(separator: " › ")
    }
}
