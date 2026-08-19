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
        static let historyTab = "tab.history"
        static let settingsTab = "tab.settings"

        static let mossJacket = "wardrobe.item.D3A00000-0000-4000-8000-000000000004"
        static let pendingDress = "wardrobe.item.D3A00000-0000-4000-8000-000000000007"
        static let editItem = "item.detail.edit"
        static let saveItem = "item.edit.save"
        static let deleteItem = "item.detail.delete"
        static let moreItemActions = "item.detail.more"
        static let fictionalDataNotice = "demo.fictionalDataNotice"

        static let startLocal = "onboarding.startLocal"
        static let onboardingHero = "onboarding.hero"
        static let localBenefit = "onboarding.benefit.local"
        static let addItem = "wardrobe.empty.addItem"
        static let photoLibrary = "item.photo.library"

        static let connectedRoot = "uiTest.connected.root"
        static let networkStatus = "uiTest.connected.networkStatus"
        static let connectedFeatures = "settings.hub.connected"
        static let wardrobeAndDemo = "settings.hub.wardrobe"
        static let privacyAndData = "settings.hub.privacy"
        static let helpAndSupport = "settings.hub.help"
        static let receiptAllow = "settings.gmail.allowReceiptAnalysis"
        static let receiptAllowed = "settings.gmail.receiptAnalysisAllowed"
        static let receiptWithdraw = "settings.gmail.withdrawReceiptAnalysis"
        static let stylingAllow = "settings.styling.allow"
        static let stylingAllowed = "settings.styling.allowed"
        static let stylingWithdraw = "settings.styling.withdraw"
        static let reminderToggle = "settings.styling.reminder"
        static let reminderTime = "settings.styling.reminderTime"
        static let signOut = "settings.gmail.signOut"
        static let disconnect = "settings.gmail.disconnect"
        static let deleteLocalData = "settings.privacy.deleteLocalData"
        static let deleteServerSecurityData = "settings.privacy.deleteServerSecurityData"
    }

    private let editedJacketName = "Moss Field Jacket Edited"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDemoLaunchIsClearlyOfflineAndExposesAllFourTabs() throws {
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
            identifier: Identifier.historyTab,
            fallbackLabel: "History"
        )
        assertTab(
            in: app,
            identifier: Identifier.settingsTab,
            fallbackLabel: "Settings"
        )

        tab(in: app, identifier: Identifier.historyTab, fallbackLabel: "History").tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
        let historyRow = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@",
                "Weekend errands",
                "Cedar Pleated Trousers"
            )
        ).firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 3))
        XCTAssertTrue(historyRow.label.localizedCaseInsensitiveContains("Weekend errands"))
        XCTAssertTrue(historyRow.label.contains("Cedar Pleated Trousers"))
        XCTAssertTrue(historyRow.label.contains("Saffron Mini Tote"))
        attachScreenshot(named: "Demo History - Fictional Worn Look")

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

        element(in: app, identifier: Identifier.moreItemActions).tap()
        let deleteAction = app.buttons["Delete"].firstMatch
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 2))
        deleteAction.tap()
        let confirmDelete = app.buttons["Delete"].firstMatch
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

        assertLocalOnboardingIsVisible(in: app)
        XCTAssertFalse(element(in: app, identifier: Identifier.demoBanner).exists)
        XCTAssertFalse(app.buttons["Sign in with Google"].exists)
    }

    @MainActor
    func testDemoPendingImportCanBeReviewedAndAcceptedOffline() throws {
        let app = launchDemo()
        XCTAssertTrue(element(in: app, identifier: Identifier.demoBanner).waitForExistence(timeout: 5))

        tab(in: app, identifier: Identifier.wardrobeTab, fallbackLabel: "Wardrobe").tap()
        XCTAssertTrue(app.navigationBars["Catalog"].waitForExistence(timeout: 3))

        let reviewFilter = app.buttons["Needs Review 1"]
        XCTAssertTrue(reviewFilter.waitForExistence(timeout: 3))
        reviewFilter.tap()

        let pendingDress = element(in: app, identifier: Identifier.pendingDress)
        XCTAssertTrue(pendingDress.waitForExistence(timeout: 3))
        pendingDress.tap()
        XCTAssertTrue(app.navigationBars["Dusk Wrap Dress"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Needs your review"].exists)
        XCTAssertTrue(app.staticTexts["Extraction confidence: Medium"].exists)

        element(in: app, identifier: "item.detail.reviewImport").tap()
        XCTAssertTrue(app.navigationBars["Review Import"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Check every imported detail"].exists)
        XCTAssertTrue(element(in: app, identifier: "item.review.confidence").exists)
        element(in: app, identifier: "item.review.accept").tap()

        XCTAssertTrue(app.navigationBars["Dusk Wrap Dress"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Needs your review"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Nothing needs review"].waitForExistence(timeout: 3))
        attachScreenshot(named: "Demo Import - Reviewed and Accepted")
    }

    @MainActor
    func testFirstLaunchCanStartLocallyWithoutGoogle() throws {
        let app = launchApp(arguments: [
            "--wardrobe-ui-testing-local",
            "-\(Identifier.onboardingCompletion)", "NO",
        ])

        assertLocalOnboardingIsVisible(in: app)
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
    func testPhotoLibraryStaysPresentedUntilTheUserCancels() throws {
        let app = launchApp(arguments: [
            "--wardrobe-ui-testing-local",
            "-\(Identifier.onboardingCompletion)", "YES",
        ])

        XCTAssertTrue(app.navigationBars["Catalog"].waitForExistence(timeout: 5))
        element(in: app, identifier: Identifier.addItem).tap()
        XCTAssertTrue(app.navigationBars["Add Item"].waitForExistence(timeout: 3))

        element(in: app, identifier: Identifier.photoLibrary).tap()
        let photoLibrary = app.navigationBars["Photos"]
        // PhotosUI is a separate system process and its first cold launch can
        // take longer on a busy CI simulator. Wait for that boundary without
        // weakening the assertions that it remains presented and cancellable.
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
    func testSettingsHubKeepsDetailedControlsBehindFourClearChoices() throws {
        let app = launchConnectedUITestExperience()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(element(in: app, identifier: Identifier.connectedFeatures).exists)
        XCTAssertTrue(element(in: app, identifier: Identifier.wardrobeAndDemo).exists)
        XCTAssertTrue(element(in: app, identifier: Identifier.privacyAndData).exists)
        XCTAssertTrue(element(in: app, identifier: Identifier.helpAndSupport).exists)
        XCTAssertTrue(app.staticTexts["Gmail import, AI styling, and reminders"].exists)
        XCTAssertTrue(app.staticTexts["Data use, privacy policy, and deletion"].exists)
        XCTAssertFalse(element(in: app, identifier: Identifier.receiptAllow).exists)
        XCTAssertFalse(element(in: app, identifier: Identifier.deleteLocalData).exists)
        attachScreenshot(named: "Settings - Simple Hub")

        openConnectedFeatures(in: app)
        XCTAssertTrue(app.staticTexts["Gmail Import"].exists)
        XCTAssertTrue(scrollToText("AI Styling & Reminder", in: app))
    }

    @MainActor
    func testConnectedDisclosuresAndConsentsAreExplicitAndReversible() throws {
        var app = launchConnectedUITestExperience()
        openConnectedFeatures(in: app)

        XCTAssertTrue(app.staticTexts["Connected (read-only)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["reviewer@example.invalid"].exists)
        XCTAssertTrue(app.staticTexts["Receipt analysis"].exists)
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "raw message bodies are not sent")
            ).firstMatch.exists
        )

        let receiptAllow = element(in: app, identifier: Identifier.receiptAllow)
        XCTAssertTrue(scrollToElement(receiptAllow, in: app))
        receiptAllow.tap()
        XCTAssertTrue(
            element(in: app, identifier: Identifier.receiptAllowed)
                .waitForExistence(timeout: 3)
        )

        let receiptWithdraw = element(in: app, identifier: Identifier.receiptWithdraw)
        XCTAssertTrue(scrollToElement(receiptWithdraw, in: app))
        receiptWithdraw.tap()
        XCTAssertTrue(receiptAllow.waitForExistence(timeout: 3))

        attachScreenshot(named: "Connected Settings - Receipt Consent Withdrawn")

        app.terminate()
        app = launchConnectedUITestExperience()
        openConnectedFeatures(in: app)

        let stylingAllow = element(in: app, identifier: Identifier.stylingAllow)
        XCTAssertTrue(scrollToElement(stylingAllow, in: app))
        XCTAssertTrue(app.staticTexts["AI styling"].exists)
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "Wardrobe photos and Gmail messages are not included")
            ).firstMatch.exists
        )
        attachScreenshot(named: "Connected Settings - Disclosures Before Consent")
        stylingAllow.tap()
        XCTAssertTrue(
            element(in: app, identifier: Identifier.stylingAllowed)
                .waitForExistence(timeout: 3)
        )

        let stylingWithdraw = element(in: app, identifier: Identifier.stylingWithdraw)
        XCTAssertTrue(scrollToElement(stylingWithdraw, in: app))
        stylingWithdraw.tap()
        XCTAssertTrue(stylingAllow.waitForExistence(timeout: 3))
        attachScreenshot(named: "Connected Settings - Consents Withdrawn")
    }

    @MainActor
    func testReminderCanEnableChangeTimeAndDisableWithoutSystemPermission() throws {
        let app = launchConnectedUITestExperience()
        openConnectedFeatures(in: app)

        let stylingAllow = element(in: app, identifier: Identifier.stylingAllow)
        XCTAssertTrue(scrollToElement(stylingAllow, in: app))
        stylingAllow.tap()
        XCTAssertTrue(
            element(in: app, identifier: Identifier.stylingAllowed)
                .waitForExistence(timeout: 3)
        )

        let reminder = element(in: app, identifier: Identifier.reminderToggle)
        XCTAssertTrue(scrollToElement(reminder, in: app))
        XCTAssertTrue(waitForSwitch(of: reminder, expected: false))
        reminder.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        var timePicker = element(in: app, identifier: Identifier.reminderTime)
        XCTAssertTrue(scrollBidirectionallyToElement(timePicker, in: app))
        XCTAssertTrue(waitForEnabledState(of: timePicker, expected: true))
        XCTAssertNotEqual(timePicker.value as? String, "Reminder is off")
        XCTAssertTrue(timePicker.isEnabled)
        timePicker.tap()

        let wheels = app.pickerWheels
        XCTAssertGreaterThanOrEqual(wheels.count, 2)
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "9")
        if wheels.count >= 3 {
            wheels.element(boundBy: 1).adjust(toPickerWheelValue: "15")
            wheels.element(boundBy: 2).adjust(toPickerWheelValue: "AM")
        } else {
            wheels.element(boundBy: 1).adjust(toPickerWheelValue: "15")
        }
        app.navigationBars["Connected Features"].tap()

        timePicker = element(in: app, identifier: Identifier.reminderTime)
        XCTAssertTrue(
            waitForValue(of: timePicker) { value in
                value.contains("9:15") || value.contains("09:15")
            }
        )
        attachScreenshot(named: "Connected Settings - Reminder Time Changed")

        let refreshedReminder = element(in: app, identifier: Identifier.reminderToggle)
        XCTAssertTrue(scrollDownToElement(refreshedReminder, in: app))
        refreshedReminder.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        timePicker = element(in: app, identifier: Identifier.reminderTime)
        XCTAssertTrue(scrollBidirectionallyToElement(timePicker, in: app))
        XCTAssertTrue(waitForEnabledState(of: timePicker, expected: false))
        XCTAssertEqual(timePicker.value as? String, "Reminder is off")
    }

    @MainActor
    func testSignOutRetainsLocalDataAndShowsDisconnectedState() throws {
        let app = launchConnectedUITestExperience()
        openConnectedFeatures(in: app)
        let signOut = element(in: app, identifier: Identifier.signOut)
        XCTAssertTrue(scrollToElement(signOut, in: app))
        signOut.tap()

        XCTAssertTrue(app.staticTexts["Sign out on this device?"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "Google permission")
            ).firstMatch.exists
        )
        app.buttons["Sign Out"].tap()

        XCTAssertTrue(app.staticTexts["Not connected"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Sign in with Google"].exists)
        returnToSettingsHub(from: "Connected Features", in: app)
        openPrivacyAndData(in: app)
        XCTAssertTrue(app.staticTexts["Data on This Device"].exists)
        attachScreenshot(named: "Connected Settings - Signed Out Locally")
        returnToSettingsHub(from: "Privacy & Data", in: app)
        assertNoConnectedNetworkAttempt(in: app)
    }

    @MainActor
    func testDisconnectExplainsRevocationAndLeavesLocalDataAvailable() throws {
        let app = launchConnectedUITestExperience()
        openConnectedFeatures(in: app)
        let disconnect = element(in: app, identifier: Identifier.disconnect)
        XCTAssertTrue(scrollToElement(disconnect, in: app))
        disconnect.tap()

        XCTAssertTrue(app.staticTexts["Disconnect Google?"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "revoke its Google access")
            ).firstMatch.exists
        )
        confirmationButton(
            in: app,
            label: "Disconnect Google",
            excludingIdentifier: Identifier.disconnect
        ).tap()

        XCTAssertTrue(app.staticTexts["Not connected"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Sign in with Google"].exists)
        returnToSettingsHub(from: "Connected Features", in: app)
        openPrivacyAndData(in: app)
        XCTAssertTrue(app.staticTexts["Data on This Device"].exists)
        attachScreenshot(named: "Connected Settings - Google Disconnected")
        returnToSettingsHub(from: "Privacy & Data", in: app)
        assertNoConnectedNetworkAttempt(in: app)
    }

    @MainActor
    func testServerSecurityDeletionKeepsLocalDataAndGoogleConnected() throws {
        let app = launchConnectedUITestExperience()
        openConnectedFeatures(in: app)
        XCTAssertTrue(app.staticTexts["2 items in your local wardrobe"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollDownToElement(app.staticTexts["Connected (read-only)"], in: app))

        returnToSettingsHub(from: "Connected Features", in: app)
        openPrivacyAndData(in: app)
        let delete = element(in: app, identifier: Identifier.deleteServerSecurityData)
        XCTAssertTrue(scrollBidirectionallyToElement(delete, in: app))
        delete.tap()

        XCTAssertTrue(app.staticTexts["Delete server security data?"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "wardrobe and Google connection stay unchanged")
            ).firstMatch.exists
        )
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "customer-visible proxy and platform stream lasts 7 days")
            ).firstMatch.exists
        )
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "provider-internal logs may include source IP")
            ).firstMatch.exists
        )
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(
                    format: "label CONTAINS %@",
                    "Snapshots stop appearing from Fly’s customer listing after 14 days"
                )
            ).firstMatch.exists
        )
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "does not publish an all-copy deletion deadline")
            ).firstMatch.exists
        )
        confirmationButton(
            in: app,
            label: "Delete Server Security Data",
            excludingIdentifier: Identifier.deleteServerSecurityData
        ).tap()

        let success = element(
            in: app,
            identifier: "settings.privacy.deleteServerSecurityData.success"
        )
        XCTAssertTrue(success.waitForExistence(timeout: 5))
        XCTAssertTrue(success.label.contains("Live server security record deleted"))

        returnToSettingsHub(from: "Privacy & Data", in: app)
        openConnectedFeatures(in: app)
        XCTAssertTrue(app.staticTexts["2 items in your local wardrobe"].waitForExistence(timeout: 3))
        XCTAssertTrue(scrollDownToElement(app.staticTexts["Connected (read-only)"], in: app))
        returnToSettingsHub(from: "Connected Features", in: app)
        assertNoConnectedNetworkAttempt(in: app)
    }

    @MainActor
    func testVerifiedLocalDeletionKeepsGoogleConnectedButRemovesFictionalRows() throws {
        let app = launchConnectedUITestExperience()
        openConnectedFeatures(in: app)
        XCTAssertTrue(app.staticTexts["2 items in your local wardrobe"].waitForExistence(timeout: 5))

        returnToSettingsHub(from: "Connected Features", in: app)
        openPrivacyAndData(in: app)

        let delete = element(in: app, identifier: Identifier.deleteLocalData)
        XCTAssertTrue(scrollToElement(delete, in: app))
        delete.tap()

        XCTAssertTrue(app.staticTexts["Delete local data?"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "does not revoke Google access")
            ).firstMatch.exists
        )
        confirmationButton(
            in: app,
            label: "Delete Local Data",
            excludingIdentifier: Identifier.deleteLocalData
        ).tap()

        XCTAssertTrue(app.alerts["Local Data Deleted"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.alerts["Local Data Deleted"].staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "Google access was not revoked")
            ).firstMatch.exists
        )
        app.alerts["Local Data Deleted"].buttons["OK"].tap()

        returnToSettingsHub(from: "Privacy & Data", in: app)
        openConnectedFeatures(in: app)
        XCTAssertTrue(app.staticTexts["0 items in your local wardrobe"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            scrollDownToElement(app.staticTexts["Connected (read-only)"], in: app)
        )
        attachScreenshot(named: "Connected Settings - Verified Local Data Deletion")
        returnToSettingsHub(from: "Connected Features", in: app)
        assertNoConnectedNetworkAttempt(in: app)
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
    private func assertLocalOnboardingIsVisible(in app: XCUIApplication) {
        let hero = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Your wardrobe, your way")
        ).firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertTrue(hero.label.contains("Your wardrobe, your way"))
        XCTAssertTrue(hero.label.contains("Gmail import and AI styling are optional"))

        let local = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", "without a Google account")
        ).firstMatch
        XCTAssertTrue(local.exists)
        XCTAssertTrue(local.label.contains("without a Google account"))
    }

    @MainActor
    private func launchConnectedUITestExperience() -> XCUIApplication {
        let app = launchApp(arguments: ["--wardrobe-ui-testing-connected"])
        XCTAssertTrue(
            element(in: app, identifier: Identifier.connectedRoot)
                .waitForExistence(timeout: 5)
        )
        assertNoConnectedNetworkAttempt(in: app)
        return app
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
    private func returnToSettingsHub(from navigationTitle: String, in app: XCUIApplication) {
        let navigationBar = app.navigationBars[navigationTitle]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 2))
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: destination)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
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
    private func scrollToText(_ text: String, in app: XCUIApplication) -> Bool {
        let element = app.staticTexts[text]
        return scrollToElement(element, in: app)
    }

    @MainActor
    private func scrollDownToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 12
    ) -> Bool {
        if element.waitForExistence(timeout: 1), element.isHittable { return true }
        for _ in 0..<attempts {
            app.swipeDown()
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

    @MainActor
    private func waitForValue(
        of element: XCUIElement,
        timeout: TimeInterval = 3,
        predicate: @escaping (String) -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let value = element.value as? String, predicate(value) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return false
    }

    @MainActor
    private func assertNoConnectedNetworkAttempt(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            element(in: app, identifier: Identifier.networkStatus).label,
            "Network boundary: 0 requests attempted",
            "The isolated connected flow must not cross its deny-network Gmail boundary.",
            file: file,
            line: line
        )
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
