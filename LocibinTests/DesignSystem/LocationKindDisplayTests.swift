import Testing
import UIKit
@testable import Locibin

struct LocationKindDisplayTests {
    @Test(arguments: LocationKind.allCases)
    func symbolExistsOnIOS(kind: LocationKind) {
        #expect(UIImage(systemName: kind.symbolName) != nil, "Missing SF Symbol \(kind.symbolName)")
    }

    @Test func everyKindHasItsOwnSymbol() {
        let symbols = LocationKind.allCases.map(\.symbolName)
        #expect(Set(symbols).count == symbols.count)
    }

    @Test(arguments: LocationKind.allCases)
    func titleIsTranslatedToRussian(kind: LocationKind) throws {
        let ru = try #require(russianBundle())
        let key = kind.title.key
        let translated = ru.localizedString(forKey: key, value: nil, table: nil)
        #expect(translated != key, "No Russian translation for \(key)")
    }

    @Test func storeErrorSymbolExists() {
        #expect(UIImage(systemName: "externaldrive.badge.exclamationmark") != nil)
    }
}
