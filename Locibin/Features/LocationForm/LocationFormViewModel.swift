import Foundation
import Observation

/// Create or edit a location. Edits a draft; nothing is saved until "Done".
@Observable
final class LocationFormViewModel: UnsavedChangesGuard {
    enum Mode: Equatable {
        case create(parentID: UUID?)
        case edit(UUID)
    }

    let mode: Mode
    var name: String
    var kind: LocationKind
    var alert: AlertState?

    /// "Inside: Garage › Rack 1", or nil for a top-level location.
    private(set) var parentPathText: String?

    private let originalName: String
    private let originalKind: LocationKind
    private let inventory: InventoryService
    private let router: AppRouter

    init(mode: Mode, inventory: InventoryService, router: AppRouter) {
        self.mode = mode
        self.inventory = inventory
        self.router = router

        var name = ""
        var kind = LocationKind.box
        var parent: StorageLocation?
        switch mode {
        case .create(let parentID):
            parent = parentID.flatMap { try? inventory.location(id: $0) }
            kind = parent == nil ? .room : .box
        case .edit(let id):
            if let location = try? inventory.location(id: id) {
                name = location.name
                kind = location.kind
                parent = location.parent
            }
        }
        self.name = name
        self.kind = kind
        self.originalName = name
        self.originalKind = kind
        self.parentPathText = parent.map { parent in
            let path = inventory.path(to: parent).map(\.name).joined(separator: " › ")
            return String(localized: "Inside: \(path)", comment: "Form footer: where the location is; the argument is a path like 'Garage › Rack 1'")
        }
        router.activeForm = self
    }

    var title: String {
        switch mode {
        case .create: String(localized: "New Place", comment: "Location form title when creating")
        case .edit: String(localized: "Edit Place", comment: "Location form title when editing")
        }
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasUnsavedChanges: Bool {
        name != originalName || kind != originalKind
    }

    func save() {
        do {
            switch mode {
            case .create(let parentID):
                let location = try inventory.createLocation(name: name, kind: kind, parentID: parentID)
                router.dismissSheet()
                // A new top-level place opens right away; a nested one just appears in its parent's list.
                if parentID == nil {
                    router.showLocation(id: location.id)
                }
            case .edit(let id):
                try inventory.updateLocation(id: id, name: name, kind: kind)
                router.dismissSheet()
            }
        } catch {
            alert = .error(error)
        }
    }

    func cancelTapped() {
        guard hasUnsavedChanges else { return router.dismissSheet() }
        alert = .discardChanges { [weak self] in self?.router.dismissSheet() }
    }
}

extension AlertState {
    /// Asked when closing a form that has unsaved changes.
    static func discardChanges(onDiscard: @escaping () -> Void) -> AlertState {
        AlertState(
            title: String(localized: "Discard Changes?", comment: "Alert title when closing a form with unsaved changes"),
            actions: [
                Action(title: String(localized: "Discard", comment: "Destructive button: close the form without saving"), role: .destructive, handler: onDiscard),
                Action(title: String(localized: "Keep Editing", comment: "Button: stay in the form"), role: .cancel),
            ]
        )
    }
}
