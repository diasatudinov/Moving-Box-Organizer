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

    func startOverTapped() {
        alert = AlertState(
            title: "Start Over?",
            message: "Your current data file will be moved to a separate folder and the app will start empty.",
            actions: [
                .cancel(),
                AlertState.Action(title: "Start Over", role: .destructive) { [weak self] in
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
                title: "Couldn't Start Over",
                message: "Please restart the app and try again.",
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
