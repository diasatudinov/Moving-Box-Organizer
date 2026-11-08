import CoreGraphics
import Foundation

/// Sheet of paper the labels are printed on. Sizes in PDF points (1/72 inch).
nonisolated enum PaperSize: String, CaseIterable, Sendable {
    case a4
    case letter

    var size: CGSize {
        switch self {
        case .a4: CGSize(width: Millimeters.points(210), height: Millimeters.points(297))
        case .letter: CGSize(width: 612, height: 792)
        }
    }

    /// Letter in the US and Canada, A4 everywhere else (design decision 2.4 / 3.3).
    static func `default`(for locale: Locale) -> PaperSize {
        switch locale.region?.identifier {
        case "US", "CA": .letter
        default: .a4
        }
    }
}

nonisolated enum LabelSize: String, CaseIterable, Sendable {
    /// 50 × 50 mm, QR 36 mm — 15 per sheet.
    case small
    /// 90 × 60 mm, QR 45 mm — 8 per sheet.
    case large

    var size: CGSize {
        switch self {
        case .small: CGSize(width: Millimeters.points(50), height: Millimeters.points(50))
        case .large: CGSize(width: Millimeters.points(90), height: Millimeters.points(60))
        }
    }

    var qrSide: CGFloat {
        switch self {
        case .small: Millimeters.points(36)
        case .large: Millimeters.points(45)
        }
    }
}

nonisolated enum Millimeters {
    static func points(_ millimeters: CGFloat) -> CGFloat {
        millimeters * 72 / 25.4
    }
}

/// Where each label goes: a grid centered on the page with at least `minimumMargin` on every side
/// (printers can't print to the edge). Pure calculation — easy to test, no drawing.
nonisolated struct LabelLayout: Sendable {
    static let minimumMargin = Millimeters.points(10)

    let paper: PaperSize
    let label: LabelSize
    let columns: Int
    let rows: Int
    private let origin: CGPoint

    init(paper: PaperSize, label: LabelSize) {
        self.paper = paper
        self.label = label
        let page = paper.size
        let cell = label.size
        columns = max(1, Int((page.width - 2 * Self.minimumMargin) / cell.width))
        rows = max(1, Int((page.height - 2 * Self.minimumMargin) / cell.height))
        origin = CGPoint(
            x: (page.width - CGFloat(columns) * cell.width) / 2,
            y: (page.height - CGFloat(rows) * cell.height) / 2
        )
    }

    var labelsPerPage: Int { columns * rows }

    func pageCount(for labelCount: Int) -> Int {
        max(1, Int((Double(labelCount) / Double(labelsPerPage)).rounded(.up)))
    }

    /// Page index and frame (in page coordinates, origin top-left) of the label at `index`.
    func position(of index: Int) -> (page: Int, frame: CGRect) {
        let page = index / labelsPerPage
        let slot = index % labelsPerPage
        let cell = label.size
        let frame = CGRect(
            x: origin.x + CGFloat(slot % columns) * cell.width,
            y: origin.y + CGFloat(slot / columns) * cell.height,
            width: cell.width,
            height: cell.height
        )
        return (page, frame)
    }
}
