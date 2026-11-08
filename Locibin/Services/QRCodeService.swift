import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

/// What a scanned QR code or an opened link turned out to be.
nonisolated enum ScannedCode: Equatable, Sendable {
    /// One of our labels.
    case location(UUID)
    /// Our scheme, but the rest is broken (damaged label or a format from a newer app version).
    case malformedOwnCode
    /// Anything else: a website, plain text, another app's code.
    case foreign
}

/// Square grid of QR modules, `true` = dark. Includes the quiet zone.
nonisolated struct QRMatrix: Equatable, Sendable {
    let size: Int
    private let modules: [Bool]

    init(size: Int, modules: [Bool]) {
        precondition(modules.count == size * size)
        self.size = size
        self.modules = modules
    }

    subscript(x: Int, y: Int) -> Bool {
        modules[y * size + x]
    }
}

/// QR codes for storage locations. The code holds only a stable link with the location's id —
/// never its name or contents — so renaming or repacking never requires a new label.
///
/// Format (fixed forever once labels are printed): `com.organizestorage://location/<uuid>`.
nonisolated struct QRCodeService: Sendable {
    static let scheme = "com.organizestorage"
    static let locationHost = "location"
    /// Empty modules around the code required by the QR standard for reliable scanning.
    static let quietZone = 4

    func payload(for locationID: UUID) -> String {
        "\(Self.scheme)://\(Self.locationHost)/\(locationID.uuidString.lowercased())"
    }

    func url(for locationID: UUID) -> URL {
        URL(string: payload(for: locationID))!
    }

    /// Strict parsing of scanned text. Content is untrusted: it is only matched, never executed.
    func parse(_ text: String) -> ScannedCode {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return .foreign }
        return parse(url: url)
    }

    func parse(url: URL) -> ScannedCode {
        guard url.scheme?.lowercased() == Self.scheme else { return .foreign }
        let components = url.pathComponents.filter { $0 != "/" }
        guard url.host()?.lowercased() == Self.locationHost,
              components.count == 1,
              let id = UUID(uuidString: components[0])
        else { return .malformedOwnCode }
        return .location(id)
    }

    /// The code as a module grid with the quiet zone, error correction level Q (~25%)
    /// so that scuffed labels in a garage still scan.
    func matrix(for payload: String) -> QRMatrix? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "Q"
        guard let output = filter.outputImage,
              let cgImage = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(output, from: output.extent)
        else { return nil }
        return Self.matrix(from: cgImage)
    }

    func matrix(for locationID: UUID) -> QRMatrix? {
        matrix(for: payload(for: locationID))
    }

    /// Black-on-white image with crisp modules for showing on screen.
    func image(for locationID: UUID, pointsPerModule: CGFloat = 8) -> UIImage? {
        guard let matrix = matrix(for: locationID) else { return nil }
        let side = CGFloat(matrix.size) * pointsPerModule
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            UIColor.black.setFill()
            for y in 0..<matrix.size {
                for x in 0..<matrix.size where matrix[x, y] {
                    context.fill(CGRect(x: CGFloat(x) * pointsPerModule, y: CGFloat(y) * pointsPerModule, width: pointsPerModule, height: pointsPerModule))
                }
            }
        }
    }

    /// Reads Core Image's one-pixel-per-module output, crops it to the symbol (Core Image adds
    /// its own margin) and adds our quiet zone — so the result doesn't depend on Core Image defaults.
    private static func matrix(from image: CGImage) -> QRMatrix? {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 255, count: width * height)
        guard let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        func isDark(_ x: Int, _ y: Int) -> Bool { pixels[y * width + x] < 128 }

        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where isDark(x, y) {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        let symbolSize = maxX - minX + 1
        guard maxX >= 0, symbolSize == maxY - minY + 1 else { return nil }

        let size = symbolSize + 2 * quietZone
        var modules = [Bool](repeating: false, count: size * size)
        for y in 0..<symbolSize {
            for x in 0..<symbolSize {
                modules[(y + quietZone) * size + (x + quietZone)] = isDark(minX + x, minY + y)
            }
        }
        return QRMatrix(size: size, modules: modules)
    }
}
