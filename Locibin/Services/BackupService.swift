import Foundation
import OSLog
import SwiftData

/// Export and import of all data as one `.storagebackup` JSON file.
///
/// Import order: read → validate → (user confirms) → save a snapshot of the current data →
/// replace everything in one save. Any failure rolls back, so current data is never half-replaced.
final class BackupService {
    static let maxFileSize = 50 * 1024 * 1024

    private let context: ModelContext
    private let exportDirectory: URL
    /// Where the data from before the last import is kept, so a wrong import can be undone.
    let snapshotURL: URL
    private let appVersion: String

    init(
        context: ModelContext,
        exportDirectory: URL = FileManager.default.temporaryDirectory.appending(path: "Backups", directoryHint: .isDirectory),
        snapshotURL: URL = URL.applicationSupportDirectory.appending(path: "Snapshots/Before last import.storagebackup"),
        appVersion: String = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    ) {
        self.context = context
        self.exportDirectory = exportDirectory
        self.snapshotURL = snapshotURL
        self.appVersion = appVersion
    }

    var hasSnapshot: Bool {
        FileManager.default.fileExists(atPath: snapshotURL.path(percentEncoded: false))
    }

    // MARK: - Export

    func makeDocument(now: Date = .now) throws -> BackupDocument {
        let locations = try context.fetch(FetchDescriptor<StorageLocation>(sortBy: [SortDescriptor(\.createdAt)]))
        let items = try context.fetch(FetchDescriptor<Item>(sortBy: [SortDescriptor(\.createdAt)]))
        let locationRecords = locations.map {
            BackupDocument.LocationRecord(id: $0.id, parentId: $0.parent?.id, name: $0.name, type: $0.kindRaw, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        let itemRecords = items.compactMap { item -> BackupDocument.ItemRecord? in
            guard let locationID = item.location?.id else { return nil }
            return BackupDocument.ItemRecord(id: item.id, locationId: locationID, name: item.name, quantity: item.quantity, note: item.note, createdAt: item.createdAt, updatedAt: item.updatedAt)
        }
        return BackupDocument(
            format: BackupDocument.formatName,
            schemaVersion: BackupDocument.currentSchemaVersion,
            exportedAt: now,
            appVersion: appVersion,
            counts: .init(locations: locationRecords.count, items: itemRecords.count),
            locations: locationRecords,
            items: itemRecords
        )
    }

    /// Writes "Locibin Backup — <date>.storagebackup" and returns its URL for sharing.
    func exportFile(now: Date = .now) throws(BackupError) -> URL {
        do {
            let data = try BackupDocument.encoder().encode(try makeDocument(now: now))
            try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
            let day = now.formatted(date: .abbreviated, time: .omitted)
            let name = String(localized: "Locibin Backup — \(day)", comment: "Backup file name; the argument is a date")
                .replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            let url = exportDirectory.appending(path: "\(name).storagebackup")
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            Logger.backup.error("Export failed: \(error.localizedDescription, privacy: .public)")
            throw .couldNotExport
        }
    }

    // MARK: - Import

    /// Reads and validates a backup. Nothing is changed yet.
    func readBackup(at url: URL) throws(BackupError) -> BackupDocument {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }

        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= Self.maxFileSize else { throw .tooLarge }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            Logger.backup.error("Couldn't read backup: \(error.localizedDescription, privacy: .public)")
            throw .couldNotRead
        }
        return try decode(data)
    }

    func decode(_ data: Data) throws(BackupError) -> BackupDocument {
        let document: BackupDocument
        do {
            document = try BackupDocument.decoder().decode(BackupDocument.self, from: data)
        } catch {
            // Tell "not ours at all" from "ours but broken" by the format marker.
            let marker = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["format"] as? String
            throw marker == BackupDocument.formatName ? .damaged : .notABackup
        }
        try document.validate()
        return document
    }

    /// Current amounts, for the confirmation before replacing.
    func currentCounts() -> BackupDocument.Counts {
        BackupDocument.Counts(
            locations: (try? context.fetchCount(FetchDescriptor<StorageLocation>())) ?? 0,
            items: (try? context.fetchCount(FetchDescriptor<Item>())) ?? 0
        )
    }

    /// Saves a snapshot of the current data, then replaces everything with `document` in one save.
    func replaceAll(with document: BackupDocument) throws(BackupError) {
        try document.validate()
        try saveSnapshot()
        do {
            for location in try context.fetch(FetchDescriptor<StorageLocation>()) where location.parent == nil {
                context.delete(location) // cascades to everything inside
            }
            for orphan in try context.fetch(FetchDescriptor<Item>()) where orphan.location == nil {
                context.delete(orphan)
            }

            var byID: [UUID: StorageLocation] = [:]
            for record in document.locations {
                let location = StorageLocation(id: record.id, name: record.name, kind: LocationKind(storedValue: record.type), createdAt: record.createdAt)
                location.updatedAt = record.updatedAt
                context.insert(location)
                byID[record.id] = location
            }
            for record in document.locations {
                byID[record.id]?.parent = record.parentId.flatMap { byID[$0] }
            }
            for record in document.items {
                let item = Item(id: record.id, name: record.name, quantity: record.quantity, note: record.note, location: byID[record.locationId], createdAt: record.createdAt)
                item.updatedAt = record.updatedAt
                context.insert(item)
            }
            try context.save()
        } catch {
            Logger.backup.error("Import failed, rolling back: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            throw .importFailed
        }
    }

    /// The data from before the last import, if any.
    func readSnapshot() throws(BackupError) -> BackupDocument {
        try readBackup(at: snapshotURL)
    }

    private func saveSnapshot() throws(BackupError) {
        do {
            let data = try BackupDocument.encoder().encode(try makeDocument())
            try FileManager.default.createDirectory(at: snapshotURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: snapshotURL, options: .atomic)
        } catch {
            Logger.backup.error("Couldn't save snapshot: \(error.localizedDescription, privacy: .public)")
            throw .importFailed
        }
    }
}
