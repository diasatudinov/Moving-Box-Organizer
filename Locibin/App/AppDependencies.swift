import SwiftData

/// Everything screens need, created once at launch and passed down explicitly.
/// Services and ViewModel factory methods are added here as the features are implemented.
final class AppDependencies {
    let modelContainer: ModelContainer
    let router: AppRouter

    init(modelContainer: ModelContainer, router: AppRouter = AppRouter()) {
        self.modelContainer = modelContainer
        self.router = router
    }

    var modelContext: ModelContext {
        modelContainer.mainContext
    }
}
