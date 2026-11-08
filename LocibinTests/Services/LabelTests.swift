import CoreImage
import Foundation
import PDFKit
import Testing
import UIKit
@testable import Locibin

struct LabelLayoutTests {
    @Test(arguments: [
        (PaperSize.a4, LabelSize.large, 2, 4),
        (PaperSize.a4, LabelSize.small, 3, 5),
        (PaperSize.letter, LabelSize.large, 2, 4),
        (PaperSize.letter, LabelSize.small, 3, 5),
    ])
    func gridMatchesTheAgreedDesign(paper: PaperSize, label: LabelSize, columns: Int, rows: Int) {
        let layout = LabelLayout(paper: paper, label: label)
        #expect(layout.columns == columns)
        #expect(layout.rows == rows)
    }

    @Test(arguments: [PaperSize.a4, .letter], [LabelSize.large, .small])
    func everyLabelFitsInsideThePrintableArea(paper: PaperSize, label: LabelSize) {
        let layout = LabelLayout(paper: paper, label: label)
        let printable = CGRect(origin: .zero, size: paper.size).insetBy(dx: LabelLayout.minimumMargin, dy: LabelLayout.minimumMargin)
        for index in 0..<layout.labelsPerPage {
            let (page, frame) = layout.position(of: index)
            #expect(page == 0)
            #expect(printable.contains(frame.insetBy(dx: 0.01, dy: 0.01)))
        }
    }

    @Test func gridIsCentered() {
        let layout = LabelLayout(paper: .a4, label: .large)
        let first = layout.position(of: 0).frame
        let last = layout.position(of: layout.labelsPerPage - 1).frame
        let page = PaperSize.a4.size
        #expect(abs(first.minX - (page.width - last.maxX)) < 0.01)
        #expect(abs(first.minY - (page.height - last.maxY)) < 0.01)
    }

    @Test func labelsContinueOnTheNextPage() {
        let layout = LabelLayout(paper: .a4, label: .large)
        #expect(layout.pageCount(for: 8) == 1)
        #expect(layout.pageCount(for: 9) == 2)
        #expect(layout.pageCount(for: 0) == 1)
        #expect(layout.position(of: 8).page == 1)
        #expect(layout.position(of: 8).frame == layout.position(of: 0).frame)
    }

    @Test func defaultPaperDependsOnRegion() {
        #expect(PaperSize.default(for: Locale(identifier: "en_US")) == .letter)
        #expect(PaperSize.default(for: Locale(identifier: "fr_CA")) == .letter)
        #expect(PaperSize.default(for: Locale(identifier: "ru_KZ")) == .a4)
        #expect(PaperSize.default(for: Locale(identifier: "de_DE")) == .a4)
    }
}

struct LabelSheetServiceTests {
    private func makeService(_ fixture: InventoryFixture) throws -> (LabelSheetService, URL) {
        let folder = try makeTemporaryDirectory()
        return (LabelSheetService(inventory: fixture.service, qrCodes: QRCodeService(), directory: folder), folder)
    }

    @Test func pdfHasTheRightPagesAndContainsNamesAsText() throws {
        let fixture = try InventoryFixture()
        let (service, folder) = try makeService(fixture)
        defer { try? FileManager.default.removeItem(at: folder) }
        let ids = (0..<9).map { _ in fixture.box.id } + [fixture.shelf.id]

        let sheet = try service.makeSheet(for: ids, paper: .a4, size: .large)

        let document = try #require(PDFDocument(data: sheet.data))
        #expect(document.pageCount == 2)
        #expect(sheet.pageCount == 2)
        #expect(sheet.labelCount == 10)
        #expect(document.string?.contains("Box 2") == true)
        #expect(document.string?.contains("Shelf 1") == true)
        #expect(FileManager.default.fileExists(atPath: sheet.fileURL.path(percentEncoded: false)))
        #expect(sheet.fileURL.pathExtension == "pdf")
    }

    @Test func printedCodeScansBackToTheLocation() throws {
        let fixture = try InventoryFixture()
        let (service, folder) = try makeService(fixture)
        defer { try? FileManager.default.removeItem(at: folder) }

        for size in LabelSize.allCases {
            let sheet = try service.makeSheet(for: [fixture.box.id], paper: .a4, size: size)
            let page = try #require(PDFDocument(data: sheet.data)?.page(at: 0))
            // Render the page roughly like a 150 dpi print and look for the code.
            let image = page.thumbnail(of: CGSize(width: 1240, height: 1754), for: .mediaBox)
            let ciImage = try #require(CIImage(image: image))
            let detector = try #require(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
            let messages = detector.features(in: ciImage).compactMap { ($0 as? CIQRCodeFeature)?.messageString }

            #expect(messages == [QRCodeService().payload(for: fixture.box.id)], "Label size \(size)")
        }
    }

    @Test func nothingToPrintIsAnError() throws {
        let fixture = try InventoryFixture()
        let (service, folder) = try makeService(fixture)
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(throws: LabelSheetError.nothingToPrint) {
            try service.makeSheet(for: [UUID()], paper: .a4, size: .small)
        }
    }

    @Test func fileNameHasNoPathSeparators() {
        let title = LabelSheetService.title(for: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(!title.contains("/") && !title.contains(":"))
        #expect(!title.isEmpty)
    }

    @Test func errorsHaveRussianMessages() throws {
        let ru = try #require(russianBundle())
        for error in [LabelSheetError.nothingToPrint, .couldNotSave] {
            let key = error.message.key
            #expect(ru.localizedString(forKey: key, value: nil, table: nil) != key)
        }
    }
}

struct PrintLabelsViewModelTests {
    private func make(_ fixture: InventoryFixture, router: AppRouter = AppRouter(), printed: @escaping (Data, String) -> Void = { _, _ in }) throws -> PrintLabelsViewModel {
        let labels = LabelSheetService(inventory: fixture.service, qrCodes: QRCodeService(), directory: try makeTemporaryDirectory())
        return PrintLabelsViewModel(inventory: fixture.service, labels: labels, router: router, locale: Locale(identifier: "en_US"), printer: printed)
    }

    @Test func listsAllPlacesWithPathsAndDefaults() throws {
        let fixture = try InventoryFixture()
        let viewModel = try make(fixture)

        #expect(viewModel.rows.map(\.title) == ["Garage", "Rack 1", "Box 2", "Shelf 1", "Pantry", "Top shelf", "New Year"])
        #expect(viewModel.rows[2].subtitle == "Garage › Rack 1")
        #expect(viewModel.paper == .letter)
        #expect(viewModel.labelSize == .large)
        #expect(!viewModel.canPreview)
    }

    @Test func selectionAndSummary() throws {
        let fixture = try InventoryFixture()
        let viewModel = try make(fixture)

        viewModel.toggle(viewModel.rows[2])
        #expect(viewModel.summary == "1 label · 1 sheet")

        viewModel.toggleAll()
        #expect(viewModel.allSelected)
        #expect(viewModel.summary == "7 labels · 1 sheet")

        viewModel.labelSize = .large
        viewModel.toggle(viewModel.rows[0])
        #expect(!viewModel.allSelected)

        viewModel.toggleAll()
        viewModel.toggleAll()
        #expect(viewModel.selectedIDs.isEmpty)
    }

    @Test func previewBuildsThePDFAndPrintSendsIt() throws {
        let fixture = try InventoryFixture()
        var printedJob: String?
        let viewModel = try make(fixture) { _, job in printedJob = job }

        viewModel.toggle(viewModel.rows[2])
        viewModel.toggle(viewModel.rows[3])
        viewModel.previewTapped()

        let sheet = try #require(viewModel.sheet)
        #expect(sheet.labelCount == 2)
        viewModel.printTapped()
        #expect(printedJob == sheet.fileURL.deletingPathExtension().lastPathComponent)
    }

    @Test func qrScreenOffersASingleLabelSheet() throws {
        let fixture = try InventoryFixture()
        var printed = false
        let labels = LabelSheetService(inventory: fixture.service, qrCodes: QRCodeService(), directory: try makeTemporaryDirectory())
        let viewModel = QRCodeViewModel(locationID: fixture.box.id, inventory: fixture.service, qrCodes: QRCodeService(), labels: labels, router: AppRouter()) { _, _ in printed = true }

        #expect(viewModel.labelSheet?.labelCount == 1)
        viewModel.printTapped()
        #expect(printed)
    }

    @Test func homeMenuOpensPrintLabels() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        HomeViewModel(inventory: fixture.service, router: router, storeChanges: StoreChanges(context: fixture.context)).printLabelsTapped()
        #expect(router.sheet == .printLabels)
    }
}
