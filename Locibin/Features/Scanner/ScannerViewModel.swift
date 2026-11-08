import AVFoundation
import Foundation
import Observation

/// In-app QR scanner (design 2.2, screen 7; flow F6).
/// Opens a scanned place right away, explains codes it can't open, and handles camera permission.
@Observable
final class ScannerViewModel {
    enum State: Equatable {
        case starting
        case scanning
        /// `restricted`: blocked by device management — Settings can't fix it, so no Settings button.
        case denied(restricted: Bool)
        /// No usable camera (for example the Simulator).
        case unavailable
        case problem(CodeProblem)
    }

    enum Hint: Equatable {
        case foreignCode
    }

    private(set) var state: State = .starting
    private(set) var hint: Hint?
    private(set) var isTorchOn = false
    /// Changes on every result, to trigger haptics in the view.
    private(set) var problemFeedbackCount = 0

    static let hintDuration: Duration = .seconds(2)

    private let camera: any CameraScanning
    private let inventory: InventoryService
    private let router: AppRouter
    private let qrCodes: QRCodeService
    @ObservationIgnored private var listeningTask: Task<Void, Never>?
    @ObservationIgnored private var hintTask: Task<Void, Never>?

    init(camera: any CameraScanning, inventory: InventoryService, router: AppRouter, qrCodes: QRCodeService) {
        self.camera = camera
        self.inventory = inventory
        self.router = router
        self.qrCodes = qrCodes
    }

    var previewSession: AVCaptureSession? { camera.previewSession }
    var hasTorch: Bool { camera.hasTorch }

    /// Checks permission, starts the camera and begins reading codes.
    func start() async {
        guard camera.isAvailable else {
            state = .unavailable
            return
        }
        switch camera.authorization {
        case .authorized:
            break
        case .notDetermined:
            guard await camera.requestAccess() else {
                state = .denied(restricted: false)
                return
            }
        case .denied:
            state = .denied(restricted: false)
            return
        case .restricted:
            state = .denied(restricted: true)
            return
        }
        resumeScanning()
        listen()
    }

    /// Handles one recognized text. Ignored unless the scanner is actively scanning,
    /// so a code that stays in view doesn't fire again while a result is shown.
    func handle(code text: String) {
        guard state == .scanning else { return }
        switch qrCodes.parse(text) {
        case .location(let id):
            if (try? inventory.location(id: id)) != nil {
                camera.stop()
                router.showOnlyLocation(id: id)
            } else {
                show(.locationNotFound)
            }
        case .malformedOwnCode:
            show(.damagedCode)
        case .foreign:
            showHint(.foreignCode)
        }
    }

    func scanAgain() {
        resumeScanning()
    }

    func toggleTorch() {
        isTorchOn.toggle()
        camera.setTorch(on: isTorchOn)
    }

    func close() {
        stop()
        router.dismissScanner()
    }

    /// Called when the screen disappears (closed, or replaced by an opened place).
    func stop() {
        listeningTask?.cancel()
        hintTask?.cancel()
        if isTorchOn {
            isTorchOn = false
            camera.setTorch(on: false)
        }
        camera.stop()
    }

    // MARK: - Private

    private func resumeScanning() {
        hint = nil
        state = .scanning
        camera.start()
    }

    private func listen() {
        listeningTask?.cancel()
        let codes = camera.codes
        listeningTask = Task { [weak self] in
            for await code in codes {
                self?.handle(code: code)
            }
        }
    }

    private func show(_ problem: CodeProblem) {
        camera.stop()
        hint = nil
        state = .problem(problem)
        problemFeedbackCount += 1
    }

    private func showHint(_ newHint: Hint) {
        guard hint != newHint else { return }
        hint = newHint
        hintTask?.cancel()
        hintTask = Task { [weak self] in
            try? await Task.sleep(for: Self.hintDuration)
            guard !Task.isCancelled else { return }
            self?.hint = nil
        }
    }
}
