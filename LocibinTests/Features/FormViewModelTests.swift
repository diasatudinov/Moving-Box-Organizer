import Foundation
import Testing
@testable import Locibin

struct LocationFormViewModelTests {
    @Test func creatingTopLevelPlaceOpensIt() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        router.present(.newLocation(parentID: nil))
        let viewModel = LocationFormViewModel(mode: .create(parentID: nil), inventory: fixture.service, router: router)

        #expect(viewModel.kind == .room)
        #expect(!viewModel.canSave)
        viewModel.name = "Basement"
        viewModel.save()

        let basement = try #require(try fixture.service.rootLocations().first { $0.name == "Basement" })
        #expect(router.sheet == nil)
        #expect(router.path == [.location(basement.id)])
    }

    @Test func creatingNestedPlaceStaysOnParent() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        router.present(.newLocation(parentID: fixture.rack.id))
        let viewModel = LocationFormViewModel(mode: .create(parentID: fixture.rack.id), inventory: fixture.service, router: router)

        #expect(viewModel.kind == .box)
        #expect(viewModel.parentPathText?.contains("Garage › Rack 1") == true)
        viewModel.name = "Drawer 3"
        viewModel.kind = .drawer
        viewModel.save()

        #expect(router.sheet == nil)
        #expect(router.path.isEmpty)
        #expect(fixture.service.children(of: fixture.rack).map(\.name) == ["Box 2", "Drawer 3", "Shelf 1"])
    }

    @Test func editingIsPrefilledAndTracksChanges() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        router.present(.editLocation(fixture.box.id))
        let viewModel = LocationFormViewModel(mode: .edit(fixture.box.id), inventory: fixture.service, router: router)

        #expect(viewModel.name == "Box 2")
        #expect(viewModel.kind == .box)
        #expect(!viewModel.hasUnsavedChanges)

        viewModel.kind = .container
        #expect(viewModel.hasUnsavedChanges)
        viewModel.save()

        #expect(fixture.box.kind == .container)
        #expect(router.sheet == nil)
    }

    @Test func cancelWithChangesAsksBeforeDiscarding() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        router.present(.editLocation(fixture.box.id))
        let viewModel = LocationFormViewModel(mode: .edit(fixture.box.id), inventory: fixture.service, router: router)

        viewModel.name = "Renamed"
        viewModel.cancelTapped()
        #expect(router.sheet != nil)
        try #require(viewModel.alert?.actions.first { $0.role == .destructive }).handler()

        #expect(router.sheet == nil)
        #expect(fixture.box.name == "Box 2")
    }

    @Test func cancelWithoutChangesClosesImmediately() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        router.present(.editLocation(fixture.box.id))
        let viewModel = LocationFormViewModel(mode: .edit(fixture.box.id), inventory: fixture.service, router: router)

        viewModel.cancelTapped()

        #expect(router.sheet == nil)
        #expect(viewModel.alert == nil)
    }
}

struct ItemFormViewModelTests {
    private func makeViewModel(_ fixture: InventoryFixture, item: Item, router: AppRouter) -> ItemFormViewModel {
        router.present(.editItem(item.id))
        return ItemFormViewModel(itemID: item.id, inventory: fixture.service, router: router, locale: Locale(identifier: "en"))
    }

    @Test func prefilledWithItemAndItsPath() throws {
        let fixture = try InventoryFixture()
        let viewModel = makeViewModel(fixture, item: fixture.drill, router: AppRouter())

        #expect(viewModel.draft == .init(name: "Bosch drill", quantity: nil, note: "In the case", locationID: fixture.shelf.id))
        #expect(viewModel.locationPathText == "Garage › Rack 1 › Shelf 1")
        #expect(!viewModel.hasUnsavedChanges)
    }

    @Test func quantityStepsFromNotSpecifiedAndBack() throws {
        let fixture = try InventoryFixture()
        let viewModel = makeViewModel(fixture, item: fixture.drill, router: AppRouter())

        #expect(!viewModel.canDecreaseQuantity)
        viewModel.increaseQuantity()
        viewModel.increaseQuantity()
        #expect(viewModel.draft.quantity == 2)
        #expect(viewModel.quantityText == "2")
        viewModel.decreaseQuantity()
        viewModel.decreaseQuantity()
        #expect(viewModel.draft.quantity == nil)
        viewModel.decreaseQuantity()
        #expect(viewModel.draft.quantity == nil)
    }

    @Test func saveWritesChangesAndCloses() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        let viewModel = makeViewModel(fixture, item: fixture.drill, router: router)

        viewModel.draft.name = "Bosch drill GSB 18V"
        viewModel.increaseQuantity()
        viewModel.draft.note = ""
        viewModel.save()

        #expect(fixture.drill.name == "Bosch drill GSB 18V")
        #expect(fixture.drill.quantity == 1)
        #expect(fixture.drill.note == nil)
        #expect(router.sheet == nil)
    }

    @Test func blankNameCannotBeSaved() throws {
        let fixture = try InventoryFixture()
        let viewModel = makeViewModel(fixture, item: fixture.drill, router: AppRouter())

        viewModel.draft.name = "  "

        #expect(!viewModel.canSave)
    }

    @Test func deleteAsksFirstThenDeletesAndCloses() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        let viewModel = makeViewModel(fixture, item: fixture.drill, router: router)

        viewModel.deleteTapped()
        #expect(try fixture.service.item(id: fixture.drill.id) != nil)
        try #require(viewModel.alert?.actions.first { $0.role == .destructive }).handler()

        #expect(try fixture.service.item(id: fixture.drill.id) == nil)
        #expect(router.sheet == nil)
    }
}
