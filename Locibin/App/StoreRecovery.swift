import Foundation

/// Moves a store that cannot be opened into a separate folder instead of deleting it,
/// so the user's data is never destroyed silently and can still be recovered later.
struct StoreRecovery {
    let storeURL: URL
    let recoveryDirectory: URL

    init(storeURL: URL, recoveryDirectory: URL? = nil) {
        self.storeURL = storeURL
        self.recoveryDirectory = recoveryDirectory
            ?? storeURL.deletingLastPathComponent().appending(path: "Recovered", directoryHint: .isDirectory)
    }

    /// Moves the store and its SQLite side files (`-shm`, `-wal`) into `Recovered/<timestamp>/`.
    /// - Returns: The folder the files were moved to.
    @discardableResult
    func moveStoreAside(now: Date = .now) throws -> URL {
        let fileManager = FileManager.default
        let destination = recoveryDirectory.appending(
            path: String(Int(now.timeIntervalSince1970)),
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        for suffix in ["", "-shm", "-wal"] {
            let source = URL(filePath: storeURL.path(percentEncoded: false) + suffix)
            guard fileManager.fileExists(atPath: source.path(percentEncoded: false)) else { continue }
            try fileManager.moveItem(at: source, to: destination.appending(path: source.lastPathComponent))
        }
        return destination
    }
}
