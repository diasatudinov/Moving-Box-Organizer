import XCTest

/// End-to-end smoke tests of the main flows (Stage 3.3: 1–2 UI scenarios) plus Apple's
/// automated accessibility audit. The app starts with an empty in-memory store and in English,
/// so the tests never touch real data and don't depend on the simulator language.
final class LocibinUITests: XCTestCase {
    @MainActor private var app: XCUIApplication!

    @MainActor override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    /// Create a place, quick-add items, find one by search and see where it is.
    @MainActor func testCreatePlaceAddItemsAndFindThemBySearch() throws {
        app.buttons["Create Place"].tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Garage")
        app.navigationBars.buttons["Done"].tap()

        // The new place opens right away; add two items one after another.
        let quickAdd = app.textFields["Add item"]
        XCTAssertTrue(quickAdd.waitForExistence(timeout: 5))
        quickAdd.tap()
        quickAdd.typeText("Drill\n")
        quickAdd.typeText("Extension cord\n")
        XCTAssertTrue(element(containing: "Drill").waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Extension cord").waitForExistence(timeout: 5), "Second item typed right after the first one")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(containing: "2 items").waitForExistence(timeout: 5))

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("dri")
        let result = element(containing: "Drill")
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.contains("Garage"), "Search shows where the item is")
    }

    /// Deleting a place asks first and names what will be deleted.
    @MainActor func testDeletingAPlaceAsksForConfirmation() throws {
        createPlace(named: "Pantry")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let row = element(containing: "Pantry")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        let delete = app.buttons.matching(NSPredicate(format: "label == %@", "Delete")).firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["Delete “Pantry”?"].exists)
        alert.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["No Places Yet"].waitForExistence(timeout: 5))
    }

    /// Apple's automated audit: missing labels, contrast, Dynamic Type clipping, small hit areas.
    @MainActor func testMainScreensPassTheAccessibilityAudit() throws {
        try audit("empty main screen")

        createPlace(named: "Garage")
        let quickAdd = app.textFields["Add item"]
        quickAdd.tap()
        quickAdd.typeText("Drill\n")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(containing: "Garage").waitForExistence(timeout: 5))
        try audit("main screen with a place")

        element(containing: "Garage").tap()
        XCTAssertTrue(element(containing: "Drill").waitForExistence(timeout: 5))
        try audit("location screen")
    }

    /// Rows combine their texts for VoiceOver ("Garage, 2 items"), so match by part of the label.
    @MainActor private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Runs the audit and reports every issue with the element it concerns.
    @MainActor private func audit(_ screen: String) throws {
        try app.performAccessibilityAudit { issue in
            // The system search field is single-line by design: on iOS 18 its placeholder is reported
            // as "may be clipped" at the largest sizes — on the list screen without a resolvable
            // element. It's Apple's control; the screens were checked by hand at AX5 text size on
            // iOS 18.2 and 26.5 (Stage 5.9) with nothing of ours clipped.
            if issue.auditType == .textClipped, issue.element == nil || issue.element?.elementType == .searchField {
                return true
            }
            let element = issue.element.map { "\($0.elementType) '\($0.label)'" } ?? "no element"
            XCTFail("[\(screen)] \(issue.compactDescription): \(element) — \(issue.detailedDescription)")
            return true // already reported above
        }
    }

    @MainActor private func createPlace(named name: String) {
        app.buttons["Create Place"].tap()
        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(name)
        app.navigationBars.buttons["Done"].tap()
        XCTAssertTrue(app.textFields["Add item"].waitForExistence(timeout: 5))
    }
}
