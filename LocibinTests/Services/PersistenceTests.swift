import Foundation
import SwiftData
import Testing
@testable import Locibin

/// Changes must survive reopening the on-disk store, not only live in the in-memory context.
struct PersistenceTests {
    private func openStore(at url: URL) throws -> ModelContainer {
        let schema = ModelContainerFactory.schema
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: LocibinMigrationPlan.self, configurations: configuration)
    }

    @Test func movedItemStaysMovedAfterReopening() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "Test.store")

        var drillID = UUID(), boxID = UUID()
        do {
            let container = try openStore(at: url)
            let service = InventoryService(context: container.mainContext)
            let garage = try service.createLocation(name: "Garage", kind: .room, parentID: nil)
            let box = try service.createLocation(name: "Box", kind: .box, parentID: garage.id)
            let drill = try service.addItem(name: "Drill", toLocationID: garage.id)
            drillID = drill.id
            boxID = box.id

            try service.moveItem(id: drill.id, toLocationID: box.id)
        }

        let reopened = try openStore(at: url)
        let item = try #require(try InventoryService(context: reopened.mainContext).item(id: drillID))
        #expect(item.location?.id == boxID)
    }

    @Test func movedLocationStaysMovedAfterReopening() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "Test.store")

        var rackID = UUID(), pantryID = UUID()
        do {
            let container = try openStore(at: url)
            let service = InventoryService(context: container.mainContext)
            let garage = try service.createLocation(name: "Garage", kind: .room, parentID: nil)
            let pantry = try service.createLocation(name: "Pantry", kind: .room, parentID: nil)
            let rack = try service.createLocation(name: "Rack", kind: .rack, parentID: garage.id)
            rackID = rack.id
            pantryID = pantry.id

            try service.moveLocation(id: rack.id, toParentID: pantry.id)
        }

        let reopened = try openStore(at: url)
        let rack = try #require(try InventoryService(context: reopened.mainContext).location(id: rackID))
        #expect(rack.parent?.id == pantryID)
    }
}
