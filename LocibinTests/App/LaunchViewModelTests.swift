import Foundation
import SwiftData
import Testing
@testable import Locibin

struct LaunchViewModelTests {
    private struct StoreBroken: Error {}

    @Test func opensStoreAtLaunch() throws {
        let viewModel = LaunchViewModel(makeContainer: { try makeTestContainer() }, recovery: try makeRecovery())
        #expect(isReady(viewModel))
    }

    @Test func showsErrorStateWhenStoreCannotBeOpenedAndRetryRecovers() throws {
        var attempts = 0
        let viewModel = LaunchViewModel(
            makeContainer: {
                attempts += 1
                if attempts == 1 { throw StoreBroken() }
                return try makeTestContainer()
            },
            recovery: try makeRecovery()
        )
        #expect(!isReady(viewModel))

        viewModel.retry()

        #expect(isReady(viewModel))
        #expect(attempts == 2)
    }

    @Test func startOverAsksForConfirmationFirst() throws {
        let viewModel = LaunchViewModel(makeContainer: { throw StoreBroken() }, recovery: try makeRecovery())

        viewModel.startOverTapped()

        let alert = try #require(viewModel.alert)
        #expect(alert.actions.map(\.role) == [.cancel, .destructive])
        #expect(!isReady(viewModel), "Nothing may happen before the user confirms")
    }

    @Test func confirmingStartOverMovesStoreAsideAndOpensFreshStore() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = root.appending(path: "Locibin.store")
        try Data("corrupted".utf8).write(to: store)

        var storeIsBroken = true
        let viewModel = LaunchViewModel(
            makeContainer: {
                if storeIsBroken { throw StoreBroken() }
                return try makeTestContainer()
            },
            recovery: StoreRecovery(storeURL: store)
        )
        viewModel.startOverTapped()
        storeIsBroken = false

        try #require(viewModel.alert?.actions.first { $0.role == .destructive }).handler()

        #expect(isReady(viewModel))
        #expect(!FileManager.default.fileExists(atPath: store.path(percentEncoded: false)))
        let recovered = root.appending(path: "Recovered", directoryHint: .isDirectory)
        #expect(FileManager.default.fileExists(atPath: recovered.path(percentEncoded: false)))
    }

    private func isReady(_ viewModel: LaunchViewModel) -> Bool {
        if case .ready = viewModel.state { true } else { false }
    }

    private func makeRecovery() throws -> StoreRecovery {
        StoreRecovery(storeURL: FileManager.default.temporaryDirectory.appending(path: "Unused-\(UUID().uuidString).store"))
    }
}
