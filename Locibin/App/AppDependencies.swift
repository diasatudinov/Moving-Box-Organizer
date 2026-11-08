import Foundation
import SwiftData

/// Everything screens need, created once at launch and passed down explicitly.
/// ViewModels are created only through the factory methods below.
final class AppDependencies {
    let modelContainer: ModelContainer
    let router: AppRouter
    let inventory: InventoryService
    let storeChanges: StoreChanges

    init(modelContainer: ModelContainer, router: AppRouter = AppRouter()) {
        self.modelContainer = modelContainer
        self.router = router
        self.inventory = InventoryService(context: modelContainer.mainContext)
        self.storeChanges = StoreChanges(context: modelContainer.mainContext)
    }

    var modelContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - ViewModel factories

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(inventory: inventory, router: router, storeChanges: storeChanges)
    }

    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(inventory: inventory, router: router, storeChanges: storeChanges)
    }

    func makeLocationViewModel(id: UUID, highlightedItemID: UUID? = nil) -> LocationViewModel {
        LocationViewModel(locationID: id, highlightedItemID: highlightedItemID, inventory: inventory, router: router, storeChanges: storeChanges)
    }

    func makeMoveItemPicker(itemID: UUID) -> LocationPickerViewModel {
        let item = try? inventory.item(id: itemID)
        return LocationPickerViewModel(
            subjectName: item?.name ?? "",
            subject: .item,
            current: item?.location.map { .location($0.id) },
            inventory: inventory,
            showsCancel: true,
            apply: { [inventory] target in
                guard case .location(let locationID) = target else { return }
                try inventory.moveItem(id: itemID, toLocationID: locationID)
            },
            close: { [router] in router.dismissSheet() }
        )
    }

    func makeMoveLocationPicker(locationID: UUID) -> LocationPickerViewModel {
        let location = try? inventory.location(id: locationID)
        return LocationPickerViewModel(
            subjectName: location?.name ?? "",
            subject: .location(locationID),
            current: location.map { $0.parent.map { .location($0.id) } ?? .topLevel },
            inventory: inventory,
            showsCancel: true,
            apply: { [inventory] target in
                switch target {
                case .topLevel: try inventory.moveLocation(id: locationID, toParentID: nil)
                case .location(let parentID): try inventory.moveLocation(id: locationID, toParentID: parentID)
                }
            },
            close: { [router] in router.dismissSheet() }
        )
    }

    func makeLocationFormViewModel(mode: LocationFormViewModel.Mode) -> LocationFormViewModel {
        LocationFormViewModel(mode: mode, inventory: inventory, router: router)
    }

    func makeItemFormViewModel(id: UUID) -> ItemFormViewModel {
        ItemFormViewModel(itemID: id, inventory: inventory, router: router)
    }
}
