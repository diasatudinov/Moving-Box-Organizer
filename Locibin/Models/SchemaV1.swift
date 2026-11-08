import Foundation
import SwiftData

typealias StorageLocation = SchemaV1.StorageLocation
typealias Item = SchemaV1.Item

/// First version of the persistent schema.
///
/// Rules kept on purpose so that iCloud (CloudKit) sync stays possible later without a migration:
/// no `@Attribute(.unique)`, every stored property has a default value, every relationship is optional.
/// The stable identifier for QR codes and backups is `id`, never `persistentModelID`.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [StorageLocation.self, Item.self]
    }

    @Model
    final class StorageLocation {
        var id: UUID = UUID()
        var name: String = ""
        var kindRaw: String = LocationKind.other.rawValue
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now

        var parent: StorageLocation?

        @Relationship(deleteRule: .cascade, inverse: \StorageLocation.parent)
        var children: [StorageLocation]? = []

        @Relationship(deleteRule: .cascade, inverse: \Item.location)
        var items: [Item]? = []

        var kind: LocationKind {
            get { LocationKind(storedValue: kindRaw) }
            set { kindRaw = newValue.rawValue }
        }

        init(id: UUID = UUID(), name: String, kind: LocationKind, parent: StorageLocation? = nil, createdAt: Date = .now) {
            self.id = id
            self.name = name
            self.kindRaw = kind.rawValue
            self.parent = parent
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    @Model
    final class Item {
        var id: UUID = UUID()
        var name: String = ""
        var quantity: Int?
        var note: String?
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now

        /// Always set inside the app; optional only because SwiftData/CloudKit require optional relationships.
        var location: StorageLocation?

        init(id: UUID = UUID(), name: String, quantity: Int? = nil, note: String? = nil, location: StorageLocation?, createdAt: Date = .now) {
            self.id = id
            self.name = name
            self.quantity = quantity
            self.note = note
            self.location = location
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }
}
