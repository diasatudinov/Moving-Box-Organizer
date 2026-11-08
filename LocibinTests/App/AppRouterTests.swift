import Foundation
import Testing
@testable import Locibin

struct AppRouterTests {
    @Test func showLocationPushesRouteAndPopToRootClearsStack() {
        let router = AppRouter()
        let garage = UUID()
        let shelf = UUID()

        router.showLocation(id: garage)
        router.showLocation(id: shelf)
        #expect(router.path == [.location(garage), .location(shelf)])

        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test func closeLocationRemovesItAndEverythingAbove() {
        let router = AppRouter()
        let garage = UUID(), rack = UUID(), shelf = UUID()
        router.showLocation(id: garage)
        router.showLocation(id: rack)
        router.showLocation(id: shelf)

        router.closeLocation(id: rack)
        #expect(router.path == [.location(garage)])

        router.closeLocation(id: UUID())
        #expect(router.path == [.location(garage)])
    }

    @Test func presentAndDismissSheet() {
        let router = AppRouter()
        router.present(.newLocation(parentID: nil))
        #expect(router.sheet == .newLocation(parentID: nil))
        router.dismissSheet()
        #expect(router.sheet == nil)
    }
}
