import Foundation
import Testing
import UIKit
@testable import Locibin

struct DeepLinkHandlerTests {
    private func make(_ fixture: InventoryFixture) -> (AppDependencies, AppRouter) {
        let dependencies = AppDependencies(modelContainer: fixture.container)
        return (dependencies, dependencies.router)
    }

    private func url(_ id: UUID) -> URL {
        QRCodeService().url(for: id)
    }

    @Test func linkOpensTheLocationAsTheOnlyScreen() throws {
        let fixture = try InventoryFixture()
        let (dependencies, router) = make(fixture)
        router.showLocation(id: fixture.pantry.id)
        router.present(.qrCode(fixture.pantry.id))

        dependencies.deepLinks.handle(url: url(fixture.box.id))

        #expect(router.path == [.location(fixture.box.id)])
        #expect(router.sheet == nil)
    }

    @Test func unknownLocationShowsNotFound() throws {
        let fixture = try InventoryFixture()
        let (dependencies, router) = make(fixture)

        dependencies.deepLinks.handle(url: url(UUID()))

        #expect(router.sheet == .codeProblem(.locationNotFound))
        #expect(router.path.isEmpty)
    }

    @Test func damagedLinkShowsCodeNotRecognized() throws {
        let fixture = try InventoryFixture()
        let (dependencies, router) = make(fixture)

        dependencies.deepLinks.handle(url: URL(string: "com.organizestorage://location/broken")!)

        #expect(router.sheet == .codeProblem(.damagedCode))
    }

    @Test func formWithoutChangesIsClosedSilently() throws {
        let fixture = try InventoryFixture()
        let (dependencies, router) = make(fixture)
        router.present(.editItem(fixture.drill.id))
        let form = dependencies.makeItemFormViewModel(id: fixture.drill.id)

        dependencies.deepLinks.handle(url: url(fixture.box.id))

        #expect(router.alert == nil)
        #expect(router.path == [.location(fixture.box.id)])
        #expect(form.hasUnsavedChanges == false)
    }

    @Test func formWithChangesAsksAndStayKeepsEverything() throws {
        let fixture = try InventoryFixture()
        let (dependencies, router) = make(fixture)
        router.present(.editItem(fixture.drill.id))
        let form = dependencies.makeItemFormViewModel(id: fixture.drill.id)
        form.draft.name = "Bosch drill GSB"

        dependencies.deepLinks.handle(url: url(fixture.box.id))

        let alert = try #require(router.alert)
        #expect(alert.actions.map(\.role) == [nil, .destructive, .cancel])
        #expect(router.sheet == .editItem(fixture.drill.id), "Nothing happens before the user decides")

        try #require(alert.actions.last).handler()
        #expect(router.sheet == .editItem(fixture.drill.id))
        #expect(router.path.isEmpty)
        #expect(form.draft.name == "Bosch drill GSB")
    }

    @Test func dontSaveDiscardsAndOpens() throws {
        let fixture = try InventoryFixture()
        let (dependencies, router) = make(fixture)
        router.present(.editItem(fixture.drill.id))
        let form = dependencies.makeItemFormViewModel(id: fixture.drill.id)
        form.draft.name = "Renamed"

        dependencies.deepLinks.handle(url: url(fixture.box.id))
        try #require(router.alert?.actions.first { $0.role == .destructive }).handler()

        #expect(router.path == [.location(fixture.box.id)])
        #expect(router.sheet == nil)
        #expect(fixture.drill.name == "Bosch drill")
    }

    @Test func saveAndOpenSavesThenOpens() throws {
        let fixture = try InventoryFixture()
        let (dependencies, router) = make(fixture)
        router.present(.editItem(fixture.drill.id))
        let form = dependencies.makeItemFormViewModel(id: fixture.drill.id)
        form.draft.name = "Renamed"

        dependencies.deepLinks.handle(url: url(fixture.box.id))
        try #require(router.alert?.actions.first).handler()

        #expect(fixture.drill.name == "Renamed")
        #expect(router.path == [.location(fixture.box.id)])
    }

    @Test func saveAndOpenStaysWhenSavingFails() throws {
        let fixture = try InventoryFixture()
        let (dependencies, router) = make(fixture)
        router.present(.editItem(fixture.drill.id))
        let form = dependencies.makeItemFormViewModel(id: fixture.drill.id)
        form.draft.name = "   "

        dependencies.deepLinks.handle(url: url(fixture.box.id))
        try #require(router.alert?.actions.first).handler()

        #expect(router.sheet == .editItem(fixture.drill.id))
        #expect(router.path.isEmpty)
        #expect(form.alert != nil)
    }

    @Test func alertIsShownOverTheSheetWhenOneIsOpen() {
        let router = AppRouter()
        router.alert = AlertState(title: "Test", actions: [.ok()])
        #expect(router.alertOverRoot != nil)
        #expect(router.alertOverSheet == nil)

        router.present(.newLocation(parentID: nil))
        #expect(router.alertOverRoot == nil)
        #expect(router.alertOverSheet != nil)
    }
}

struct QRCodeViewModelTests {
    @Test func showsNameParentPathAndImage() throws {
        let fixture = try InventoryFixture()
        let viewModel = AppDependencies(modelContainer: fixture.container).makeQRCodeViewModel(locationID: fixture.box.id)

        guard case .loaded(let title, let pathText, let image) = viewModel.state else {
            Issue.record("Not loaded")
            return
        }
        #expect(title == "Box 2")
        #expect(pathText == "Garage › Rack 1")
        #expect(image.size.width > 0 && image.size.width == image.size.height)
    }

    @Test func unknownLocationIsMissing() throws {
        let fixture = try InventoryFixture()
        let viewModel = AppDependencies(modelContainer: fixture.container).makeQRCodeViewModel(locationID: UUID())

        guard case .missing = viewModel.state else {
            Issue.record("Expected missing")
            return
        }
    }
}
