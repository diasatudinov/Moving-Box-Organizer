import CoreImage
import Foundation
import Testing
import UIKit
@testable import Locibin

struct QRCodeServiceTests {
    private let service = QRCodeService()
    private let id = UUID(uuidString: "3F2B8C1E-7A4D-4E8F-9B21-0C6D5E4A1F90")!

    @Test func payloadUsesTheFixedSchemeAndLowercaseID() {
        #expect(service.payload(for: id) == "com.organizestorage://location/3f2b8c1e-7a4d-4e8f-9b21-0c6d5e4a1f90")
    }

    @Test(arguments: [
        "com.organizestorage://location/3f2b8c1e-7a4d-4e8f-9b21-0c6d5e4a1f90",
        "COM.ORGANIZESTORAGE://LOCATION/3F2B8C1E-7A4D-4E8F-9B21-0C6D5E4A1F90",
        "com.organizestorage://location/3f2b8c1e-7a4d-4e8f-9b21-0c6d5e4a1f90/",
        "com.organizestorage://location/3f2b8c1e-7a4d-4e8f-9b21-0c6d5e4a1f90?source=label",
        "  com.organizestorage://location/3f2b8c1e-7a4d-4e8f-9b21-0c6d5e4a1f90\n",
    ])
    func validCodesOpenTheLocation(text: String) {
        #expect(service.parse(text) == .location(id))
    }

    @Test(arguments: [
        "com.organizestorage://location/not-a-uuid",
        "com.organizestorage://location/",
        "com.organizestorage://box/3f2b8c1e-7a4d-4e8f-9b21-0c6d5e4a1f90",
        "com.organizestorage://location/3f2b8c1e-7a4d-4e8f-9b21-0c6d5e4a1f90/extra",
    ])
    func ourSchemeWithBrokenContentIsMalformed(text: String) {
        #expect(service.parse(text) == .malformedOwnCode)
    }

    @Test(arguments: [
        "https://example.com/location/3f2b8c1e-7a4d-4e8f-9b21-0c6d5e4a1f90",
        "3f2b8c1e-7a4d-4e8f-9b21-0c6d5e4a1f90",
        "Garage, box 3",
        "",
        "organizestorage://location/3f2b8c1e-7a4d-4e8f-9b21-0c6d5e4a1f90",
    ])
    func anythingElseIsForeign(text: String) {
        #expect(service.parse(text) == .foreign)
    }

    @Test func generatedCodeScansBackToTheSamePayload() throws {
        let image = try #require(service.image(for: id))
        let ciImage = try #require(CIImage(image: image))
        let detector = try #require(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))

        let messages = detector.features(in: ciImage).compactMap { ($0 as? CIQRCodeFeature)?.messageString }

        #expect(messages == [service.payload(for: id)])
        #expect(service.parse(messages.first ?? "") == .location(id))
    }

    @Test func matrixHasQuietZoneAndAValidSymbolSize() throws {
        let matrix = try #require(service.matrix(for: id))
        let zone = QRCodeService.quietZone
        let symbol = matrix.size - 2 * zone

        // Valid QR symbol sizes are 21, 25, 29 … (version 1 = 21, +4 per version).
        #expect(symbol >= 21 && (symbol - 21) % 4 == 0)
        // Quiet zone is empty on all four sides.
        for i in 0..<matrix.size {
            for z in 0..<zone {
                #expect(!matrix[i, z] && !matrix[z, i] && !matrix[i, matrix.size - 1 - z] && !matrix[matrix.size - 1 - z, i])
            }
        }
        // Top-left finder pattern starts right after the quiet zone.
        #expect(matrix[zone, zone])
    }
}
