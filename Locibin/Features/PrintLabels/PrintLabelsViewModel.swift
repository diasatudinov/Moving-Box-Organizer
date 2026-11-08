import Foundation
import Observation

/// "Print Labels": choose places, label size and paper, then preview, print or share the PDF.
@Observable
final class PrintLabelsViewModel {
    struct Row: Identifiable, Equatable {
        let id: UUID
        let title: String
        /// Parent path, e.g. "Garage › Rack 1".
        let subtitle: String?
        let kind: LocationKind
    }

    let rows: [Row]
    private(set) var selectedIDs: Set<UUID> = []
    var paper: PaperSize
    var labelSize: LabelSize = .large
    /// Set when the preview is shown.
    var sheet: LabelSheet?
    var alert: AlertState?

    private let labels: LabelSheetService
    private let printer: (Data, String) -> Void
    private let router: AppRouter
    private let locale: Locale

    init(
        inventory: InventoryService,
        labels: LabelSheetService,
        router: AppRouter,
        locale: Locale = .current,
        printer: @escaping (Data, String) -> Void
    ) {
        self.labels = labels
        self.router = router
        self.locale = locale
        self.printer = printer
        self.paper = PaperSize.default(for: locale)
        self.rows = ((try? inventory.locationTree()) ?? []).map { entry in
            let parents = inventory.path(to: entry.location).dropLast().map(\.name)
            return Row(
                id: entry.location.id,
                title: entry.location.name,
                subtitle: parents.isEmpty ? nil : parents.joined(separator: " › "),
                kind: entry.location.kind
            )
        }
    }

    var allSelected: Bool { !rows.isEmpty && selectedIDs.count == rows.count }
    var canPreview: Bool { !selectedIDs.isEmpty }

    /// "3 labels · 1 sheet" for the current choice.
    var summary: String {
        let count = selectedIDs.count
        let sheets = LabelLayout(paper: paper, label: labelSize).pageCount(for: count)
        let labelsText = String(localized: LocalizedStringResource("\(count) labels", locale: locale, comment: "Number of labels to print"))
        let sheetsText = String(localized: LocalizedStringResource("\(sheets) sheets", locale: locale, comment: "Number of paper sheets"))
        return labelsText + " · " + sheetsText
    }

    func isSelected(_ row: Row) -> Bool {
        selectedIDs.contains(row.id)
    }

    func toggle(_ row: Row) {
        if selectedIDs.contains(row.id) {
            selectedIDs.remove(row.id)
        } else {
            selectedIDs.insert(row.id)
        }
    }

    func toggleAll() {
        selectedIDs = allSelected ? [] : Set(rows.map(\.id))
    }

    /// Builds the PDF in list order and shows the preview.
    func previewTapped() {
        let ids = rows.map(\.id).filter(selectedIDs.contains)
        do {
            sheet = try labels.makeSheet(for: ids, paper: paper, size: labelSize)
        } catch {
            alert = .error(error)
        }
    }

    func printTapped() {
        guard let sheet else { return }
        printer(sheet.data, sheet.fileURL.deletingPathExtension().lastPathComponent)
    }

    func cancel() {
        router.dismissSheet()
    }
}
