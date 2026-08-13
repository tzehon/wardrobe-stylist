import XCTest

final class WardrobeUITests: XCTestCase {
    private enum Identifier {
        static let onboardingCompletion = "com.tth.Wardrobe.onboarding.completed.v1"

        static let demoBanner = "demo.banner"
        static let demoExit = "demo.banner.exit"
        static let demoToday = "demo.today"
        static let demoReset = "demo.settings.reset"

        static let todayTab = "tab.today"
        static let wardrobeTab = "tab.wardrobe"
        static let settingsTab = "tab.settings"

        static let mossJacket = "wardrobe.item.D3A00000-0000-4000-8000-000000000004"
        static let editItem = "item.detail.edit"
        static let saveItem = "item.edit.save"
        static let deleteItem = "item.detail.delete"
        static let fictionalDataNotice = "demo.fictionalDataNotice"

        static let startLocal = "onboarding.startLocal"
    }

    private let editedJacketName = "Moss Field Jacket Edited"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDemoLaunchIsClearlyOfflineAndExposesAllThreeTabs() throws {
        let app = launchDemo()

        XCTAssertTrue(
            element(in: app, identifier: Identifier.demoBanner)
                .waitForExistence(timeout: 5),
            "The launch argument should open Demo Mode before onboarding or connected setup."
        )
        XCTAssertTrue(app.staticTexts["Demo Mode · Fictional Data"].exists)
        XCTAssertTrue(app.staticTexts["Offline · Changes are discarded"].exists)
        XCTAssertTrue(element(in: app, identifier: Identifier.demoToday).exists)
        XCTAssertTrue(app.staticTexts["Fictional offline recommendation"].exists)
        XCTAssertTrue(
            app.staticTexts[
                "This look is bundled with the demo. No wardrobe data was sent anywhere."
            ].exists
        )
        attachScreenshot(named: "Demo Today - Offline Fictional Data")

        assertTab(
            in: app,
            identifier: Identifier.todayTab,
            fallbackLabel: "Today"
        )
        assertTab(
            in: app,
            identifier: Identifier.wardrobeTab,
            fallbackLabel: "Wardrobe"
        )
        assertTab(
            in: app,
            identifier: Identifier.settingsTab,
            fallbackLabel: "Settings"
        )

        tab(in: app, identifier: Identifier.settingsTab, fallbackLabel: "Settings").tap()
        XCTAssertTrue(app.navigationBars["Demo Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Runs entirely offline"].exists)
        XCTAssertTrue(app.staticTexts["Google sign-in"].exists)
        XCTAssertTrue(app.staticTexts["Gmail import"].exists)
        XCTAssertTrue(app.staticTexts["AI network styling"].exists)
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "Unavailable in demo")
            ).firstMatch.exists
        )
        XCTAssertFalse(app.buttons["Sign in with Google"].exists)
        attachScreenshot(named: "Demo Settings - Connected Features Unavailable")
    }

    @MainActor
    func testDemoCatalogCanSearchEditDeleteResetAndExitWithoutGoogle() throws {
        let app = launchDemo()
        XCTAssertTrue(element(in: app, identifier: Identifier.demoBanner).waitForExistence(timeout: 5))

        tab(in: app, identifier: Identifier.wardrobeTab, fallbackLabel: "Wardrobe").tap()
        XCTAssertTrue(app.navigationBars["Catalog"].waitForExistence(timeout: 3))

        let searchField = app.searchFields["Search name or brand"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("Moss")

        let jacket = element(in: app, identifier: Identifier.mossJacket)
        XCTAssertTrue(jacket.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Cloud Oxford Shirt"].exists)
        jacket.tap()

        XCTAssertTrue(app.navigationBars["Moss Field Jacket"].waitForExistence(timeout: 3))
        element(in: app, identifier: Identifier.editItem).tap()
        XCTAssertTrue(app.navigationBars["Edit Item"].waitForExistence(timeout: 3))
        XCTAssertTrue(element(in: app, identifier: Identifier.fictionalDataNotice).exists)

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        replaceText(in: nameField, with: editedJacketName)
        element(in: app, identifier: Identifier.saveItem).tap()

        XCTAssertTrue(app.navigationBars[editedJacketName].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts[editedJacketName].exists)
        attachScreenshot(named: "Demo Item - Edited")

        element(in: app, identifier: Identifier.deleteItem).tap()
        let confirmDelete = app.buttons["Delete"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 2))
        confirmDelete.tap()

        XCTAssertTrue(app.navigationBars["Catalog"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts[editedJacketName].exists)

        tab(in: app, identifier: Identifier.settingsTab, fallbackLabel: "Settings").tap()
        let reset = element(in: app, identifier: Identifier.demoReset)
        XCTAssertTrue(reset.waitForExistence(timeout: 3))
        reset.tap()
        let confirmReset = app.buttons["Delete Demo Changes and Reset"]
        XCTAssertTrue(confirmReset.waitForExistence(timeout: 2))
        confirmReset.tap()

        XCTAssertTrue(element(in: app, identifier: Identifier.demoBanner).waitForExistence(timeout: 5))
        tab(in: app, identifier: Identifier.wardrobeTab, fallbackLabel: "Wardrobe").tap()
        XCTAssertTrue(app.staticTexts["Moss Field Jacket"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts[editedJacketName].exists)
        attachScreenshot(named: "Demo Catalog - Reset")

        element(in: app, identifier: Identifier.demoExit).tap()
        let confirmExit = app.buttons["Exit and Discard Demo Changes"]
        XCTAssertTrue(confirmExit.waitForExistence(timeout: 2))
        confirmExit.tap()

        XCTAssertTrue(app.staticTexts["Your wardrobe, your way"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your wardrobe works without a Google account."].exists)
        XCTAssertFalse(element(in: app, identifier: Identifier.demoBanner).exists)
        XCTAssertFalse(app.buttons["Sign in with Google"].exists)
    }

    @MainActor
    func testFirstLaunchCanStartLocallyWithoutGoogle() throws {
        let app = launchApp(arguments: [
            "-\(Identifier.onboardingCompletion)", "NO",
        ])

        XCTAssertTrue(app.staticTexts["Your wardrobe, your way"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your wardrobe works without a Google account."].exists)
        XCTAssertTrue(
            app.staticTexts[
                "Add pieces yourself and browse them anytime. Gmail import and AI styling are optional features you can choose later."
            ].exists
        )
        XCTAssertFalse(app.buttons["Sign in with Google"].exists)
        attachScreenshot(named: "Onboarding - Local Without Google")

        let startLocal = element(in: app, identifier: Identifier.startLocal)
        XCTAssertTrue(startLocal.exists)
        startLocal.tap()

        XCTAssertTrue(app.navigationBars["Catalog"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            tab(in: app, identifier: Identifier.wardrobeTab, fallbackLabel: "Wardrobe").isSelected
        )
        XCTAssertFalse(app.buttons["Sign in with Google"].exists)
    }

    @MainActor
    private func launchDemo() -> XCUIApplication {
        launchApp(arguments: [
            "--wardrobe-demo",
            "-\(Identifier.onboardingCompletion)", "NO",
        ])
    }

    @MainActor
    private func launchApp(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ] + arguments
        app.launch()
        return app
    }

    @MainActor
    private func assertTab(
        in app: XCUIApplication,
        identifier: String,
        fallbackLabel: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            tab(in: app, identifier: identifier, fallbackLabel: fallbackLabel)
                .waitForExistence(timeout: 2),
            "Expected the \(fallbackLabel) tab.",
            file: file,
            line: line
        )
    }

    @MainActor
    private func tab(
        in app: XCUIApplication,
        identifier: String,
        fallbackLabel: String
    ) -> XCUIElement {
        let identified = element(in: app, identifier: identifier)
        if identified.waitForExistence(timeout: 1) {
            return identified
        }
        return app.tabBars.buttons[fallbackLabel]
    }

    @MainActor
    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func replaceText(in field: XCUIElement, with replacement: String) {
        field.tap()
        if let current = field.value as? String, !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(replacement)
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
