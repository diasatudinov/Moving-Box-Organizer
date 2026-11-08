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
}
