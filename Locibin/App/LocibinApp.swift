import SwiftUI

@main
struct LocibinApp: App {
    @State private var launchViewModel = LaunchViewModel(
        makeContainer: { try ModelContainerFactory.makePersistent() },
        recovery: StoreRecovery(storeURL: ModelContainerFactory.persistentStoreURL)
    )

    var body: some Scene {
        WindowGroup {
            AppRootView(viewModel: launchViewModel)
        }
    }
}
