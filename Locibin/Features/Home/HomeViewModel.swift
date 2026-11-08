import Foundation
import Observation

/// Main screen: the list of top-level places.
@Observable
final class HomeViewModel {
    private(set) var rows: [LocationRowData] = []
    var alert: AlertState?

    var isEmpty: Bool { rows.isEmpty }

    private let inventory: InventoryService
    private let router: AppRouter
    private let formatter: ContentsFormatter
    @ObservationIgnored private var storeObservation: StoreObservation?

    init(inventory: InventoryService, router: AppRouter, storeChanges: StoreChanges, formatter: ContentsFormatter = ContentsFormatter()) {
        self.inventory = inventory
        self.router = router
        self.formatter = formatter
        reload()
        storeObservation = storeChanges.observe { [weak self] in self?.reload() }
    }

    func reload() {
        do {
            rows = try inventory.rootLocations().map { LocationRowData($0, inventory: inventory, formatter: formatter) }
        } catch {
            alert = .error(error)
        }
    }

    func addLocationTapped() {
        router.present(.newLocation(parentID: nil))
    }

    func scanTapped() {
        router.presentScanner()
    }

    func printLabelsTapped() {
        router.present(.printLabels)
    }

    func deleteTapped(locationID: UUID) {
        do {
            guard let location = try inventory.location(id: locationID) else { return reload() }
            alert = DeleteConfirmation.location(
                named: location.name,
                contents: inventory.totalContents(of: location),
                formatter: formatter
            ) { [weak self] in
                self?.delete(locationID: locationID)
            }
        } catch {
            alert = .error(error)
        }
    }

    private func delete(locationID: UUID) {
        do {
            try inventory.deleteLocation(id: locationID)
        } catch {
            alert = .error(error)
        }
    }
}
