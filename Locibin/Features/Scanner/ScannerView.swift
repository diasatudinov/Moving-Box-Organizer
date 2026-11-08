import SwiftUI
import UIKit

/// Full-screen scanner. Always dark, like the system Camera, whatever the app appearance.
struct ScannerView: View {
    let viewModel: ScannerViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        content
            .task { await viewModel.start() }
            .onDisappear(perform: viewModel.stop)
            .sensoryFeedback(.warning, trigger: viewModel.problemFeedbackCount)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .starting, .scanning:
            camera
        case .denied(let restricted):
            NavigationStack {
                ContentUnavailableView {
                    Label("No Access to Camera", systemImage: "camera")
                } description: {
                    if restricted {
                        Text("Camera access is restricted on this device.")
                    } else {
                        Text("The camera is needed only to scan QR codes on your storage places. Allow access in Settings.")
                    }
                } actions: {
                    if !restricted {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .primaryButtonStyle()
                    }
                }
                .toolbar { closeToolbarItem }
            }
        case .unavailable:
            NavigationStack {
                ContentUnavailableView(
                    "Camera Unavailable",
                    systemImage: "camera",
                    description: Text("This device has no camera that can be used for scanning.")
                )
                .toolbar { closeToolbarItem }
            }
        case .problem(let problem):
            CodeProblemView(problem: problem, onScanAgain: viewModel.scanAgain, onClose: viewModel.close)
        }
    }

    private var closeToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close", action: viewModel.close)
        }
    }

    private var camera: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let session = viewModel.previewSession {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }

            VStack(spacing: 24) {
                HStack {
                    Button("Close", systemImage: "xmark", action: viewModel.close)
                        .labelStyle(.iconOnly)
                        .font(.title3.weight(.semibold))
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: .circle)
                    Spacer()
                }

                Text("Point the camera at a place's QR code")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: .capsule)

                ViewfinderFrame()
                    .frame(width: 250, height: 250)
                    .accessibilityHidden(true)

                Spacer()

                if viewModel.hint == .foreignCode {
                    Label("This isn't a code from this app", systemImage: "exclamationmark.circle")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: .capsule)
                        .transition(.opacity)
                }

                if viewModel.hasTorch {
                    Button(viewModel.isTorchOn ? "Turn Flashlight Off" : "Turn Flashlight On",
                           systemImage: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                           action: viewModel.toggleTorch)
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .frame(width: 60, height: 60)
                        .background(.ultraThinMaterial, in: .circle)
                }
            }
            .padding(16)
            .animation(.easeInOut(duration: 0.2), value: viewModel.hint)
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}

/// Four corner brackets marking where to hold the code.
private struct ViewfinderFrame: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let arm: CGFloat = 44
            Path { path in
                path.move(to: CGPoint(x: 0, y: arm)); path.addLine(to: .zero); path.addLine(to: CGPoint(x: arm, y: 0))
                path.move(to: CGPoint(x: size.width - arm, y: 0)); path.addLine(to: CGPoint(x: size.width, y: 0)); path.addLine(to: CGPoint(x: size.width, y: arm))
                path.move(to: CGPoint(x: size.width, y: size.height - arm)); path.addLine(to: CGPoint(x: size.width, y: size.height)); path.addLine(to: CGPoint(x: size.width - arm, y: size.height))
                path.move(to: CGPoint(x: arm, y: size.height)); path.addLine(to: CGPoint(x: 0, y: size.height)); path.addLine(to: CGPoint(x: 0, y: size.height - arm))
            }
            .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
    }
}
