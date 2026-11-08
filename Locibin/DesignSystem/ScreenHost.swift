import SwiftUI

/// Creates a screen's ViewModel exactly once and keeps it for the screen's lifetime.
/// (`@State` initial values are re-evaluated on every parent update, so creating the
/// ViewModel in an initializer would build throw-away instances.)
struct ScreenHost<ViewModel: AnyObject, Content: View>: View {
    let makeViewModel: () -> ViewModel
    @ViewBuilder let content: (ViewModel) -> Content

    @State private var viewModel: ViewModel?

    var body: some View {
        if let viewModel {
            content(viewModel)
        } else {
            Color.clear.onAppear { viewModel = makeViewModel() }
        }
    }
}
