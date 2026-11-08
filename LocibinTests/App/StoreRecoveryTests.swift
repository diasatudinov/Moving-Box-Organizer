import Foundation
import Testing
@testable import Locibin

struct StoreRecoveryTests {
    @Test func movesStoreAndSideFilesIntoTimestampedFolder() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = root.appending(path: "Locibin.store")
        for suffix in ["", "-shm", "-wal"] {
            try Data("x".utf8).write(to: URL(filePath: store.path(percentEncoded: false) + suffix))
        }

        let recovery = StoreRecovery(storeURL: store)
        let folder = try recovery.moveStoreAside(now: Date(timeIntervalSince1970: 1_000))

        #expect(folder == root.appending(path: "Recovered/1000", directoryHint: .isDirectory))
        let moved = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).sorted()
        #expect(moved == ["Locibin.store", "Locibin.store-shm", "Locibin.store-wal"])
        #expect(!FileManager.default.fileExists(atPath: store.path(percentEncoded: false)))
    }

    @Test func missingSideFilesAreNotAnError() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = root.appending(path: "Locibin.store")
        try Data("x".utf8).write(to: store)

        let folder = try StoreRecovery(storeURL: store).moveStoreAside()

        let moved = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
        #expect(moved == ["Locibin.store"])
    }
}
