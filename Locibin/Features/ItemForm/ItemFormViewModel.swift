import Foundation
import Observation

/// Edit an item: name, optional quantity and note. Items are created by quick add on the location screen.
@Observable
final class ItemFormViewModel {
    struct Draft: Equatable {
        var name = ""
        var quantity: Int?
        var note = ""
    }

    let itemID: UUID
    var draft: Draft
    var alert: AlertState?
    /// "Garage › Rack 1 › Shelf 1".
    private(set) var locationPathText = ""
    private(set) var isMissing = false

    private let original: Draft
    private let inventory: InventoryService
    private let router: AppRouter
    private let locale: Locale

    static let maxQuantity = 9_999

    init(itemID: UUID, inventory: InventoryService, router: AppRouter, locale: Locale = .current) {
        self.itemID = itemID
        self.inventory = inventory
        self.router = router
        self.locale = locale

        var draft = Draft()
        if let item = try? inventory.item(id: itemID) {
            draft = Draft(name: item.name, quantity: item.quantity, note: item.note ?? "")
            if let location = item.location {
                locationPathText = inventory.path(to: location).map(\.name).joined(separator: " › ")
            }
        } else {
            isMissing = true
        }
        self.draft = draft
        self.original = draft
    }

    var canSave: Bool {
        !isMissing && !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasUnsavedChanges: Bool {
        draft != original
    }

    var quantityText: String {
        draft.quantity.map { $0.formatted(.number.locale(locale)) }
            ?? String(localized: "Not specified", comment: "Quantity value when no quantity is set")
    }

    var canDecreaseQuantity: Bool { draft.quantity != nil }
    var canIncreaseQuantity: Bool { (draft.quantity ?? 0) < Self.maxQuantity }

    /// Not specified → 1 → 2 …
    func increaseQuantity() {
        draft.quantity = min((draft.quantity ?? 0) + 1, Self.maxQuantity)
    }

    /// … 2 → 1 → not specified.
    func decreaseQuantity() {
        guard let quantity = draft.quantity else { return }
        draft.quantity = quantity > 1 ? quantity - 1 : nil
    }

    func save() {
        do {
            try inventory.updateItem(id: itemID, name: draft.name, quantity: draft.quantity, note: draft.note)
            router.dismissSheet()
        } catch {
            alert = .error(error)
        }
    }

    func cancelTapped() {
        guard hasUnsavedChanges else { return router.dismissSheet() }
        alert = .discardChanges { [weak self] in self?.router.dismissSheet() }
    }

    func deleteTapped() {
        alert = AlertState(
            title: String(localized: "Delete “\(original.name)”?", comment: "Delete confirmation title; the argument is the location name"),
            message: String(localized: "This can't be undone.", comment: "Delete confirmation message for an empty location"),
            actions: [
                .cancel(),
                AlertState.Action(title: String(localized: "Delete", comment: "Destructive button"), role: .destructive) { [weak self] in
                    self?.delete()
                },
            ]
        )
    }

    private func delete() {
        do {
            try inventory.deleteItem(id: itemID)
            router.dismissSheet()
        } catch {
            alert = .error(error)
        }
    }
}
