import Foundation
import SwiftData
import Testing
@testable import Locibin

struct HomeViewModelTests {
    private func makeViewModel(_ fixture: InventoryFixture, router: AppRouter = AppRouter()) -> HomeViewModel {
        HomeViewModel(
            inventory: fixture.service,
            router: router,
            storeChanges: StoreChanges(context: fixture.context),
            formatter: ContentsFormatter(locale: Locale(identifier: "en"))
        )
    }

    @Test func showsTopLevelPlacesWithContents() throws {
        let fixture = try InventoryFixture()
        let viewModel = makeViewModel(fixture)

        #expect(viewModel.rows.map(\.title) == ["Garage", "Pantry"])
        #expect(viewModel.rows.map(\.subtitle) == ["1 place · 4 items", "1 place · 2 items"])
        #expect(viewModel.rows.first?.kind == .room)
        #expect(!viewModel.isEmpty)
    }

    @Test func emptyStoreShowsEmptyState() throws {
        let container = try makeTestContainer()
        let viewModel = HomeViewModel(
            inventory: InventoryService(context: container.mainContext),
            router: AppRouter(),
            storeChanges: StoreChanges(context: container.mainContext)
        )
        #expect(viewModel.isEmpty)
    }

    @Test func reloadsAutomaticallyWhenStoreChanges() throws {
        let fixture = try InventoryFixture()
        let viewModel = makeViewModel(fixture)

        try fixture.service.createLocation(name: "Basement", kind: .room, parentID: nil)

        #expect(viewModel.rows.map(\.title) == ["Basement", "Garage", "Pantry"])
    }

    @Test func addOpensNewTopLevelPlaceForm() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        let viewModel = makeViewModel(fixture, router: router)

        viewModel.addLocationTapped()

        #expect(router.sheet == .newLocation(parentID: nil))
    }

    @Test func deleteAsksFirstThenDeletesWithEverythingInside() throws {
        let fixture = try InventoryFixture()
        let viewModel = makeViewModel(fixture)

        viewModel.deleteTapped(locationID: fixture.garage.id)
        let alert = try #require(viewModel.alert)
        #expect(alert.message?.contains("3 places · 4 items") == true)
        #expect(viewModel.rows.count == 2, "Nothing is deleted before confirmation")

        try #require(alert.actions.first { $0.role == .destructive }).handler()

        #expect(viewModel.rows.map(\.title) == ["Pantry"])
    }
}
