import Foundation
import Observation

/// A screen in the navigation stack. Locations are referenced by their stable `id`,
/// so the same route can come from the list, search, the scanner or a deep link.
enum Route: Hashable {
    /// `highlightedItem` briefly highlights an item found by search.
    case location(UUID, highlightedItem: UUID? = nil)
}

/// Why a scanned code or opened link could not be shown.
enum CodeProblem: Hashable {
    /// A valid code of a location that is not in this app (deleted, or data on another iPhone).
    case locationNotFound
    /// Our scheme, but the code is damaged or from a newer app version.
    case damagedCode
}

/// A modal screen. Kept in the router (not in screen ViewModels) so that deep links
/// can check whether a form with unsaved changes is open.
enum Sheet: Identifiable, Hashable {
    case newLocation(parentID: UUID?)
    case editLocation(UUID)
    case editItem(UUID)
    case moveItem(UUID)
    case moveLocation(UUID)
    case qrCode(UUID)
    case codeProblem(CodeProblem)
    case printLabels

    var id: Self { self }
}

/// A form that can hold unsaved edits; it registers itself with the router while open.
protocol UnsavedChangesGuard: AnyObject {
    var hasUnsavedChanges: Bool { get }
    /// Saves and closes the form; leaves it open (with its own error) if saving fails.
    func save()
}

/// Owns navigation state: the stack, the presented sheet and app-level alerts.
@Observable
final class AppRouter {
    var path: [Route] = []
    var sheet: Sheet?
    /// The full-screen scanner.
    var isScannerPresented = false
    /// App-level alert (for example: a link arrived while a form has unsaved changes).
    var alert: AlertState?

    /// The open form, if any. Weak: it disappears together with its sheet.
    @ObservationIgnored weak var activeForm: (any UnsavedChangesGuard)?

    /// Alert shown over the main screens when no sheet is open…
    var alertOverRoot: AlertState? {
        get { sheet == nil ? alert : nil }
        set { alert = newValue }
    }

    /// …or over the open sheet, because SwiftUI can present an alert only from the topmost screen.
    var alertOverSheet: AlertState? {
        get { sheet != nil ? alert : nil }
        set { alert = newValue }
    }

    func showLocation(id: UUID, highlightingItem itemID: UUID? = nil) {
        path.append(.location(id, highlightedItem: itemID))
    }

    /// Opens a location as the only screen above the main list — used for scans and links.
    func showOnlyLocation(id: UUID) {
        isScannerPresented = false
        sheet = nil
        path = [.location(id)]
    }

    func presentScanner() {
        isScannerPresented = true
    }

    func dismissScanner() {
        isScannerPresented = false
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
