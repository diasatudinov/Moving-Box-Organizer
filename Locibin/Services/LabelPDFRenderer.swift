import Foundation
import UIKit

/// Everything needed to draw one label — plain values, no SwiftData models.
nonisolated struct LabelContent: Sendable {
    let name: String
    /// Localized kind, printed small above the name ("BOX").
    let kindTitle: String
    let qr: QRMatrix
}

/// Draws label sheets as a vector PDF: QR modules are filled rectangles, so codes stay sharp
/// on any printer and the file stays small. Black on white only; dashed cut lines.
/// No path on the label on purpose: it goes stale when a box is moved, the QR never does.
nonisolated struct LabelPDFRenderer: Sendable {
    func render(_ labels: [LabelContent], layout: LabelLayout, title: String) -> Data {
        let pageRect = CGRect(origin: .zero, size: layout.paper.size)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: title, kCGPDFContextCreator as String: "Locibin"]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            let pageCount = layout.pageCount(for: labels.count)
            for page in 0..<pageCount {
                context.beginPage()
                let start = page * layout.labelsPerPage
                let end = min(start + layout.labelsPerPage, labels.count)
                guard start < end else { continue }
                for index in start..<end {
                    draw(labels[index], in: layout.position(of: index).frame, size: layout.label, context: context.cgContext)
                }
            }
        }
    }

    private func draw(_ label: LabelContent, in frame: CGRect, size: LabelSize, context: CGContext) {
        drawCutLine(around: frame, context: context)
        let padding = Millimeters.points(size == .small ? 3 : 6)
        let inner = frame.insetBy(dx: padding, dy: padding)

        switch size {
        case .large:
            let qrSide = min(size.qrSide, inner.height)
            let qrRect = CGRect(x: inner.minX, y: inner.midY - qrSide / 2, width: qrSide, height: qrSide)
            drawQR(label.qr, in: qrRect, context: context)
            let textRect = CGRect(x: qrRect.maxX + Millimeters.points(4), y: inner.minY, width: inner.maxX - qrRect.maxX - Millimeters.points(4), height: inner.height)
            drawText(kind: label.kindTitle, name: label.name, in: textRect, kindSize: 8, nameSize: 16, centered: false, maxNameLines: 4)
        case .small:
            let qrSide = min(size.qrSide, inner.width)
            let qrRect = CGRect(x: inner.midX - qrSide / 2, y: inner.minY, width: qrSide, height: qrSide)
            drawQR(label.qr, in: qrRect, context: context)
            let textRect = CGRect(x: inner.minX, y: qrRect.maxY + Millimeters.points(1), width: inner.width, height: inner.maxY - qrRect.maxY - Millimeters.points(1))
            drawText(kind: nil, name: label.name, in: textRect, kindSize: 0, nameSize: 9, centered: true, maxNameLines: 2)
        }
    }

    private func drawCutLine(around frame: CGRect, context: CGContext) {
        context.saveGState()
        context.setStrokeColor(UIColor(white: 0.6, alpha: 1).cgColor)
        context.setLineWidth(0.5)
        context.setLineDash(phase: 0, lengths: [3, 3])
        context.stroke(frame.insetBy(dx: 0.25, dy: 0.25))
        context.restoreGState()
    }

    /// Fills each horizontal run of dark modules as one rectangle.
    private func drawQR(_ matrix: QRMatrix, in rect: CGRect, context: CGContext) {
        let module = rect.width / CGFloat(matrix.size)
        context.saveGState()
        context.setFillColor(UIColor.black.cgColor)
        for y in 0..<matrix.size {
            var x = 0
            while x < matrix.size {
                guard matrix[x, y] else { x += 1; continue }
                let runStart = x
                while x < matrix.size && matrix[x, y] { x += 1 }
                context.fill(CGRect(
                    x: rect.minX + CGFloat(runStart) * module,
                    y: rect.minY + CGFloat(y) * module,
                    width: CGFloat(x - runStart) * module,
                    height: module
                ))
            }
        }
        context.restoreGState()
    }

    private func drawText(kind: String?, name: String, in rect: CGRect, kindSize: CGFloat, nameSize: CGFloat, centered: Bool, maxNameLines: Int) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = centered ? .center : .left
        paragraph.lineBreakMode = .byWordWrapping

        var nameTop = rect.minY
        if let kind, !kind.isEmpty {
            let kindText = NSAttributedString(string: kind.uppercased(with: .current), attributes: [
                .font: UIFont.systemFont(ofSize: kindSize, weight: .semibold),
                .foregroundColor: UIColor.black,
                .kern: 0.6,
                .paragraphStyle: paragraph,
            ])
            let kindHeight = kindText.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin], context: nil).height
            // Vertically center kind + name as a block for the large label.
            let nameFont = UIFont.systemFont(ofSize: nameSize, weight: .bold)
            let nameHeight = min(nameFont.lineHeight * CGFloat(maxNameLines), nameText(name, size: nameSize, paragraph: paragraph).boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).height)
            let blockTop = rect.minY + max(0, (rect.height - kindHeight - 4 - nameHeight) / 2)
            kindText.draw(with: CGRect(x: rect.minX, y: blockTop, width: rect.width, height: kindHeight), options: [.usesLineFragmentOrigin], context: nil)
            nameTop = blockTop + kindHeight + 4
        }

        let font = UIFont.systemFont(ofSize: nameSize, weight: .bold)
        let nameRect = CGRect(x: rect.minX, y: nameTop, width: rect.width, height: min(rect.maxY - nameTop, font.lineHeight * CGFloat(maxNameLines)))
        nameText(name, size: nameSize, paragraph: paragraph).draw(
            with: nameRect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            context: nil
        )
    }

    private func nameText(_ name: String, size: CGFloat, paragraph: NSParagraphStyle) -> NSAttributedString {
        NSAttributedString(string: name, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: .bold),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph,
        ])
    }
}
