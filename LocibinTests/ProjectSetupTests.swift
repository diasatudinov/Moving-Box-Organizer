import Foundation
import Testing

/// Smoke tests for the project configuration agreed in Stage 4.
/// They run inside the host app, so `Bundle.main` is the Locibin app bundle.
struct ProjectSetupTests {
    @Test func bundleIdentifierMatchesAgreedValue() {
        #expect(Bundle.main.bundleIdentifier == "com.diasiosdev.locibin")
    }

    @Test func appShipsEnglishAndRussianLocalizations() {
        let localizations = Bundle.main.localizations
        #expect(localizations.contains("en"))
        #expect(localizations.contains("ru"))
    }

    @Test func russianTranslationIsResolvedFromStringCatalog() throws {
        let ruPath = try #require(Bundle.main.path(forResource: "ru", ofType: "lproj"))
        let ruBundle = try #require(Bundle(path: ruPath))
        let value = ruBundle.localizedString(forKey: "Project is set up", value: nil, table: nil)
        #expect(value == "Проект настроен")
    }
}
