import SwiftUI

/// "Place not found" / "Code not recognized" after a scan or a link (design 2.2, screen 8).
/// Static screen: the texts depend only on the problem, so it has no ViewModel.
/// The scanner passes `onScanAgain`; a link from the system Camera has only "Close".
struct CodeProblemView: View {
    let problem: CodeProblem
    var onScanAgain: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        ScrollableFullScreen {
            ContentUnavailableView {
                switch problem {
                case .locationNotFound:
                    Label("Place Not Found", systemImage: "questionmark.folder")
                case .damagedCode:
                    Label("Code Not Recognized", systemImage: "qrcode")
                }
            } description: {
                switch problem {
                case .locationNotFound:
                    Text("This place isn't in the app. It may have been deleted, or its data is on another iPhone.")
                    .emptyStateDescriptionStyle()
                case .damagedCode:
                    Text("This QR code looks damaged or was made by a newer version of the app.")
                    .emptyStateDescriptionStyle()
                }
            }
        }
        // Buttons stay pinned at the bottom; the text above scrolls at large text sizes.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if let onScanAgain {
                    Button(action: onScanAgain) {
                        Text("Scan Again").frame(maxWidth: .infinity)
                    }
                    .primaryButtonStyle()
                    Button(action: onClose) {
                        Text("Close").frame(maxWidth: .infinity)
                    }
                    .secondaryButtonStyle()
                } else {
                    Button(action: onClose) {
                        Text("Close").frame(maxWidth: .infinity)
                    }
                    .primaryButtonStyle()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .sensoryFeedback(.warning, trigger: problem)
    }
}

#Preview {
    CodeProblemView(problem: .locationNotFound, onScanAgain: {}, onClose: {})
}
