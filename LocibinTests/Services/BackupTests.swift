import Foundation
import SwiftData
import Testing
@testable import Locibin

/// Backup service on a fresh in-memory store with its own temporary folders.
private struct BackupFixture {
    let inventory: InventoryFixture
    let service: BackupService
    let folder: URL

    init() throws {
        inventory = try InventoryFixture()
        folder = try makeTemporaryDirectory()
        service = BackupService(
            context: inventory.context,
            exportDirectory: folder.appending(path: "Export", directoryHint: .isDirectory),
            snapshotURL: folder.appending(path: "Snapshots/last.storagebackup"),
            appVersion: "1.0"
        )
    }

    func cleanUp() { try? FileManager.default.removeItem(at: folder) }

    /// Returns the container too: a `ModelContext` must not outlive its container.
    func emptyStoreService() throws -> (BackupService, ModelContainer) {
        let container = try makeTestContainer()
        let service = BackupService(context: container.mainContext, exportDirectory: folder.appending(path: "Export2"), snapshotURL: folder.appending(path: "Snapshots2/last.storagebackup"))
        return (service, container)
    }
}

struct BackupServiceTests {
    @Test func exportedFileHasTheAgreedFormat() throws {
        let fixture = try BackupFixture()
        defer { fixture.cleanUp() }

        let url = try fixture.service.exportFile()
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])

        #expect(url.pathExtension == "storagebackup")
        #expect(json["format"] as? String == "storage-backup")
        #expect(json["schemaVersion"] as? Int == 1)
        #expect((json["counts"] as? [String: Int]) == ["locations": 7, "items": 6])
        let first = try #require((json["locations"] as? [[String: Any]])?.first)
        #expect(Set(first.keys).isSubset(of: ["id", "parentId", "name", "type", "createdAt", "updatedAt"]))
        #expect(Set(first.keys).isSuperset(of: ["id", "name", "type", "createdAt", "updatedAt"]))
    }

    @Test func exportThenImportIntoAnEmptyStoreKeepsEverythingAndTheSameIDs() throws {
        let fixture = try BackupFixture()
        defer { fixture.cleanUp() }
        let url = try fixture.service.exportFile()

        let (target, container) = try fixture.emptyStoreService()
        let context = container.mainContext
        let document = try target.readBackup(at: url)
        try target.replaceAll(with: document)

        let inventory = InventoryService(context: context)
        let shelf = try #require(try inventory.location(id: fixture.inventory.shelf.id))
        #expect(inventory.path(to: shelf).map(\.name) == ["Garage", "Rack 1", "Shelf 1"])
        #expect(inventory.items(in: shelf).map(\.name) == ["Bosch drill", "Screwdriver set"])
        let drill = try #require(try inventory.item(id: fixture.inventory.drill.id))
        #expect(drill.note == "In the case")
        let fuses = try #require(try inventory.search("Fuses").items.first)
        #expect(fuses.quantity == 10)
        #expect(try context.fetchCount(FetchDescriptor<StorageLocation>()) == 7)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 6)
        // Printed labels keep working: a deep link with the old id opens the same place.
        #expect(try inventory.location(id: fixture.inventory.box.id)?.name == "Box 2")
    }

    @Test func importReplacesExistingDataAndKeepsASnapshotThatRestoresIt() throws {
        let fixture = try BackupFixture()
        defer { fixture.cleanUp() }
        let original = try fixture.service.makeDocument()

        // Import a tiny different backup over the fixture data.
        let (other, otherContainer) = try fixture.emptyStoreService()
        let otherContext = otherContainer.mainContext
        let otherInventory = InventoryService(context: otherContext)
        try otherInventory.createLocation(name: "Basement", kind: .room, parentID: nil)
        let small = try other.makeDocument()

        #expect(!fixture.service.hasSnapshot)
        try fixture.service.replaceAll(with: small)

        let context = fixture.inventory.context
        #expect(try context.fetchCount(FetchDescriptor<StorageLocation>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
        #expect(fixture.service.hasSnapshot)

        let snapshot = try fixture.service.readSnapshot()
        #expect(snapshot.counts == original.counts)
        try fixture.service.replaceAll(with: snapshot)
        #expect(try context.fetchCount(FetchDescriptor<StorageLocation>()) == 7)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 6)
    }

    @Test func unknownKindBecomesOther() throws {
        let fixture = try BackupFixture()
        defer { fixture.cleanUp() }
        var document = try fixture.service.makeDocument()
        document.locations[0].type = "spaceship"

        let (target, container) = try fixture.emptyStoreService()
        let context = container.mainContext
        try target.replaceAll(with: document)

        let location = try #require(try InventoryService(context: context).location(id: document.locations[0].id))
        #expect(location.kind == .other)
    }
}

struct BackupValidationTests {
    private func validDocument() throws -> BackupDocument {
        let fixture = try BackupFixture()
        defer { fixture.cleanUp() }
        return try fixture.service.makeDocument()
    }

    private func decodeError(_ data: Data) throws -> BackupError? {
        let container = try makeTestContainer()
        let service = BackupService(context: container.mainContext)
        do {
            _ = try service.decode(data)
            return nil
        } catch {
            return error
        }
    }

    @Test func notJSONOrOtherJSONIsNotABackup() throws {
        #expect(try decodeError(Data("hello".utf8)) == .notABackup)
        #expect(try decodeError(Data(#"{"name":"something else"}"#.utf8)) == .notABackup)
    }

    @Test func ourMarkerWithBrokenContentIsDamaged() throws {
        #expect(try decodeError(Data(#"{"format":"storage-backup","schemaVersion":1}"#.utf8)) == .damaged)
    }

    @Test func newerSchemaAsksToUpdateTheApp() throws {
        var document = try validDocument()
        document.schemaVersion = 2
        #expect(throws: BackupError.newerVersion) { try document.validate() }
    }

    @Test func wrongFormatMarker() throws {
        var document = try validDocument()
        document.format = "other"
        #expect(throws: BackupError.notABackup) { try document.validate() }
    }

    @Test func duplicateIDsAreDamaged() throws {
        var document = try validDocument()
        document.locations[1].id = document.locations[0].id
        #expect(throws: BackupError.damaged) { try document.validate() }
    }

    @Test func missingParentIsDamaged() throws {
        var document = try validDocument()
        document.locations[1].parentId = UUID()
        #expect(throws: BackupError.damaged) { try document.validate() }
    }

    @Test func parentCycleIsDamaged() throws {
        var document = try validDocument()
        let garage = try #require(document.locations.firstIndex { $0.name == "Garage" })
        let rack = try #require(document.locations.first { $0.name == "Rack 1" })
        document.locations[garage].parentId = rack.id
        #expect(throws: BackupError.damaged) { try document.validate() }
    }

    @Test func itemInAMissingPlaceIsDamaged() throws {
        var document = try validDocument()
        document.items[0].locationId = UUID()
        #expect(throws: BackupError.damaged) { try document.validate() }
    }

    @Test func wrongCountsAreDamaged() throws {
        var document = try validDocument()
        document.counts.items += 1
        #expect(throws: BackupError.damaged) { try document.validate() }
    }

    @Test(arguments: [BackupError.notABackup, .newerVersion, .damaged, .tooLarge, .couldNotRead, .couldNotExport, .importFailed])
    func everyErrorHasARussianMessage(error: BackupError) throws {
        let ru = try #require(russianBundle())
        let key = error.message.key
        #expect(ru.localizedString(forKey: key, value: nil, table: nil) != key)
    }
}

struct SettingsViewModelTests {
    @Test func importAsksFirstThenReplacesAndReportsSuccess() throws {
        let fixture = try BackupFixture()
        defer { fixture.cleanUp() }
        let url = try fixture.service.exportFile()

        let (target, container) = try fixture.emptyStoreService()
        let context = container.mainContext
        let router = AppRouter()
        router.showLocation(id: UUID())
        let settings = SettingsViewModel(backup: target, router: router, locale: Locale(identifier: "en"))

        settings.importFileSelected(url)
        let confirm = try #require(settings.alert)
        #expect(confirm.message?.contains("7 places · 6 items") == true)
        #expect(try context.fetchCount(FetchDescriptor<StorageLocation>()) == 0, "Nothing changes before confirmation")

        try #require(confirm.actions.first { $0.role == .destructive }).handler()

        #expect(try context.fetchCount(FetchDescriptor<StorageLocation>()) == 7)
        #expect(settings.alert?.actions.count == 1)
        #expect(router.path.isEmpty)
        #expect(settings.hasSnapshot)
    }

    @Test func badFileShowsAnErrorAndChangesNothing() throws {
        let fixture = try BackupFixture()
        defer { fixture.cleanUp() }
        let bad = fixture.folder.appending(path: "bad.storagebackup")
        try Data("nope".utf8).write(to: bad)
        let settings = SettingsViewModel(backup: fixture.service, router: AppRouter())

        settings.importFileSelected(bad)

        #expect(settings.alert?.message == BackupError.notABackup.errorDescription)
        #expect(try fixture.inventory.context.fetchCount(FetchDescriptor<StorageLocation>()) == 7)
    }

    @Test func exportFileIsReadyWhenTheScreenOpens() throws {
        let fixture = try BackupFixture()
        defer { fixture.cleanUp() }
        let settings = SettingsViewModel(backup: fixture.service, router: AppRouter())

        settings.onAppear()

        let url = try #require(settings.exportURL)
        #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }

    @Test func backupOpenedFromFilesIsOfferedForImport() throws {
        let fixture = try BackupFixture()
        defer { fixture.cleanUp() }
        let url = try fixture.service.exportFile()
        let dependencies = AppDependencies(modelContainer: fixture.inventory.container)

        dependencies.deepLinks.handle(url: url)
        #expect(dependencies.router.sheet == .settings(importing: url))

        let settings = SettingsViewModel(backup: fixture.service, router: dependencies.router, pendingImportURL: url)
        settings.onAppear()
        #expect(settings.alert?.actions.contains { $0.role == .destructive } == true)
    }

    @Test func otherFilesAreIgnored() throws {
        let fixture = try BackupFixture()
        defer { fixture.cleanUp() }
        let dependencies = AppDependencies(modelContainer: fixture.inventory.container)

        dependencies.deepLinks.handle(url: URL(filePath: "/tmp/photo.jpg"))

        #expect(dependencies.router.sheet == nil)
    }
}
