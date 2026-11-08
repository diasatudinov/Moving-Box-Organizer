import Foundation
import Testing
@testable import Locibin

struct ContentsFormatterTests {
    private let english = ContentsFormatter(locale: Locale(identifier: "en"))
    private let russian = ContentsFormatter(locale: Locale(identifier: "ru"))

    @Test func englishSummary() {
        #expect(english.summary(LocationContents(locations: 4, items: 37)) == "4 places · 37 items")
        #expect(english.summary(LocationContents(locations: 1, items: 1)) == "1 place · 1 item")
        #expect(english.summary(LocationContents(locations: 0, items: 5)) == "5 items")
        #expect(english.summary(LocationContents(locations: 2, items: 0)) == "2 places")
        #expect(english.summary(LocationContents(locations: 0, items: 0)) == "Empty")
    }

    @Test(arguments: [
        (1, "1 место"), (2, "2 места"), (4, "4 места"), (5, "5 мест"), (11, "11 мест"), (21, "21 место"), (22, "22 места"),
    ])
    func russianPlacesPlural(count: Int, expected: String) {
        #expect(russian.places(count) == expected)
    }

    @Test(arguments: [
        (1, "1 предмет"), (3, "3 предмета"), (5, "5 предметов"), (12, "12 предметов"), (101, "101 предмет"),
    ])
    func russianItemsPlural(count: Int, expected: String) {
        #expect(russian.items(count) == expected)
    }

    @Test func russianSummary() {
        #expect(russian.summary(LocationContents(locations: 4, items: 37)) == "4 места · 37 предметов")
        #expect(russian.summary(LocationContents(locations: 0, items: 0)) == "Пусто")
    }
}
