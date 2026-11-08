import Foundation
import SwiftData
import Testing
@testable import Locibin

struct SchemaV1Tests {
    @Test func deletingLocationCascadesToNestedLocationsAndItems() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let garage = StorageLocation(name: "Garage", kind: .room)
        let rack = StorageLocation(name: "Rack 1", kind: .rack, parent: garage)
        let shelf = StorageLocation(name: "Shelf 2", kind: .shelf, parent: rack)
        context.insert(garage)
        context.insert(rack)
        context.insert(shelf)
        context.insert(Item(name: "Ladder", location: garage))
        context.insert(Item(name: "Drill", location: shelf))
        try context.save()

        context.delete(garage)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<StorageLocation>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
    }

    @Test func deletingItemKeepsItsLocation() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let box = StorageLocation(name: "Box 3", kind: .box)
        let fuse = Item(name: "Fuses", quantity: 10, location: box)
        context.insert(box)
        context.insert(fuse)
        try context.save()

        context.delete(fuse)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<StorageLocation>()) == 1)
        #expect(box.items?.isEmpty == true)
    }

    @Test func relationshipsAreConnectedBothWays() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let pantry = StorageLocation(name: "Pantry", kind: .room)
        let shelf = StorageLocation(name: "Top shelf", kind: .shelf, parent: pantry)
        let lights = Item(name: "Garland", location: shelf)
        context.insert(pantry)
        context.insert(shelf)
        context.insert(lights)
        try context.save()

        #expect(pantry.children?.map(\.id) == [shelf.id])
        #expect(shelf.items?.map(\.id) == [lights.id])
        #expect(lights.location?.parent?.id == pantry.id)
    }

    @Test func stableIdentifierSurvivesSaveAndFetch() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let id = UUID()
        context.insert(StorageLocation(id: id, name: "Drawer", kind: .drawer))
        try context.save()

        let descriptor = FetchDescriptor<StorageLocation>(predicate: #Predicate { $0.id == id })
        #expect(try context.fetch(descriptor).first?.name == "Drawer")
    }

    @Test func kindIsStoredAsRawValueAndUnknownValuesFallBackToOther() {
        let location = StorageLocation(name: "Bin", kind: .container)
        #expect(location.kindRaw == "container")

        location.kindRaw = "spaceship"
        #expect(location.kind == .other)

        location.kind = .cabinet
        #expect(location.kindRaw == "cabinet")
    }

    @Test func persistentStoreLivesInApplicationSupport() {
        let url = ModelContainerFactory.persistentStoreURL
        #expect(url.lastPathComponent == "Locibin.store")
        #expect(url.deletingLastPathComponent() == URL.applicationSupportDirectory)
    }
}
