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

    func makeLocationViewModel(id: UUID) -> LocationViewModel {
        LocationViewModel(locationID: id, inventory: inventory, router: router, storeChanges: storeChanges)
    }

    func makeLocationFormViewModel(mode: LocationFormViewModel.Mode) -> LocationFormViewModel {
        LocationFormViewModel(mode: mode, inventory: inventory, router: router)
    }

    func makeItemFormViewModel(id: UUID) -> ItemFormViewModel {
        ItemFormViewModel(itemID: id, inventory: inventory, router: router)
    }
}
