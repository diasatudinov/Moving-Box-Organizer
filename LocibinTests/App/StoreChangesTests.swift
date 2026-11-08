import Foundation
import Testing
@testable import Locibin

struct StoreChangesTests {
    @Test func handlerRunsAfterEverySaveUntilObservationIsReleased() throws {
        let fixture = try InventoryFixture()
        let changes = StoreChanges(context: fixture.context)
        var calls = 0

        var observation: StoreObservation? = changes.observe { calls += 1 }
        try fixture.service.addItem(name: "Tape", toLocationID: fixture.box.id)
        try fixture.service.deleteItem(id: fixture.ladder.id)
        #expect(calls == 2)
        #expect(observation != nil)

        observation = nil
        try fixture.service.addItem(name: "Glue", toLocationID: fixture.box.id)
        #expect(calls == 2)
    }
}
