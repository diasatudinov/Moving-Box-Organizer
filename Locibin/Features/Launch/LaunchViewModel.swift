import Foundation
import Observation
import OSLog
import SwiftData

/// Opens the data store at launch and handles the case where it cannot be opened.
@Observable
final class LaunchViewModel {
    enum State {
        case ready(AppDependencies)
        case storeUnavailable
    }

    private(set) var state: State = .storeUnavailable
    var alert: AlertState?

    private let makeContainer: () throws -> ModelContainer
    private let recovery: StoreRecovery

    init(makeContainer: @escaping () throws -> ModelContainer, recovery: StoreRecovery) {
        self.makeContainer = makeContainer
        self.recovery = recovery
        openStore()
    }

    func retry() {
        openStore()
    }

    /// Links from the system Camera (QR labels). Ignored while the store can't be opened.
    func handle(url: URL) {
        guard case .ready(let dependencies) = state else {
            Logger.navigation.notice("Ignored a link: the store is not available")
            return
        }
        dependencies.deepLinks.handle(url: url)
    }

    func startOverTapped() {
        alert = AlertState(
            title: String(localized: "Start Over?", comment: "Confirmation alert title before moving the broken store aside"),
            message: String(localized: "Your current data file will be moved to a separate folder and the app will start empty.", comment: "Confirmation alert message before moving the broken store aside"),
            actions: [
                .cancel(),
                AlertState.Action(title: String(localized: "Start Over", comment: "Store error screen button and destructive alert button"), role: .destructive) { [weak self] in
                    self?.startOver()
                },
            ]
        )
    }

    private func startOver() {
        do {
            let folder = try recovery.moveStoreAside()
            Logger.data.notice("Moved unreadable store aside to \(folder.path(percentEncoded: false), privacy: .private)")
            openStore()
        } catch {
            Logger.data.error("Could not move store aside: \(error.localizedDescription, privacy: .public)")
            alert = AlertState(
                title: String(localized: "Couldn't Start Over", comment: "Alert title when moving the broken store aside failed"),
                message: String(localized: "Please restart the app and try again.", comment: "Alert message when moving the broken store aside failed"),
                actions: [.ok()]
            )
        }
    }

    private func openStore() {
        do {
            let container = try makeContainer()
            state = .ready(AppDependencies(modelContainer: container))
        } catch {
            Logger.data.error("Could not open store: \(error.localizedDescription, privacy: .public)")
            state = .storeUnavailable
        }
    }
}
