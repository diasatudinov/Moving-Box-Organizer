import SwiftUI

/// Switches between the main navigation and the store error screen.
struct AppRootView: View {
    @Bindable var viewModel: LaunchViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .ready(let dependencies):
                MainNavigationView(router: dependencies.router)
            case .storeUnavailable:
                StoreErrorView(onRetry: viewModel.retry, onStartOver: viewModel.startOverTapped)
            }
        }
        .alert($viewModel.alert)
    }
}

/// The app's single navigation stack. Screens and destinations are added in step 5.3.
private struct MainNavigationView: View {
    @Bindable var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            ContentUnavailableView(
                "Project is set up",
                systemImage: "shippingbox",
                description: Text("Screens will be added in the implementation stage.")
            )
        }
    }
}
