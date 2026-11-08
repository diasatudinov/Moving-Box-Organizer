import Foundation
import Observation
import UIKit

/// A location's QR code, shown large with the name. Print and PDF actions are added in step 5.7.
@Observable
final class QRCodeViewModel {
    enum State {
        case loaded(title: String, pathText: String?, image: UIImage)
        case missing
    }

    let locationID: UUID
    private(set) var state: State = .missing

    private let router: AppRouter

    init(locationID: UUID, inventory: InventoryService, qrCodes: QRCodeService, router: AppRouter) {
        self.locationID = locationID
        self.router = router
        guard let location = try? inventory.location(id: locationID),
              let image = qrCodes.image(for: locationID)
        else { return }
        let parents = inventory.path(to: location).dropLast().map(\.name)
        state = .loaded(
            title: location.name,
            pathText: parents.isEmpty ? nil : parents.joined(separator: " › "),
            image: image
        )
    }

    func doneTapped() {
        router.dismissSheet()
    }
}
