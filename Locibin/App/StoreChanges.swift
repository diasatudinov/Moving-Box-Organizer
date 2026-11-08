import Foundation
import SwiftData

/// Tells ViewModels that the store was saved, so they can reload their data.
/// This replaces the automatic updates `@Query` would give inside views.
/// All saves happen on the main context, so the handler runs synchronously on the main actor.
final class StoreChanges {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Calls `handler` after every save of the main context until the returned token is released.
    func observe(_ handler: @escaping @MainActor () -> Void) -> StoreObservation {
        StoreObservation(
            token: NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: context, queue: nil) { _ in
                MainActor.assumeIsolated { handler() }
            }
        )
    }
}

/// Keeps a `StoreChanges` subscription alive; removing the last reference unsubscribes.
nonisolated final class StoreObservation {
    private let token: any NSObjectProtocol

    init(token: any NSObjectProtocol) {
        self.token = token
    }

    deinit {
        NotificationCenter.default.removeObserver(token)
    }
}
