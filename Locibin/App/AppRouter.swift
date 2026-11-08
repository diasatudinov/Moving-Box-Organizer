import Foundation
import Observation

/// A screen in the navigation stack. Locations are referenced by their stable `id`,
/// so the same route can come from the list, search, the scanner or a deep link.
enum Route: Hashable {
    /// `highlightedItem` briefly highlights an item found by search.
    case location(UUID, highlightedItem: UUID? = nil)
}

/// A modal form. Kept in the router (not in screen ViewModels) so that deep links
/// can later check whether a form with unsaved changes is open.
enum Sheet: Identifiable, Hashable {
    case newLocation(parentID: UUID?)
    case editLocation(UUID)
    case editItem(UUID)
    case moveItem(UUID)
    case moveLocation(UUID)

    var id: Self { self }
}

/// Owns navigation state: the stack and the presented sheet.
@Observable
final class AppRouter {
    var path: [Route] = []
    var sheet: Sheet?

    func showLocation(id: UUID, highlightingItem itemID: UUID? = nil) {
        path.append(.location(id, highlightedItem: itemID))
    }

    func popToRoot() {
        path.removeAll()
    }

    /// Removes the location's screen and everything opened above it — used after deleting it.
    func closeLocation(id: UUID) {
        let index = path.firstIndex { route in
            if case .location(let routeID, _) = route { routeID == id } else { false }
        }
        guard let index else { return }
        path.removeSubrange(index...)
    }

    func present(_ sheet: Sheet) {
        self.sheet = sheet
    }

    func dismissSheet() {
        sheet = nil
    }
}
