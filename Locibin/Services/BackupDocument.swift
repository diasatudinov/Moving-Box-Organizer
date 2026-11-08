import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// `.storagebackup` files. Declared in Config/Locibin-Info.plist; fixed once released.
    nonisolated static let storageBackup = UTType(exportedAs: "com.organizestorage.backup", conformingTo: .json)
}

/// The backup file format (design 3.3). Flat lists linked by ids — easy to validate, and the
/// UUIDs are kept on import, so printed QR labels keep working on the new iPhone.
nonisolated struct BackupDocument: Codable, Equatable, Sendable {
    static let formatName = "storage-backup"
    static let currentSchemaVersion = 1

    struct Counts: Codable, Equatable, Sendable {
        var locations: Int
        var items: Int
    }

    struct LocationRecord: Codable, Equatable, Sendable {
        var id: UUID
        var parentId: UUID?
        var name: String
        /// `LocationKind` raw value; unknown values become "other" on import.
        var type: String
        var createdAt: Date
        var updatedAt: Date
    }

    struct ItemRecord: Codable, Equatable, Sendable {
        var id: UUID
        var locationId: UUID
        var name: String
        var quantity: Int?
        var note: String?
        var createdAt: Date
        var updatedAt: Date
    }

    var format: String
    var schemaVersion: Int
    var exportedAt: Date
    var appVersion: String
    var counts: Counts
    var locations: [LocationRecord]
    var items: [ItemRecord]

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Checks everything that could break the hierarchy before anything is replaced.
    func validate() throws(BackupError) {
        guard format == Self.formatName else { throw .notABackup }
        guard schemaVersion <= Self.currentSchemaVersion else { throw .newerVersion }
        guard schemaVersion >= 1, counts == Counts(locations: locations.count, items: items.count) else { throw .damaged }

        var parents: [UUID: UUID?] = [:]
        for location in locations {
            guard parents.updateValue(location.parentId, forKey: location.id) == nil,
                  !location.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw .damaged }
        }
        for case let parentID? in parents.values where parents[parentID] == nil {
            throw .damaged
        }
        // No cycles: walking up from any location must reach the top level.
        for start in parents.keys {
            var current: UUID? = start
            var steps = 0
            while let id = current {
                steps += 1
                guard steps <= parents.count else { throw .damaged }
                current = parents[id] ?? nil
            }
        }

        var itemIDs = Set<UUID>()
        for item in items {
            guard itemIDs.insert(item.id).inserted,
                  parents[item.locationId] != nil,
                  !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.quantity.map({ $0 >= 1 }) ?? true
            else { throw .damaged }
        }
    }
}

nonisolated enum BackupError: LocalizedError, Equatable, Sendable {
    case notABackup
    case newerVersion
    case damaged
    case tooLarge
    case couldNotRead
    case couldNotExport
    case importFailed

    var errorDescription: String? {
        String(localized: message)
    }

    var message: LocalizedStringResource {
        switch self {
        case .notABackup:
            LocalizedStringResource("This file isn't a backup of this app.", comment: "Import error")
        case .newerVersion:
            LocalizedStringResource("This backup was made by a newer version of the app. Update the app and try again.", comment: "Import error")
        case .damaged:
            LocalizedStringResource("The backup file is damaged and can't be imported. Your current data hasn't changed.", comment: "Import error")
        case .tooLarge:
            LocalizedStringResource("The file is too large to be a backup of this app.", comment: "Import error")
        case .couldNotRead:
            LocalizedStringResource("Couldn't open the file. Try again.", comment: "Import error")
        case .couldNotExport:
            LocalizedStringResource("Couldn't create the backup file. Try again.", comment: "Export error")
        case .importFailed:
            LocalizedStringResource("Couldn't import the backup. Your current data hasn't changed.", comment: "Import error")
        }
    }
}
