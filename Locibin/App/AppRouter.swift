import Foundation
import Observation

/// A screen in the navigation stack. Locations are referenced by their stable `id`,
/// so the same route can come from the list, search, the scanner or a deep link.
enum Route: Hashable {
    case location(UUID)
}

/// Owns navigation state. Sheets and deep link handling are added with their features.
@Observable
final class AppRouter {
    var path: [Route] = []

    func showLocation(id: UUID) {
        path.append(.location(id))
    }

    func popToRoot() {
        path.removeAll()
    }
}
