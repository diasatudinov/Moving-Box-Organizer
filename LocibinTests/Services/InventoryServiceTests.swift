import Foundation
import SwiftData
import Testing
@testable import Locibin

@Suite("InventoryService — locations")
struct InventoryServiceLocationTests {
    @Test func createLocationTrimsNameAndAttachesParent() throws {
        let fixture = try InventoryFixture()

        let drawer = try fixture.service.createLocation(name: "  Drawer 4 \n", kind: .drawer, parentID: fixture.rack.id)

        #expect(drawer.name == "Drawer 4")
        #expect(drawer.kind == .drawer)
        #expect(drawer.parent?.id == fixture.rack.id)
    }

    @Test func createLocationRejectsEmptyNameAndUnknownParent() throws {
        let fixture = try InventoryFixture()

        #expect(throws: InventoryError.emptyName) {
            try fixture.service.createLocation(name: "   ", kind: .box, parentID: nil)
        }
        #expect(throws: InventoryError.locationNotFound) {
            try fixture.service.createLocation(name: "Box", kind: .box, parentID: UUID())
        }
        #expect(try fixture.service.rootLocations().map(\.name) == ["Garage", "Pantry"])
    }

    @Test func locationsAreSortedNaturally() throws {
        let fixture = try InventoryFixture()
        for name in ["Shelf 10", "shelf 3", "Shelf 2"] {
            try fixture.service.createLocation(name: name, kind: .shelf, parentID: fixture.pantry.id)
        }

        let names = fixture.service.children(of: fixture.pantry).map(\.name)

        #expect(names == ["Shelf 2", "shelf 3", "Shelf 10", "Top shelf"])
    }

    @Test func updateLocationKeepsIdentifierAndBumpsUpdatedAt() throws {
        let fixture = try InventoryFixture()
        let id = fixture.box.id
        let before = fixture.box.updatedAt

        try fixture.service.updateLocation(id: id, name: "Box 3", kind: .container)

        let box = try #require(try fixture.service.location(id: id))
        #expect(box.name == "Box 3")
        #expect(box.kind == .container)
        #expect(box.updatedAt > before)
    }

    @Test func pathGoesFromTopLevelDown() throws {
        let fixture = try InventoryFixture()

        #expect(fixture.service.path(to: fixture.shelf).map(\.name) == ["Garage", "Rack 1", "Shelf 1"])
        #expect(fixture.service.path(to: fixture.garage).map(\.name) == ["Garage"])
    }

    @Test func rowContentsCountsDirectChildrenAndAllNestedItems() throws {
        let fixture = try InventoryFixture()

        #expect(fixture.service.rowContents(of: fixture.garage) == LocationContents(locations: 1, items: 4))
        #expect(fixture.service.rowContents(of: fixture.rack) == LocationContents(locations: 2, items: 3))
        #expect(fixture.service.rowContents(of: fixture.box) == LocationContents(locations: 0, items: 1))
    }

    @Test func totalContentsCountsEverythingThatWouldBeDeleted() throws {
        let fixture = try InventoryFixture()

        #expect(fixture.service.totalContents(of: fixture.garage) == LocationContents(locations: 3, items: 4))
        #expect(fixture.service.totalContents(of: fixture.pantry) == LocationContents(locations: 2, items: 2))
    }

    @Test func deleteLocationRemovesEverythingInsideOnly() throws {
        let fixture = try InventoryFixture()

        try fixture.service.deleteLocation(id: fixture.garage.id)

        #expect(try fixture.service.rootLocations().map(\.name) == ["Pantry"])
        #expect(try fixture.context.fetchCount(FetchDescriptor<StorageLocation>()) == 3)
        #expect(try fixture.context.fetchCount(FetchDescriptor<Item>()) == 2)
    }

    @Test func deleteUnknownLocationThrows() throws {
        let fixture = try InventoryFixture()
        #expect(throws: InventoryError.locationNotFound) {
            try fixture.service.deleteLocation(id: UUID())
        }
    }
}

@Suite("InventoryService — moving locations")
struct InventoryServiceMoveLocationTests {
    @Test func moveLocationToAnotherParent() throws {
        let fixture = try InventoryFixture()

        try fixture.service.moveLocation(id: fixture.box.id, toParentID: fixture.topShelf.id)

        #expect(fixture.service.path(to: fixture.box).map(\.name) == ["Pantry", "Top shelf", "Box 2"])
        #expect(fixture.service.children(of: fixture.rack).map(\.name) == ["Shelf 1"])
    }

    @Test func moveLocationToTopLevel() throws {
        let fixture = try InventoryFixture()

        try fixture.service.moveLocation(id: fixture.rack.id, toParentID: nil)

        #expect(try fixture.service.rootLocations().map(\.name) == ["Garage", "Pantry", "Rack 1"])
    }

    @Test func movingIntoItselfOrADescendantIsRejectedAndChangesNothing() throws {
        let fixture = try InventoryFixture()

        #expect(throws: InventoryError.moveIntoItself) {
            try fixture.service.moveLocation(id: fixture.rack.id, toParentID: fixture.rack.id)
        }
        #expect(throws: InventoryError.moveIntoItself) {
            try fixture.service.moveLocation(id: fixture.garage.id, toParentID: fixture.shelf.id)
        }
        #expect(fixture.service.path(to: fixture.shelf).map(\.name) == ["Garage", "Rack 1", "Shelf 1"])
    }

    @Test func canMoveMatchesTheMoveRules() throws {
        let fixture = try InventoryFixture()
        let service = fixture.service

        #expect(service.canMove(locationID: fixture.rack.id, toParentID: nil))
        #expect(service.canMove(locationID: fixture.rack.id, toParentID: fixture.pantry.id))
        #expect(!service.canMove(locationID: fixture.rack.id, toParentID: fixture.rack.id))
        #expect(!service.canMove(locationID: fixture.rack.id, toParentID: fixture.box.id))
        #expect(!service.canMove(locationID: fixture.rack.id, toParentID: UUID()))
    }
}

@Suite("InventoryService — items")
struct InventoryServiceItemTests {
    @Test func addItemTrimsTextAndDropsEmptyNote() throws {
        let fixture = try InventoryFixture()

        let item = try fixture.service.addItem(name: " Gloves ", quantity: 3, note: "   ", toLocationID: fixture.box.id)

        #expect(item.name == "Gloves")
        #expect(item.quantity == 3)
        #expect(item.note == nil)
        #expect(item.location?.id == fixture.box.id)
    }

    @Test func addItemValidatesInput() throws {
        let fixture = try InventoryFixture()

        #expect(throws: InventoryError.emptyName) {
            try fixture.service.addItem(name: "", toLocationID: fixture.box.id)
        }
        #expect(throws: InventoryError.invalidQuantity) {
            try fixture.service.addItem(name: "Tape", quantity: 0, toLocationID: fixture.box.id)
        }
        #expect(throws: InventoryError.locationNotFound) {
            try fixture.service.addItem(name: "Tape", toLocationID: UUID())
        }
    }

    @Test func itemsKeepTheOrderTheyWereAdded() throws {
        let fixture = try InventoryFixture()
        try fixture.service.addItem(name: "Allen keys", toLocationID: fixture.shelf.id)

        let names = fixture.service.items(in: fixture.shelf).map(\.name)

        #expect(names == ["Bosch drill", "Screwdriver set", "Allen keys"])
    }

    @Test func updateItemChangesFieldsAndCanClearQuantity() throws {
        let fixture = try InventoryFixture()

        try fixture.service.updateItem(id: fixture.drill.id, name: "Bosch drill GSB 18V", quantity: 1, note: "With bits")
        #expect(fixture.drill.name == "Bosch drill GSB 18V")
        #expect(fixture.drill.quantity == 1)
        #expect(fixture.drill.note == "With bits")

        try fixture.service.updateItem(id: fixture.drill.id, name: "Bosch drill", quantity: nil, note: nil)
        #expect(fixture.drill.quantity == nil)
        #expect(fixture.drill.note == nil)
    }

    @Test func moveItemToAnotherLocation() throws {
        let fixture = try InventoryFixture()

        try fixture.service.moveItem(id: fixture.drill.id, toLocationID: fixture.box.id)

        #expect(fixture.drill.location?.id == fixture.box.id)
        #expect(fixture.service.items(in: fixture.shelf).map(\.name) == ["Screwdriver set"])
    }

    @Test func deleteItemKeepsLocation() throws {
        let fixture = try InventoryFixture()

        try fixture.service.deleteItem(id: fixture.ladder.id)

        #expect(try fixture.service.location(id: fixture.garage.id) != nil)
        #expect(fixture.service.items(in: fixture.garage).isEmpty)
        #expect(throws: InventoryError.itemNotFound) {
            try fixture.service.deleteItem(id: fixture.ladder.id)
        }
    }
}

@Suite("InventoryService — search")
struct InventoryServiceSearchTests {
    @Test func searchIgnoresCaseAndMatchesPartOfWord() throws {
        let fixture = try InventoryFixture()

        #expect(try fixture.service.search("DRILL").items.map(\.name) == ["Bosch drill"])
        #expect(try fixture.service.search("screw").items.map(\.name) == ["Screwdriver set"])
    }

    @Test func searchTreatsYoAndYeAsTheSameLetter() throws {
        let fixture = try InventoryFixture()

        #expect(try fixture.service.search("елочные").items.map(\.name) == ["Ёлочные игрушки"])
        #expect(try fixture.service.search("ЁЛОЧ").items.map(\.name) == ["Ёлочные игрушки"])
    }

    @Test func searchFindsLocationsToo() throws {
        let fixture = try InventoryFixture()

        let results = try fixture.service.search("shelf")

        #expect(results.locations.map(\.name) == ["Shelf 1", "Top shelf"])
        #expect(results.items.isEmpty)
    }

    @Test(arguments: ["", "   ", "\n"])
    func blankQueryReturnsNothing(query: String) throws {
        let fixture = try InventoryFixture()
        #expect(try fixture.service.search(query).isEmpty)
    }

    @Test func noMatchesReturnsEmptyResults() throws {
        let fixture = try InventoryFixture()
        #expect(try fixture.service.search("perforator").isEmpty)
    }
}

struct InventoryErrorTests {
    @Test(arguments: [
        InventoryError.emptyName, .invalidQuantity, .locationNotFound, .itemNotFound, .moveIntoItself, .saveFailed,
    ])
    func everyErrorHasARussianMessage(error: InventoryError) throws {
        let ru = try #require(russianBundle())
        let key = error.message.key
        let russian = ru.localizedString(forKey: key, value: nil, table: nil)
        #expect(russian != key, "No Russian translation for: \(key)")
        #expect(error.errorDescription?.isEmpty == false)
    }
}
