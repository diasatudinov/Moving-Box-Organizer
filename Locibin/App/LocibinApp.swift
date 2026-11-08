import SwiftUI

@main
struct LocibinApp: App {
    var body: some Scene {
        WindowGroup {
            SetupPlaceholderView()
        }
    }
}

/// Temporary root view created during project setup (Stage 4).
/// It is replaced by the real root screen in the implementation stage.
private struct SetupPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Project is set up",
            systemImage: "shippingbox",
            description: Text("Screens will be added in the implementation stage.")
        )
    }
}
