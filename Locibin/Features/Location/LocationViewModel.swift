import Foundation
import Observation

/// One storage location: what is inside, quick item entry and the location's actions.
@Observable
final class LocationViewModel {
    struct Content: Equatable {
        var title: String
        /// "Rack · Garage › Rack 1" — kind, then where the location is.
        var header: String
        var kind: LocationKind
        var sublocations: [LocationRowData]
        var items: [ItemRowData]

        var isEmpty: Bool { sublocations.isEmpty && items.isEmpty }
    }

    enum State: Equatable {
        case loaded(Content)
        /// The location was deleted (for example on another screen) or never existed.
        case missing
    }

    let locationID: UUID
    private(set) var state: State = .missing
    var quickAddText = ""
    var alert: AlertState?
    /// An item found by search; highlighted briefly when the screen opens.
    private(set) var highlightedItemID: UUID?

    static let highlightDuration: Duration = .seconds(1.5)

    private let inventory: InventoryService
    private let router: AppRouter
    private let formatter: ContentsFormatter
    private let locale: Locale
    @ObservationIgnored private var storeObservation: StoreObservation?

    init(
        locationID: UUID,
        highlightedItemID: UUID? = nil,
        inventory: InventoryService,
        router: AppRouter,
        storeChanges: StoreChanges,
        locale: Locale = .current
    ) {
        self.locationID = locationID
        self.highlightedItemID = highlightedItemID
        self.inventory = inventory
        self.router = router
        self.locale = locale
        self.formatter = ContentsFormatter(locale: locale)
        reload()
        storeObservation = storeChanges.observe { [weak self] in self?.reload() }
    }

    func reload() {
        do {
            guard let location = try inventory.location(id: locationID) else {
                state = .missing
                return
            }
            state = .loaded(content(for: location))
        } catch {
            alert = .error(error)
        }
    }

    /// Adds the typed item and clears the field so the next one can be typed right away.
    /// A blank field is ignored silently — pressing Return on it is not an error.
    func submitQuickAdd() {
        guard !quickAddText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            quickAddText = ""
            return
        }
        do {
            try inventory.addItem(name: quickAddText, toLocationID: locationID)
            quickAddText = ""
        } catch {
            alert = .error(error)
        }
    }

    func itemTapped(id: UUID) {
        router.present(.editItem(id))
    }

    func moveItemTapped(id: UUID) {
        router.present(.moveItem(id))
    }

    func moveTapped() {
        router.present(.moveLocation(locationID))
    }

    func moveSublocationTapped(id: UUID) {
        router.present(.moveLocation(id))
    }

    /// Called once the highlighted item is on screen; the highlight fades after a moment.
    func highlightShown() async {
        guard highlightedItemID != nil else { return }
        try? await Task.sleep(for: Self.highlightDuration)
        clearHighlight()
    }

    func clearHighlight() {
        highlightedItemID = nil
    }

    func addSublocationTapped() {
        router.present(.newLocation(parentID: locationID))
    }

    func editTapped() {
        router.present(.editLocation(locationID))
    }

    func deleteItem(id: UUID) {
        do {
            try inventory.deleteItem(id: id)
        } catch {
            alert = .error(error)
        }
    }

    func deleteTapped() {
        confirmDeletion(of: locationID) { [weak self] in
            guard let self else { return }
            router.closeLocation(id: locationID)
        }
    }

    func deleteSublocationTapped(id: UUID) {
        confirmDeletion(of: id) {}
    }

    // MARK: - Private

    private func confirmDeletion(of id: UUID, afterDelete: @escaping () -> Void) {
        do {
            guard let location = try inventory.location(id: id) else { return reload() }
            alert = DeleteConfirmation.location(
                named: location.name,
                contents: inventory.totalContents(of: location),
                formatter: formatter
            ) { [weak self] in
                guard let self else { return }
                do {
                    try inventory.deleteLocation(id: id)
                    afterDelete()
                } catch {
                    alert = .error(error)
                }
            }
        } catch {
            alert = .error(error)
        }
    }

    private func content(for location: StorageLocation) -> Content {
        let kindTitle = String(localized: location.kind.title)
        let parents = inventory.path(to: location).dropLast().map(\.name)
        let header = parents.isEmpty ? kindTitle : kindTitle + " · " + parents.joined(separator: " › ")
        return Content(
            title: location.name,
            header: header,
            kind: location.kind,
            sublocations: inventory.children(of: location).map { LocationRowData($0, inventory: inventory, formatter: formatter) },
            items: inventory.items(in: location).map { ItemRowData($0, locale: locale) }
        )
    }
}
