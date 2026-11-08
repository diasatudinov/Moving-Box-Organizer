import AVFoundation
import Foundation
import Testing
@testable import Locibin

/// Camera stand-in: controllable permission, records start/stop, lets tests feed codes.
nonisolated final class FakeCamera: CameraScanning, @unchecked Sendable {
    var authorization: CameraAuthorization
    var isAvailable = true
    var hasTorch = true
    var grantsAccess = true
    let codes: AsyncStream<String>
    let continuation: AsyncStream<String>.Continuation
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var torchOn = false

    init(authorization: CameraAuthorization = .authorized) {
        self.authorization = authorization
        (codes, continuation) = AsyncStream.makeStream(of: String.self)
    }

    var previewSession: AVCaptureSession? { nil }
    func requestAccess() async -> Bool { grantsAccess }
    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
    func setTorch(on: Bool) { torchOn = on }
}

struct ScannerViewModelTests {
    private func make(_ fixture: InventoryFixture, camera: FakeCamera, router: AppRouter = AppRouter()) -> ScannerViewModel {
        ScannerViewModel(camera: camera, inventory: fixture.service, router: router, qrCodes: QRCodeService())
    }

    @Test func authorizedCameraStartsScanning() async throws {
        let fixture = try InventoryFixture()
        let camera = FakeCamera()
        let scanner = make(fixture, camera: camera)

        await scanner.start()

        #expect(scanner.state == .scanning)
        #expect(camera.startCount == 1)
    }

    @Test func firstUseAsksForPermission() async throws {
        let fixture = try InventoryFixture()

        let granted = FakeCamera(authorization: .notDetermined)
        let grantedScanner = make(fixture, camera: granted)
        await grantedScanner.start()
        #expect(grantedScanner.state == .scanning)

        let refused = FakeCamera(authorization: .notDetermined)
        refused.grantsAccess = false
        let refusedScanner = make(fixture, camera: refused)
        await refusedScanner.start()
        #expect(refusedScanner.state == .denied(restricted: false))
        #expect(refused.startCount == 0)
    }

    @Test func deniedAndRestrictedNeverStartTheCamera() async throws {
        let fixture = try InventoryFixture()

        let denied = FakeCamera(authorization: .denied)
        let deniedScanner = make(fixture, camera: denied)
        await deniedScanner.start()
        #expect(deniedScanner.state == .denied(restricted: false))

        let restricted = FakeCamera(authorization: .restricted)
        let restrictedScanner = make(fixture, camera: restricted)
        await restrictedScanner.start()
        #expect(restrictedScanner.state == .denied(restricted: true))

        #expect(denied.startCount == 0 && restricted.startCount == 0)
    }

    @Test func noCameraIsUnavailable() async throws {
        let fixture = try InventoryFixture()
        let camera = FakeCamera()
        camera.isAvailable = false
        let scanner = make(fixture, camera: camera)

        await scanner.start()

        #expect(scanner.state == .unavailable)
    }

    @Test func scanningAKnownPlaceOpensItAndClosesTheScanner() async throws {
        let fixture = try InventoryFixture()
        let camera = FakeCamera()
        let router = AppRouter()
        router.presentScanner()
        let scanner = make(fixture, camera: camera, router: router)
        await scanner.start()

        scanner.handle(code: QRCodeService().payload(for: fixture.box.id))

        #expect(router.path == [.location(fixture.box.id)])
        #expect(!router.isScannerPresented)
        #expect(camera.stopCount == 1)
    }

    @Test func unknownPlaceShowsNotFoundAndScanAgainResumes() async throws {
        let fixture = try InventoryFixture()
        let camera = FakeCamera()
        let router = AppRouter()
        let scanner = make(fixture, camera: camera, router: router)
        await scanner.start()

        scanner.handle(code: QRCodeService().payload(for: UUID()))
        #expect(scanner.state == .problem(.locationNotFound))
        #expect(scanner.problemFeedbackCount == 1)
        #expect(router.path.isEmpty)

        // A code still in view is ignored while the result is shown.
        scanner.handle(code: QRCodeService().payload(for: fixture.box.id))
        #expect(router.path.isEmpty)

        scanner.scanAgain()
        #expect(scanner.state == .scanning)
        #expect(camera.startCount == 2)
    }

    @Test func damagedCodeIsNotRecognized() async throws {
        let fixture = try InventoryFixture()
        let scanner = make(fixture, camera: FakeCamera())
        await scanner.start()

        scanner.handle(code: "com.organizestorage://location/broken")

        #expect(scanner.state == .problem(.damagedCode))
    }

    @Test func foreignCodeShowsAHintAndKeepsScanning() async throws {
        let fixture = try InventoryFixture()
        let scanner = make(fixture, camera: FakeCamera())
        await scanner.start()

        scanner.handle(code: "https://example.com")

        #expect(scanner.state == .scanning)
        #expect(scanner.hint == .foreignCode)
    }

    @Test func codesFromTheCameraStreamAreHandled() async throws {
        let fixture = try InventoryFixture()
        let camera = FakeCamera()
        let router = AppRouter()
        let scanner = make(fixture, camera: camera, router: router)
        await scanner.start()

        camera.continuation.yield(QRCodeService().payload(for: fixture.shelf.id))
        for _ in 0..<50 where router.path.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(router.path == [.location(fixture.shelf.id)])
    }

    @Test func torchTogglesAndIsTurnedOffWhenClosing() async throws {
        let fixture = try InventoryFixture()
        let camera = FakeCamera()
        let router = AppRouter()
        router.presentScanner()
        let scanner = make(fixture, camera: camera, router: router)
        await scanner.start()

        scanner.toggleTorch()
        #expect(scanner.isTorchOn && camera.torchOn)

        scanner.close()
        #expect(!camera.torchOn)
        #expect(!router.isScannerPresented)
    }

    @Test func linkWhileScannerIsOpenClosesIt() throws {
        let fixture = try InventoryFixture()
        let dependencies = AppDependencies(modelContainer: fixture.container)
        dependencies.router.presentScanner()

        dependencies.deepLinks.handle(url: QRCodeService().url(for: fixture.box.id))

        #expect(!dependencies.router.isScannerPresented)
        #expect(dependencies.router.path == [.location(fixture.box.id)])
    }

    @Test func homeScanButtonOpensScanner() throws {
        let fixture = try InventoryFixture()
        let router = AppRouter()
        let home = HomeViewModel(inventory: fixture.service, router: router, storeChanges: StoreChanges(context: fixture.context))

        home.scanTapped()

        #expect(router.isScannerPresented)
    }
}
