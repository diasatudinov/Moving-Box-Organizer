import SwiftData

/// All schema versions in order. Add a new `SchemaVN` and a migration stage here
/// instead of editing `SchemaV1` once version 1.0 has shipped.
enum LocibinMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
