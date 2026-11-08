import Foundation
import Testing
@testable import Locibin

struct LocationViewModelTests {
    private func makeViewModel(_ fixture: InventoryFixture, id: UUID, router: AppRouter = AppRouter()) -> LocationViewModel {
        LocationViewModel(
            locationID: id,
            inventory: fixture.service,
            router: router,
            storeChanges: StoreChanges(context: fixture.context),
            locale: Locale(identifier: "en")
        )
    }

    private func content(_ viewModel: LocationViewModel) throws -> LocationViewModel.Content {
        guard case .loaded(let content) = viewModel.state else {
            Issue.record("Location is not loaded")
            throw CancellationError()
        }
        return content
    }

    @Test func showsSublocationsItemsAndWhereTheLocationIs() throws {
        let fixture = try InventoryFixture()
        let viewModel = makeViewModel(fixture, id: fixture.rack.id)

        let content = try content(viewModel)
        #expect(content.title == "Rack 1")
        #expect(content.header.hasSuffix(" · Garage"))
        #expect(content.sublocations.map(\.title) == ["Box 2", "Shelf 1"])
        #expect(content.items.isEmpty)
    }

    @Test func itemRowsShowNoteAndQuantity() throws {
        let fixture = try InventoryFixture()

        let shelf = try content(makeViewModel(fixture, id: fixture.shelf.id))
        #expect(shelf.items.map(\.title) == ["Bosch drill", "Screwdriver set"])
        #expect(shelf.items.first?.note == "In the case")
        #expect(shelf.items.first?.quantityText == nil)

        let box = try content(makeViewModel(fixture, id: fixture.box.id))
        #expect(box.items.first?.quantityText == "×10")
    }

    @Test func quickAddAddsItemAtTheBottomAndClearsTheField() throws {
        let fixture = try InventoryFixture()
        let viewModel = makeViewModel(fixture, id: fixture.shelf.id)

        viewModel.quickAddText = "  Allen keys "
        viewModel.submitQuickAdd()
        viewModel.quickAddText = "Tape measure"
        viewModel.submitQuickAdd()

        #expect(viewModel.quickAddText.isEmpty)
        #expect(try content(viewModel).items.map(\.title) == ["Bosch drill", "Screwdriver set", "Allen keys", "Tape measure"])
        #expect(viewModel.alert == nil)
    }

    @Test func quickAddIgnoresBlankInput() throws {
        let fixture = try InventoryFixture()
        let viewModel = makeViewModel(fixture, id: fixture.box.id)

        viewModel.quickAddText = "   "
        viewModel.submitQuickAdd()

        #expect(try content(viewModel).items.count == 1)
        #expect(viewModel.alert == nil)
        #expect(viewModel.quickAddText.isEmpty)
    }

    @Test func actionsOpenTheRightForms() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        let viewModel = makeViewModel(fixture, id: fixture.shelf.id, router: router)

        viewModel.itemTapped(id: fixture.drill.id)
        #expect(router.sheet == .editItem(fixture.drill.id))
        viewModel.addSublocationTapped()
        #expect(router.sheet == .newLocation(parentID: fixture.shelf.id))
        viewModel.editTapped()
        #expect(router.sheet == .editLocation(fixture.shelf.id))
    }

    @Test func deletingTheLocationClosesItsScreenAfterConfirmation() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        router.showLocation(id: fixture.garage.id)
        router.showLocation(id: fixture.rack.id)
        let viewModel = makeViewModel(fixture, id: fixture.rack.id, router: router)

        viewModel.deleteTapped()
        #expect(router.path.count == 2, "Nothing happens before confirmation")
        try #require(viewModel.alert?.actions.first { $0.role == .destructive }).handler()

        #expect(router.path == [.location(fixture.garage.id)])
        #expect(viewModel.state == .missing)
    }

    @Test func swipeDeletingAnItemRemovesItRightAway() throws {
        let fixture = try InventoryFixture()
        let viewModel = makeViewModel(fixture, id: fixture.shelf.id)

        viewModel.deleteItem(id: fixture.drill.id)

        #expect(try content(viewModel).items.map(\.title) == ["Screwdriver set"])
    }

    @Test func unknownLocationIsMissing() throws {
        let fixture = try InventoryFixture()
        #expect(makeViewModel(fixture, id: UUID()).state == .missing)
    }
}
