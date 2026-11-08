import Foundation
import Observation

/// Choose where to move an item or a location. The whole hierarchy is shown as an indented list
/// with a filter field; the current place is marked and places that are not allowed are disabled.
@Observable
final class LocationPickerViewModel {
    enum Target: Hashable {
        case topLevel
        case location(UUID)
    }

    /// What is being moved — decides which targets are allowed.
    enum Subject {
        /// An item can go into any location, but not to the top level.
        case item
        /// A location can go to the top level or anywhere except into itself or its own sub-locations.
        case location(UUID)
    }

    struct Row: Identifiable, Equatable {
        let target: Target
        let title: String
        /// Parent path, shown while filtering (the indentation is gone then).
        let subtitle: String?
        let depth: Int
        let kind: LocationKind?
        let isCurrent: Bool
        let isDisabled: Bool

        var id: Target { target }
    }

    var query = ""
    private(set) var selection: Target?
    var alert: AlertState?

    let subjectName: String
    let showsCancel: Bool

    private let current: Target?
    private let allRows: [Row]
    private let entriesByID: [UUID: (title: String, kind: LocationKind, parentPath: String)]
    private let apply: (Target) throws -> Void
    private let close: () -> Void

    init(
        subjectName: String,
        subject: Subject,
        current: Target?,
        inventory: InventoryService,
        showsCancel: Bool,
        apply: @escaping (Target) throws -> Void,
        close: @escaping () -> Void
    ) {
        self.subjectName = subjectName
        self.current = current
        self.showsCancel = showsCancel
        self.apply = apply
        self.close = close

        let entries = (try? inventory.locationTree()) ?? []
        var rows: [Row] = []
        var byID: [UUID: (String, LocationKind, String)] = [:]
        if case .location = subject {
            rows.append(Row(target: .topLevel, title: String(localized: "Top Level", comment: "Move target: no parent location"), subtitle: nil, depth: 0, kind: nil, isCurrent: current == .topLevel, isDisabled: current == .topLevel))
        }
        for entry in entries {
            let location = entry.location
            let target = Target.location(location.id)
            let isAllowed: Bool
            switch subject {
            case .item: isAllowed = true
            case .location(let movingID): isAllowed = inventory.canMove(locationID: movingID, toParentID: location.id)
            }
            let isCurrent = current == target
            rows.append(Row(target: target, title: location.name, subtitle: nil, depth: entry.depth, kind: location.kind, isCurrent: isCurrent, isDisabled: isCurrent || !isAllowed))
            byID[location.id] = (location.name, location.kind, inventory.path(to: location).dropLast().map(\.name).joined(separator: " › "))
        }
        self.allRows = rows
        self.entriesByID = byID.mapValues { (title: $0.0, kind: $0.1, parentPath: $0.2) }
    }

    /// The tree, or a flat filtered list with parent paths while the filter is used.
    var rows: [Row] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return allRows }
        return allRows.compactMap { row in
            guard case .location(let id) = row.target, let entry = entriesByID[id], entry.title.localizedStandardContains(text) else { return nil }
            return Row(target: row.target, title: row.title, subtitle: entry.parentPath.isEmpty ? nil : entry.parentPath, depth: 0, kind: row.kind, isCurrent: row.isCurrent, isDisabled: row.isDisabled)
        }
    }

    var prompt: String {
        String(localized: "Choose a new place for “\(subjectName)”.", comment: "Move picker header; the argument is the item or location name")
    }

    var canConfirm: Bool {
        guard let selection else { return false }
        return selection != current
    }

    var confirmTitle: String {
        switch selection {
        case .location(let id):
            let name = entriesByID[id]?.title ?? ""
            return String(localized: "Move to “\(name)”", comment: "Move picker confirm button; the argument is the target location name")
        case .topLevel:
            return String(localized: "Move to Top Level", comment: "Move picker confirm button for the top level")
        case nil:
            return String(localized: "Move", comment: "Move action")
        }
    }

    func select(_ row: Row) {
        guard !row.isDisabled else { return }
        selection = row.target
    }

    func confirm() {
        guard let selection, canConfirm else { return }
        do {
            try apply(selection)
            close()
        } catch {
            alert = .error(error)
        }
    }

    func cancel() {
        close()
    }
}
