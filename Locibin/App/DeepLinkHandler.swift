import Foundation
import OSLog

/// The single way a location is opened from outside the app's own navigation:
/// links from the system Camera now, the in-app scanner in step 5.6.
/// Never throws away unsaved edits without asking (design 2.4).
final class DeepLinkHandler {
    private let inventory: InventoryService
    private let router: AppRouter
    private let qrCodes: QRCodeService

    init(inventory: InventoryService, router: AppRouter, qrCodes: QRCodeService) {
        self.inventory = inventory
        self.router = router
        self.qrCodes = qrCodes
    }

    func handle(url: URL) {
        switch qrCodes.parse(url: url) {
        case .location(let id):
            open(locationID: id)
        case .malformedOwnCode:
            Logger.navigation.notice("Opened a damaged code link")
            proceed(title: nil) { [router] in router.present(.codeProblem(.damagedCode)) }
        case .foreign:
            Logger.navigation.notice("Ignored a link with an unknown format")
        }
    }

    func open(locationID: UUID) {
        guard let location = try? inventory.location(id: locationID) else {
            proceed(title: nil) { [router] in router.present(.codeProblem(.locationNotFound)) }
            return
        }
        proceed(title: location.name) { [router] in router.showOnlyLocation(id: locationID) }
    }

    /// Runs `action` right away, or first asks what to do with unsaved edits in the open form.
    private func proceed(title locationName: String?, action: @escaping () -> Void) {
        guard router.sheet != nil, let form = router.activeForm, form.hasUnsavedChanges else {
            action()
            return
        }
        let title = locationName.map {
            String(localized: "Open “\($0)”?", comment: "Alert title: a scanned place is about to open while a form has unsaved changes")
        } ?? String(localized: "Unsaved Changes", comment: "Alert title: a scanned code arrived while a form has unsaved changes")
        router.alert = AlertState(
            title: title,
            message: String(localized: "Your changes haven't been saved.", comment: "Alert message: the open form has unsaved changes"),
            actions: [
                AlertState.Action(title: String(localized: "Save and Open", comment: "Button: save the form, then open the scanned place")) { [router, weak form] in
                    form?.save()
                    // Saving closes the form; if it failed the form stays open with its own error.
                    if router.sheet == nil { action() }
                },
                AlertState.Action(title: String(localized: "Don't Save", comment: "Button: discard the form's changes and open the scanned place"), role: .destructive, handler: action),
                AlertState.Action(title: String(localized: "Stay", comment: "Button: keep editing the form"), role: .cancel),
            ]
        )
    }
}
