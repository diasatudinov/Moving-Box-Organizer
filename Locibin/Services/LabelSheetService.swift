import Foundation
import OSLog

/// A finished label PDF: the bytes for printing and a file with a readable name for sharing.
struct LabelSheet: Identifiable, Hashable {
    let id = UUID()
    let data: Data
    let fileURL: URL
    let labelCount: Int
    let pageCount: Int
}

/// Builds label sheets for locations: collects names and QR codes, lays them out and saves the PDF.
/// Shared by the "Print Labels" screen and a single location's QR screen.
final class LabelSheetService {
    private let inventory: InventoryService
    private let qrCodes: QRCodeService
    private let renderer = LabelPDFRenderer()
    private let directory: URL

    init(inventory: InventoryService, qrCodes: QRCodeService, directory: URL = FileManager.default.temporaryDirectory.appending(path: "Labels", directoryHint: .isDirectory)) {
        self.inventory = inventory
        self.qrCodes = qrCodes
        self.directory = directory
    }

    /// Labels in the order given; unknown ids are skipped.
    func makeSheet(for locationIDs: [UUID], paper: PaperSize, size: LabelSize, now: Date = .now) throws -> LabelSheet {
        let labels: [LabelContent] = locationIDs.compactMap { id in
            guard let location = try? inventory.location(id: id), let qr = qrCodes.matrix(for: id) else { return nil }
            return LabelContent(name: location.name, kindTitle: String(localized: location.kind.title), qr: qr)
        }
        guard !labels.isEmpty else { throw LabelSheetError.nothingToPrint }

        let layout = LabelLayout(paper: paper, label: size)
        let title = Self.title(for: now)
        let data = renderer.render(labels, layout: layout, title: title)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: "\(title).pdf")
            try data.write(to: url, options: .atomic)
            return LabelSheet(data: data, fileURL: url, labelCount: labels.count, pageCount: layout.pageCount(for: labels.count))
        } catch {
            Logger.labels.error("Couldn't write label PDF: \(error.localizedDescription, privacy: .public)")
            throw LabelSheetError.couldNotSave
        }
    }

    /// "Labels — Nov 9, 2026", safe as a file name.
    static func title(for date: Date) -> String {
        let day = date.formatted(date: .abbreviated, time: .omitted)
        let title = String(localized: "Labels — \(day)", comment: "PDF title and file name; the argument is a date")
        return title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }
}

nonisolated enum LabelSheetError: LocalizedError, Equatable, Sendable {
    case nothingToPrint
    case couldNotSave

    var errorDescription: String? {
        String(localized: message)
    }

    var message: LocalizedStringResource {
        switch self {
        case .nothingToPrint:
            LocalizedStringResource("Choose at least one place.", comment: "Error: no places selected for printing labels")
        case .couldNotSave:
            LocalizedStringResource("Couldn't create the PDF. Try again.", comment: "Error: writing the label PDF failed")
        }
    }
}
