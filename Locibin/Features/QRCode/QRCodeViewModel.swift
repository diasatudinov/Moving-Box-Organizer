import Foundation
import Observation
import UIKit

/// A location's QR code, shown large with the name, plus printing / sharing a single label.
@Observable
final class QRCodeViewModel {
    enum State {
        case loaded(title: String, pathText: String?, image: UIImage)
        case missing
    }

    let locationID: UUID
    private(set) var state: State = .missing
    /// One large label on a sheet, ready to print or share.
    private(set) var labelSheet: LabelSheet?
    var alert: AlertState?

    private let router: AppRouter
    private let printer: (Data, String) -> Void

    init(
        locationID: UUID,
        inventory: InventoryService,
        qrCodes: QRCodeService,
        labels: LabelSheetService,
        router: AppRouter,
        locale: Locale = .current,
        printer: @escaping (Data, String) -> Void
    ) {
        self.locationID = locationID
        self.router = router
        self.printer = printer
        guard let location = try? inventory.location(id: locationID),
              let image = qrCodes.image(for: locationID)
        else { return }
        let parents = inventory.path(to: location).dropLast().map(\.name)
        state = .loaded(
            title: location.name,
            pathText: parents.isEmpty ? nil : parents.joined(separator: " › "),
            image: image
        )
        labelSheet = try? labels.makeSheet(for: [locationID], paper: PaperSize.default(for: locale), size: .large)
    }

    func printTapped() {
        guard let labelSheet else {
            alert = .error(LabelSheetError.couldNotSave)
            return
        }
        printer(labelSheet.data, labelSheet.fileURL.deletingPathExtension().lastPathComponent)
    }

    func doneTapped() {
        router.dismissSheet()
    }
}
