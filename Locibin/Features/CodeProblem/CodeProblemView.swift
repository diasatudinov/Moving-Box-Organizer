import SwiftUI

/// "Place not found" / "Code not recognized" after a scan or a link (design 2.2, screen 8).
/// Static screen: the texts depend only on the problem, so it has no ViewModel.
/// "Scan Again" is added together with the scanner in step 5.6.
struct CodeProblemView: View {
    let problem: CodeProblem
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
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
                case .damagedCode:
                    Text("This QR code looks damaged or was made by a newer version of the app.")
                }
            }
            Spacer()
            Button(action: onClose) {
                Text("Close").frame(maxWidth: .infinity)
            }
            .primaryButtonStyle()
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .sensoryFeedback(.warning, trigger: problem)
    }
}

#Preview {
    CodeProblemView(problem: .locationNotFound, onClose: {})
}
