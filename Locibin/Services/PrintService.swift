import Foundation
import UIKit

/// Opens the system print dialog for a PDF. A tiny UIKit bridge so ViewModels never touch UIKit.
final class PrintService {
    func printPDF(_ data: Data, jobName: String) {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .grayscale
        info.jobName = jobName
        controller.printInfo = info
        controller.printingItem = data
        controller.present(animated: true)
    }
}
