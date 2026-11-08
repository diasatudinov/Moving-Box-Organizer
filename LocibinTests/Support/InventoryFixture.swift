import Foundation
import SwiftData
@testable import Locibin

/// Clock that moves one second forward on every call, so creation order is deterministic.
final class SteppingClock {
    private var current = Date(timeIntervalSince1970: 1_800_000_000)

    func next() -> Date {
        current.addTimeInterval(1)
        return current
    }
}

/// A small realistic inventory used across service and ViewModel tests:
///
///     Garage            — Ladder
///       Rack 1
///         Shelf 1       — Bosch drill, Screwdriver set
///         Box 2         — Fuses ×10
///     Pantry
///       Top shelf
///         Box "New Year" — Ёлочные игрушки, Garland
struct InventoryFixture {
    let container: ModelContainer
    let service: InventoryService
    let garage: StorageLocation
    let rack: StorageLocation
    let shelf: StorageLocation
    let box: StorageLocation
    let pantry: StorageLocation
    let topShelf: StorageLocation
    let newYearBox: StorageLocation
    let ladder: Item
    let drill: Item

    init() throws {
        container = try makeTestContainer()
        let clock = SteppingClock()
        service = InventoryService(context: container.mainContext, now: clock.next)

        garage = try service.createLocation(name: "Garage", kind: .room, parentID: nil)
        rack = try service.createLocation(name: "Rack 1", kind: .rack, parentID: garage.id)
        shelf = try service.createLocation(name: "Shelf 1", kind: .shelf, parentID: rack.id)
        box = try service.createLocation(name: "Box 2", kind: .box, parentID: rack.id)
        pantry = try service.createLocation(name: "Pantry", kind: .room, parentID: nil)
        topShelf = try service.createLocation(name: "Top shelf", kind: .shelf, parentID: pantry.id)
        newYearBox = try service.createLocation(name: "New Year", kind: .box, parentID: topShelf.id)

        ladder = try service.addItem(name: "Ladder", toLocationID: garage.id)
        drill = try service.addItem(name: "Bosch drill", note: "In the case", toLocationID: shelf.id)
        try service.addItem(name: "Screwdriver set", toLocationID: shelf.id)
        try service.addItem(name: "Fuses", quantity: 10, toLocationID: box.id)
        try service.addItem(name: "Ёлочные игрушки", toLocationID: newYearBox.id)
        try service.addItem(name: "Garland", toLocationID: newYearBox.id)
    }

    var context: ModelContext { container.mainContext }
}
