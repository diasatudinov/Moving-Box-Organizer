import Foundation
import SwiftData

/// Creates the app's SwiftData containers.
enum ModelContainerFactory {
    /// Known, fixed location of the on-disk store, so a broken store can be moved aside (see `StoreRecovery`).
    /// Application Support is included in the device's iCloud / computer backups by default.
    static var persistentStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "Locibin.store")
    }

    static var schema: Schema {
        Schema(versionedSchema: SchemaV1.self)
    }

    static func makePersistent() throws -> ModelContainer {
        try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        // CloudKit is switched off explicitly: sync is not part of the MVP and must never turn on by accident.
        let configuration = ModelConfiguration(schema: schema, url: persistentStoreURL, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: LocibinMigrationPlan.self, configurations: configuration)
    }

    /// In-memory container for tests and SwiftUI previews.
    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: LocibinMigrationPlan.self, configurations: configuration)
    }
}
