import Foundation
import Testing
@testable import Locibin

struct LocationTreeTests {
    @Test func treeListsParentsBeforeChildrenInNaturalOrder() throws {
        let fixture = try InventoryFixture()

        let tree = try fixture.service.locationTree()

        #expect(tree.map(\.location.name) == ["Garage", "Rack 1", "Box 2", "Shelf 1", "Pantry", "Top shelf", "New Year"])
        #expect(tree.map(\.depth) == [0, 1, 2, 2, 0, 1, 2])
    }
}

struct LocationPickerViewModelTests {
    private func itemPicker(_ fixture: InventoryFixture, router: AppRouter) -> LocationPickerViewModel {
        AppDependencies(modelContainer: fixture.container, router: router).makeMoveItemPicker(itemID: fixture.drill.id)
    }

    @Test func movingAnItemMarksCurrentPlaceAndHasNoTopLevel() throws {
        let fixture = try InventoryFixture()
        let picker = itemPicker(fixture, router: AppRouter())

        #expect(!picker.rows.contains { $0.target == .topLevel })
        let current = try #require(picker.rows.first { $0.isCurrent })
        #expect(current.target == .location(fixture.shelf.id))
        #expect(current.isDisabled)
        #expect(picker.rows.filter(\.isDisabled).count == 1)
        #expect(!picker.canConfirm)
    }

    @Test func confirmingMovesTheItemAndClosesTheSheet() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        router.present(.moveItem(fixture.drill.id))
        let picker = itemPicker(fixture, router: router)

        let box = try #require(picker.rows.first { $0.target == .location(fixture.box.id) })
        picker.select(box)
        #expect(picker.canConfirm)
        picker.confirm()

        #expect(fixture.drill.location?.id == fixture.box.id)
        #expect(router.sheet == nil)
    }

    @Test func selectingADisabledRowDoesNothing() throws {
        let fixture = try InventoryFixture()
        let picker = itemPicker(fixture, router: AppRouter())

        picker.select(try #require(picker.rows.first { $0.isCurrent }))

        #expect(picker.selection == nil)
    }

    @Test func movingALocationDisablesItselfAndItsSubLocations() throws {
        let fixture = try InventoryFixture()
        let picker = AppDependencies(modelContainer: fixture.container).makeMoveLocationPicker(locationID: fixture.rack.id)

        let disabled = Set(picker.rows.filter(\.isDisabled).map(\.target))
        #expect(disabled == [.location(fixture.rack.id), .location(fixture.shelf.id), .location(fixture.box.id), .location(fixture.garage.id)])
        #expect(picker.rows.first { $0.isCurrent }?.target == .location(fixture.garage.id))
        #expect(picker.rows.first?.target == .topLevel)
    }

    @Test func movingALocationToTopLevel() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        let picker = AppDependencies(modelContainer: fixture.container, router: router).makeMoveLocationPicker(locationID: fixture.rack.id)

        picker.select(try #require(picker.rows.first { $0.target == .topLevel }))
        picker.confirm()

        #expect(fixture.rack.parent == nil)
        #expect(try fixture.service.rootLocations().map(\.name) == ["Garage", "Pantry", "Rack 1"])
    }

    @Test func filterShowsMatchesFlatWithTheirParentPath() throws {
        let fixture = try InventoryFixture()
        let picker = itemPicker(fixture, router: AppRouter())

        picker.query = "box"

        #expect(picker.rows.map(\.title) == ["Box 2"])
        #expect(picker.rows.first?.subtitle == "Garage › Rack 1")
        #expect(picker.rows.first?.depth == 0)
    }

    @Test func cancelClosesWithoutChanges() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        router.present(.moveItem(fixture.drill.id))
        let picker = itemPicker(fixture, router: router)

        picker.select(try #require(picker.rows.first { $0.target == .location(fixture.box.id) }))
        picker.cancel()

        #expect(router.sheet == nil)
        #expect(fixture.drill.location?.id == fixture.shelf.id)
    }
}

struct SearchViewModelTests {
    private func makeViewModel(_ fixture: InventoryFixture, router: AppRouter = AppRouter()) -> SearchViewModel {
        SearchViewModel(inventory: fixture.service, router: router, storeChanges: StoreChanges(context: fixture.context))
    }

    @Test func resultsShowWhereThingsAre() throws {
        let fixture = try InventoryFixture()
        let search = makeViewModel(fixture)

        search.query = "drill"

        #expect(search.items == [.init(id: fixture.drill.id, title: "Bosch drill", pathText: "Garage › Rack 1 › Shelf 1", locationID: fixture.shelf.id)])
        #expect(search.locations.isEmpty)
        #expect(!search.hasNoResults)
    }

    @Test func placesShowTheirParentPath() throws {
        let fixture = try InventoryFixture()
        let search = makeViewModel(fixture)

        search.query = "shelf"

        #expect(search.locations.map(\.title) == ["Shelf 1", "Top shelf"])
        #expect(search.locations.map(\.subtitle) == ["Garage › Rack 1", "Pantry"])
    }

    @Test func blankQueryIsInactiveAndUnknownWordHasNoResults() throws {
        let fixture = try InventoryFixture()
        let search = makeViewModel(fixture)

        search.query = "  "
        #expect(!search.isActive)
        #expect(!search.hasNoResults)

        search.query = "perforator"
        #expect(search.hasNoResults)
    }

    @Test func selectingAnItemOpensItsPlaceWithTheItemHighlighted() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        let search = makeViewModel(fixture, router: router)
        search.query = "drill"

        search.select(try #require(search.items.first))

        #expect(router.path == [.location(fixture.shelf.id, highlightedItem: fixture.drill.id)])
    }

    @Test func resultsRefreshWhenDataChanges() throws {
        let fixture = try InventoryFixture()
        let search = makeViewModel(fixture)
        search.query = "drill"

        try fixture.service.moveItem(id: fixture.drill.id, toLocationID: fixture.box.id)

        #expect(search.items.first?.pathText == "Garage › Rack 1 › Box 2")
    }
}

struct MoveFromScreensTests {
    @Test func locationScreenOpensMovePickers() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        let viewModel = LocationViewModel(locationID: fixture.rack.id, inventory: fixture.service, router: router, storeChanges: StoreChanges(context: fixture.context))

        viewModel.moveTapped()
        #expect(router.sheet == .moveLocation(fixture.rack.id))
        viewModel.moveSublocationTapped(id: fixture.box.id)
        #expect(router.sheet == .moveLocation(fixture.box.id))
        viewModel.moveItemTapped(id: fixture.drill.id)
        #expect(router.sheet == .moveItem(fixture.drill.id))
    }

    @Test func highlightFromSearchCanBeCleared() throws {
        let fixture = try InventoryFixture()
        let viewModel = LocationViewModel(locationID: fixture.shelf.id, highlightedItemID: fixture.drill.id, inventory: fixture.service, router: AppRouter(), storeChanges: StoreChanges(context: fixture.context))

        #expect(viewModel.highlightedItemID == fixture.drill.id)
        viewModel.clearHighlight()
        #expect(viewModel.highlightedItemID == nil)
    }

    @Test func itemFormAppliesNewLocationOnlyOnDone() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        router.present(.editItem(fixture.drill.id))
        let form = ItemFormViewModel(itemID: fixture.drill.id, inventory: fixture.service, router: router)

        let picker = form.makeLocationPicker()
        picker.select(try #require(picker.rows.first { $0.target == .location(fixture.box.id) }))
        picker.confirm()

        #expect(form.draft.locationID == fixture.box.id)
        #expect(form.locationPathText == "Garage › Rack 1 › Box 2")
        #expect(fixture.drill.location?.id == fixture.shelf.id, "Not moved before Done")
        #expect(form.hasUnsavedChanges)

        form.save()

        #expect(fixture.drill.location?.id == fixture.box.id)
        #expect(router.sheet == nil)
    }

    @Test func itemFormCancelKeepsTheOldLocation() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        router.present(.editItem(fixture.drill.id))
        let form = ItemFormViewModel(itemID: fixture.drill.id, inventory: fixture.service, router: router)
        form.draft.locationID = fixture.box.id

        form.cancelTapped()
        try #require(form.alert?.actions.first { $0.role == .destructive }).handler()

        #expect(fixture.drill.location?.id == fixture.shelf.id)
    }
}
