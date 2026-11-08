@preconcurrency import AVFoundation
import Foundation

/// Camera permission as the scanner needs it.
nonisolated enum CameraAuthorization: Sendable {
    case notDetermined
    case authorized
    case denied
    /// Blocked by parental controls or device management — the user can't change it in Settings.
    case restricted
}

/// What the scanner screen needs from a camera. A protocol only because the real camera
/// can't run in tests or the Simulator; `ScannerViewModel` is tested with a fake.
nonisolated protocol CameraScanning: AnyObject, Sendable {
    var authorization: CameraAuthorization { get }
    var isAvailable: Bool { get }
    var hasTorch: Bool { get }
    /// Text of every QR code the camera recognizes.
    var codes: AsyncStream<String> { get }
    /// The session to show in a preview layer; `nil` for fakes.
    var previewSession: AVCaptureSession? { get }

    func requestAccess() async -> Bool
    func start()
    func stop()
    func setTorch(on: Bool)
}

/// Real camera: an `AVCaptureSession` with a QR metadata output.
///
/// Concurrency: the session is not `Sendable`. Every session call runs on `queue`
/// (`startRunning()` blocks, so it must never run on the main thread). That single rule is
/// why the class can be `@unchecked Sendable`.
nonisolated final class CameraScanner: NSObject, CameraScanning, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let codes: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.diasiosdev.locibin.camera")
    private let device = AVCaptureDevice.default(for: .video)
    private var isConfigured = false

    override init() {
        (codes, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1))
        super.init()
    }

    deinit {
        continuation.finish()
    }

    var authorization: CameraAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        default: .denied
        }
    }

    var isAvailable: Bool { device != nil }
    var hasTorch: Bool { device?.hasTorch ?? false }
    var previewSession: AVCaptureSession? { session }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func start() {
        queue.async { [self] in
            configureIfNeeded()
            if isConfigured, !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func setTorch(on: Bool) {
        queue.async { [self] in
            guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        }
    }

    // Runs on `queue`.
    private func configureIfNeeded() {
        guard !isConfigured, let device, let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: queue)
        output.metadataObjectTypes = [.qr]
        isConfigured = true
    }

    // Called on `queue`.
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        for case let code as AVMetadataMachineReadableCodeObject in metadataObjects where code.type == .qr {
            if let text = code.stringValue {
                continuation.yield(text)
            }
        }
    }
}
