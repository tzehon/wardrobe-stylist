import XCTest

final class WardrobeUITests: XCTestCase {
    private enum Identifier {
        static let onboardingCompletion = "com.tth.Wardrobe.onboarding.completed.v1"
        static let selectedTab = "com.tth.Wardrobe.selectedTab"

        static let demoBanner = "demo.banner"
        static let demoExit = "demo.banner.exit"
        static let demoToday = "demo.today"
        static let demoReset = "demo.settings.reset"

        static let todayTab = "tab.today"
        static let wardrobeTab = "tab.wardrobe"
        static let historyTab = "tab.history"
        static let settingsTab = "tab.settings"

        static let mossJacket = "wardrobe.item.D3A00000-0000-4000-8000-000000000004"
        static let editItem = "item.detail.edit"
        static let saveEditedItem = "item.edit.save"
        static let moreItemActions = "item.detail.more"
        static let fictionalDataNotice = "demo.fictionalDataNotice"

        static let onboardingHero = "onboarding.hero"
        static let localBenefit = "onboarding.benefit.local"
        static let startLocal = "onboarding.startLocal"
        static let addEmptyItem = "wardrobe.empty.addItem"
        static let addToolbarItem = "wardrobe.addItem"
        static let itemName = "item.details.name"
        static let saveAddedItem = "item.add.save"
        static let photoLibrary = "item.photo.library"

        static let connectedRoot = "uiTest.connected.root"
        static let connectedFeatures = "settings.hub.connected"
        static let wardrobeAndDemo = "settings.hub.wardrobe"
        static let privacyAndData = "settings.hub.privacy"
        static let helpAndSupport = "settings.hub.help"
        static let stylingAllow = "settings.styling.allow"
        static let stylingAllowed = "settings.styling.allowed"
        static let stylingWithdraw = "settings.styling.withdraw"
        static let reminderToggle = "settings.styling.reminder"
        static let reminderTime = "settings.styling.reminderTime"
        static let deleteLocalData = "settings.privacy.deleteLocalData"
        static let deleteServerSecurityData = "settings.privacy.deleteServerSecurityData"
        static let serverDeletionSuccess = "settings.privacy.deleteServerSecurityData.success"
    }

    private let editedJacketName = "Moss Field Jacket Edited"
    private let manualItemName = "Local UI Test Shirt"
    private let editedManualItemName = "Local UI Test Oxford"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDemoLaunchIsOfflineAndExposesTodayHistoryAndAllTabs() {
        let app = launchDemo()

        XCTAssertTrue(
            element(in: app, identifier: Identifier.demoBanner)
                .waitForExistence(timeout: 5),
            "The demo launch argument should open fictional offline data immediately."
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

        assertTab(in: app, identifier: Identifier.todayTab, fallbackLabel: "Today")
        assertTab(in: app, identifier: Identifier.wardrobeTab, fallbackLabel: "Wardrobe")
        assertTab(in: app, identifier: Identifier.historyTab, fallbackLabel: "History")
        assertTab(in: app, identifier: Identifier.settingsTab, fallbackLabel: "Settings")

        tab(in: app, identifier: Identifier.historyTab, fallbackLabel: "History").tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
        XCTAssertTrue(element(in: app, identifier: "history.root").exists)
        let historyRow = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@",
                "Weekend errands",
                "Cedar Pleated Trousers"
            )
        ).firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 3))
        XCTAssertTrue(historyRow.label.contains("Saffron Mini Tote"))

        tab(in: app, identifier: Identifier.settingsTab, fallbackLabel: "Settings").tap()
        XCTAssertTrue(app.navigationBars["Demo Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Runs entirely offline"].exists)
        XCTAssertTrue(app.staticTexts["AI network styling"].exists)
        XCTAssertTrue(app.staticTexts["Notifications"].exists)
        XCTAssertTrue(element(in: app, identifier: Identifier.demoReset).exists)
        assertRetiredCapabilitiesAbsent(in: app)
    }

    @MainActor
    func testDemoCatalogCanFilterSearchEditDeleteAndRestoreOnRelaunch() {
        let app = launchDemo()
        XCTAssertTrue(element(in: app, identifier: Identifier.demoBanner).waitForExistence(timeout: 5))

        tab(in: app, identifier: Identifier.wardrobeTab, fallbackLabel: "Wardrobe").tap()
        XCTAssertTrue(app.navigationBars["Catalog"].waitForExistence(timeout: 3))

        let outerwear = app.buttons["Outerwear"]
        XCTAssertTrue(outerwear.waitForExistence(timeout: 3))
        outerwear.tap()
        XCTAssertTrue(app.staticTexts["Moss Field Jacket"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Cloud Oxford Shirt"].exists)

        app.buttons["All"].tap()
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

        let nameField = element(in: app, identifier: Identifier.itemName)
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        replaceText(in: nameField, with: editedJacketName)
        element(in: app, identifier: Identifier.saveEditedItem).tap()

        XCTAssertTrue(app.navigationBars[editedJacketName].waitForExistence(timeout: 3))
        element(in: app, identifier: Identifier.moreItemActions).tap()
        XCTAssertTrue(app.buttons["Delete"].firstMatch.waitForExistence(timeout: 2))
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Delete"].firstMatch.waitForExistence(timeout: 2))
        app.buttons["Delete"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Catalog"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts[editedJacketName].exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(element(in: app, identifier: Identifier.demoBanner).waitForExistence(timeout: 5))
        tab(in: app, identifier: Identifier.wardrobeTab, fallbackLabel: "Wardrobe").tap()
        XCTAssertTrue(app.staticTexts["Moss Field Jacket"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts[editedJacketName].exists)

        element(in: app, identifier: Identifier.demoExit).tap()
        let confirmExit = app.buttons["Exit and Discard Demo Changes"]
        XCTAssertTrue(confirmExit.waitForExistence(timeout: 2))
        confirmExit.tap()

        assertLocalOnboardingIsVisible(in: app)
        XCTAssertFalse(element(in: app, identifier: Identifier.demoBanner).exists)
        assertRetiredCapabilitiesAbsent(in: app)
    }

    @MainActor
    func testFirstLaunchCanStartLocallyWithRemovedCapabilitiesAbsent() {
        let app = launchApp(arguments: [
            "--wardrobe-ui-testing-local",
            "-\(Identifier.onboardingCompletion)", "NO",
            "-\(Identifier.selectedTab)", "wardrobe",
        ])

        assertLocalOnboardingIsVisible(in: app)
        assertRetiredCapabilitiesAbsent(in: app)

        let startLocal = element(in: app, identifier: Identifier.startLocal)
        XCTAssertTrue(startLocal.exists)
        startLocal.tap()

        XCTAssertTrue(app.navigationBars["Catalog"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            tab(in: app, identifier: Identifier.wardrobeTab, fallbackLabel: "Wardrobe").isSelected
        )
        XCTAssertTrue(app.staticTexts["No items yet"].exists)
        assertRetiredCapabilitiesAbsent(in: app)
    }

    @MainActor
    func testManualItemCanBeAddedEditedAndDeletedLocally() {
        let app = launchLocalCatalog()
        XCTAssertTrue(app.navigationBars["Catalog"].waitForExistence(timeout: 5))

        let add = firstExistingElement(
            in: app,
            identifiers: [Identifier.addEmptyItem, Identifier.addToolbarItem]
        )
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        add.tap()
        XCTAssertTrue(app.navigationBars["Add Item"].waitForExistence(timeout: 3))

        let name = element(in: app, identifier: Identifier.itemName)
        XCTAssertTrue(name.waitForExistence(timeout: 2))
        name.tap()
        name.typeText(manualItemName)
        let save = element(in: app, identifier: Identifier.saveAddedItem)
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(app.navigationBars["Catalog"].waitForExistence(timeout: 3))
        let itemLabel = app.staticTexts[manualItemName]
        XCTAssertTrue(itemLabel.waitForExistence(timeout: 3))
        itemLabel.tap()
        XCTAssertTrue(app.navigationBars[manualItemName].waitForExistence(timeout: 3))

        element(in: app, identifier: Identifier.editItem).tap()
        XCTAssertTrue(app.navigationBars["Edit Item"].waitForExistence(timeout: 3))
        replaceText(
            in: element(in: app, identifier: Identifier.itemName),
            with: editedManualItemName
        )
        element(in: app, identifier: Identifier.saveEditedItem).tap()
        XCTAssertTrue(app.navigationBars[editedManualItemName].waitForExistence(timeout: 3))

        element(in: app, identifier: Identifier.moreItemActions).tap()
        XCTAssertTrue(app.buttons["Delete"].firstMatch.waitForExistence(timeout: 2))
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Delete"].firstMatch.waitForExistence(timeout: 2))
        app.buttons["Delete"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Catalog"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No items yet"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts[editedManualItemName].exists)
        assertRetiredCapabilitiesAbsent(in: app)
    }

    @MainActor
    func testPhotoLibraryStaysPresentedUntilTheUserCancels() {
        let app = launchLocalCatalog()
        XCTAssertTrue(app.navigationBars["Catalog"].waitForExistence(timeout: 5))
        firstExistingElement(
            in: app,
            identifiers: [Identifier.addEmptyItem, Identifier.addToolbarItem]
        ).tap()
        XCTAssertTrue(app.navigationBars["Add Item"].waitForExistence(timeout: 3))

        element(in: app, identifier: Identifier.photoLibrary).tap()
        let photoLibrary = app.navigationBars["Photos"]
        XCTAssertTrue(photoLibrary.waitForExistence(timeout: 15))

        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertTrue(
            photoLibrary.exists,
            "The photo library must remain presented until the user selects an image or cancels."
        )

        let cancel = photoLibrary.buttons["Cancel"]
        XCTAssertTrue(cancel.exists)
        cancel.tap()
        XCTAssertTrue(app.navigationBars["Add Item"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSettingsHubAndStylingConsentStayExplicitAndReversible() {
        let app = launchConnectedUITestExperience()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(element(in: app, identifier: Identifier.connectedFeatures).exists)
        XCTAssertTrue(element(in: app, identifier: Identifier.wardrobeAndDemo).exists)
        XCTAssertTrue(element(in: app, identifier: Identifier.privacyAndData).exists)
        XCTAssertTrue(element(in: app, identifier: Identifier.helpAndSupport).exists)
        XCTAssertTrue(app.staticTexts["AI styling and reminders"].exists)
        XCTAssertTrue(app.staticTexts["Data use, privacy policy, and deletion"].exists)
        assertRetiredCapabilitiesAbsent(in: app)

        openConnectedFeatures(in: app)
        XCTAssertTrue(app.staticTexts["AI Styling & Reminder"].exists)
        let disclosure = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@",
                "wardrobe photos",
                "occasion or context"
            )
        ).firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: 3))

        let allow = element(in: app, identifier: Identifier.stylingAllow)
        XCTAssertTrue(scrollToElement(allow, in: app))
        allow.tap()
        XCTAssertTrue(
            element(in: app, identifier: Identifier.stylingAllowed)
                .waitForExistence(timeout: 3)
        )

        let withdraw = element(in: app, identifier: Identifier.stylingWithdraw)
        XCTAssertTrue(scrollToElement(withdraw, in: app))
        withdraw.tap()
        XCTAssertTrue(allow.waitForExistence(timeout: 3))
        assertRetiredCapabilitiesAbsent(in: app)
    }

    @MainActor
    func testReminderCanEnableAndDisableWithoutSystemPermission() {
        let app = launchConnectedUITestExperience()
        openConnectedFeatures(in: app)

        let allow = element(in: app, identifier: Identifier.stylingAllow)
        XCTAssertTrue(scrollToElement(allow, in: app))
        allow.tap()
        XCTAssertTrue(
            element(in: app, identifier: Identifier.stylingAllowed)
                .waitForExistence(timeout: 3)
        )

        let reminder = element(in: app, identifier: Identifier.reminderToggle)
        XCTAssertTrue(scrollToElement(reminder, in: app))
        XCTAssertTrue(waitForSwitch(of: reminder, expected: false))
        reminder.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()

        let timePicker = element(in: app, identifier: Identifier.reminderTime)
        XCTAssertTrue(scrollBidirectionallyToElement(timePicker, in: app))
        XCTAssertTrue(waitForSwitch(of: reminder, expected: true))
        XCTAssertTrue(waitForEnabledState(of: timePicker, expected: true))
        XCTAssertNotEqual(timePicker.value as? String, "Reminder is off")

        XCTAssertTrue(scrollBidirectionallyToElement(reminder, in: app))
        reminder.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(waitForSwitch(of: reminder, expected: false))
        XCTAssertTrue(scrollBidirectionallyToElement(timePicker, in: app))
        XCTAssertTrue(waitForEnabledState(of: timePicker, expected: false))
        XCTAssertEqual(timePicker.value as? String, "Reminder is off")
    }

    @MainActor
    func testServerSecurityDeletionUsesTheIsolatedFakeAndKeepsLocalControlAvailable() {
        let app = launchConnectedUITestExperience()
        openPrivacyAndData(in: app)

        let delete = element(in: app, identifier: Identifier.deleteServerSecurityData)
        XCTAssertTrue(scrollBidirectionallyToElement(delete, in: app))
        delete.tap()

        XCTAssertTrue(app.staticTexts["Delete server security data?"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "Your wardrobe stays on this device")
            ).firstMatch.exists
        )
        confirmationButton(
            in: app,
            label: "Delete Server Security Data",
            excludingIdentifier: Identifier.deleteServerSecurityData
        ).tap()

        let success = element(in: app, identifier: Identifier.serverDeletionSuccess)
        XCTAssertTrue(success.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Live server security record deleted"].exists)
        XCTAssertTrue(
            scrollBidirectionallyToElement(
                element(in: app, identifier: Identifier.deleteLocalData),
                in: app
            )
        )
    }

    @MainActor
    func testVerifiedLocalDeletionRemovesSeededDataThroughTheRealCoordinator() {
        let app = launchConnectedUITestExperience()
        openPrivacyAndData(in: app)

        let delete = element(in: app, identifier: Identifier.deleteLocalData)
        XCTAssertTrue(scrollToElement(delete, in: app))
        delete.tap()

        XCTAssertTrue(app.staticTexts["Delete local data?"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "permanently removes your wardrobe")
            ).firstMatch.exists
        )
        confirmationButton(
            in: app,
            label: "Delete Local Data",
            excludingIdentifier: Identifier.deleteLocalData
        ).tap()

        let alert = app.alerts["Local Data Deleted"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(
            alert.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "local wardrobe, history, cached looks")
            ).firstMatch.exists
        )
        alert.buttons["OK"].tap()
        XCTAssertTrue(element(in: app, identifier: Identifier.connectedRoot).exists)
    }

    @MainActor
    private func launchDemo() -> XCUIApplication {
        launchApp(arguments: [
            "--wardrobe-demo",
            "--wardrobe-ui-testing-local",
            "-\(Identifier.onboardingCompletion)", "NO",
        ])
    }

    @MainActor
    private func launchLocalCatalog() -> XCUIApplication {
        launchApp(arguments: [
            "--wardrobe-ui-testing-local",
            "-\(Identifier.onboardingCompletion)", "YES",
            "-\(Identifier.selectedTab)", "wardrobe",
        ])
    }

    @MainActor
    private func launchConnectedUITestExperience() -> XCUIApplication {
        let app = launchApp(arguments: ["--wardrobe-ui-testing-connected"])
        XCTAssertTrue(
            element(in: app, identifier: Identifier.connectedRoot)
                .waitForExistence(timeout: 5)
        )
        return app
    }

    @MainActor
    private func assertLocalOnboardingIsVisible(in app: XCUIApplication) {
        let hero = element(in: app, identifier: Identifier.onboardingHero)
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertTrue(hero.label.contains("Your wardrobe, your way"))
        XCTAssertTrue(hero.label.contains("AI styling is optional"))

        let local = element(in: app, identifier: Identifier.localBenefit)
        XCTAssertTrue(local.exists)
        XCTAssertTrue(local.label.contains("needs no account"))
    }

    @MainActor
    private func assertRetiredCapabilitiesAbsent(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(app.buttons["Sign in with Google"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["Connect Google"].exists, file: file, line: line)
        let retiredCopy = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS[c] %@",
                "Gmail",
                "Google sign-in",
                "Import receipts"
            )
        )
        XCTAssertEqual(retiredCopy.count, 0, file: file, line: line)
    }

    @MainActor
    private func openConnectedFeatures(in app: XCUIApplication) {
        openSettingsDestination(
            identifier: Identifier.connectedFeatures,
            navigationTitle: "Connected Features",
            in: app
        )
    }

    @MainActor
    private func openPrivacyAndData(in app: XCUIApplication) {
        openSettingsDestination(
            identifier: Identifier.privacyAndData,
            navigationTitle: "Privacy & Data",
            in: app
        )
    }

    @MainActor
    private func openSettingsDestination(
        identifier: String,
        navigationTitle: String,
        in app: XCUIApplication
    ) {
        let destination = element(in: app, identifier: identifier)
        XCTAssertTrue(destination.waitForExistence(timeout: 3))
        destination.tap()
        XCTAssertTrue(app.navigationBars[navigationTitle].waitForExistence(timeout: 3))
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
    private func firstExistingElement(
        in app: XCUIApplication,
        identifiers: [String]
    ) -> XCUIElement {
        for identifier in identifiers {
            let candidate = element(in: app, identifier: identifier)
            if candidate.waitForExistence(timeout: 1) { return candidate }
        }
        return element(in: app, identifier: identifiers[0])
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
    private func scrollToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 12
    ) -> Bool {
        if element.waitForExistence(timeout: 1), element.isHittable { return true }
        for _ in 0..<attempts {
            app.swipeUp()
            if element.exists, element.isHittable { return true }
        }
        return element.exists && element.isHittable
    }

    @MainActor
    private func scrollBidirectionallyToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attemptsPerDirection: Int = 12
    ) -> Bool {
        if element.waitForExistence(timeout: 1), element.isHittable { return true }
        for _ in 0..<attemptsPerDirection {
            app.swipeDown()
            if element.exists, element.isHittable { return true }
        }
        for _ in 0..<attemptsPerDirection {
            app.swipeUp()
            if element.exists, element.isHittable { return true }
        }
        return element.exists && element.isHittable
    }

    @MainActor
    private func waitForSwitch(
        of element: XCUIElement,
        expected: Bool,
        timeout: TimeInterval = 3
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let value = (element.value as? String)?.lowercased()
            if expected ? (value == "1" || value == "on") : (value == "0" || value == "off") {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return false
    }

    @MainActor
    private func waitForEnabledState(
        of element: XCUIElement,
        expected: Bool,
        timeout: TimeInterval = 3
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.exists, element.isEnabled == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return false
    }

    @MainActor
    private func confirmationButton(
        in app: XCUIApplication,
        label: String,
        excludingIdentifier: String
    ) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(
                format: "label == %@ AND identifier != %@",
                label,
                excludingIdentifier
            )
        ).firstMatch
    }
}
