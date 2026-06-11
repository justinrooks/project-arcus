//
//  SkyAwareUITests.swift
//  SkyAwareUITests
//
//  Created by Justin Rooks on 7/3/25.
//

import XCTest

final class SkyAwareUITests: XCTestCase {
    private let sharedDefaultsSuiteName = "com.justinrooks.skyaware"
    private let reliabilityAskCountKey = "fb016.locationReliability.askCount"
    private let reliabilityLastImpressionKey = "fb016.locationReliability.lastCountedRailImpressionAt"
    private let reliabilityLastCountedDayKey = "fb016.locationReliability.lastCountedQualifyingDay"
    private let reliabilitySuppressedDayKey = "fb016.locationReliability.lastSuppressedQualifyingDay"

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testTabNavigationLoadsEachPrimaryView() throws {
        let app = XCUIApplication()
        app.launch()

        completeOnboardingIfNeeded(in: app)
        dismissBlockingSheetsIfNeeded(in: app)

        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 10), "Expected Today tab to exist after launch.")

        let alertsTab = app.tabBars.buttons["Alerts"]
        XCTAssertTrue(alertsTab.waitForExistence(timeout: 10), "Expected Alerts tab to exist.")
        alertsTab.tap()
        XCTAssertTrue(app.navigationBars["Active Alerts"].waitForExistence(timeout: 10), "Expected Alerts view to load.")

        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 10), "Expected Map tab to exist.")
        mapTab.tap()
        XCTAssertTrue(app.buttons["Map layers"].waitForExistence(timeout: 10), "Expected Map view content to load.")

        let outlooksTab = app.tabBars.buttons["Outlooks"]
        XCTAssertTrue(outlooksTab.waitForExistence(timeout: 10), "Expected Outlooks tab to exist.")
        outlooksTab.tap()
        XCTAssertTrue(app.navigationBars["Convective Outlooks"].waitForExistence(timeout: 10), "Expected Outlooks view to load.")

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Expected Settings tab to exist.")
        settingsTab.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10), "Expected Settings view to load.")
    }

    @MainActor
    func testSettingsShowsNotificationRecoveryCopyWhenAuthorizationDenied() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_FORCE_ONBOARDING_COMPLETE"] = "1"
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = "authorized"
        app.launchEnvironment["UI_TESTS_SUPPRESS_LOCATION_RESTRICTED_SHEET"] = "1"
        app.launchEnvironment["UI_TESTS_NOTIFICATION_AUTH_MODE"] = "denied"
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Expected Settings tab to exist.")
        settingsTab.tap()

        XCTAssertTrue(
            app.staticTexts["Notifications are disabled for SkyAware in iOS Settings. Your preferences are preserved and will apply again if you re-enable notifications."].waitForExistence(timeout: 10),
            "Expected blocked notification copy to appear when authorization is denied."
        )

        XCTAssertTrue(app.switches["Mesoscale Discussion Alerts"].waitForExistence(timeout: 10), "Expected mesoscale discussion copy to use canonical terminology.")
        XCTAssertTrue(app.switches["Local Severe-Weather Alerts"].waitForExistence(timeout: 10), "Expected local severe-weather alert copy to use canonical terminology.")
        XCTAssertTrue(app.switches["Share Approximate Location for Alerts"].waitForExistence(timeout: 10), "Expected location-sharing copy to use canonical terminology.")
        XCTAssertTrue(
            app.staticTexts["Get local severe-weather alerts relevant to your area."].waitForExistence(timeout: 10),
            "Expected local severe-weather helper copy to appear."
        )
        XCTAssertTrue(
            app.staticTexts["Share an approximate location so SkyAware can match alerts to your area."].waitForExistence(timeout: 10),
            "Expected location-sharing helper copy to appear."
        )

        let openSettingsButton = app.buttons["Open Settings"]
        XCTAssertTrue(openSettingsButton.waitForExistence(timeout: 10), "Expected Open Settings action to appear when authorization is denied.")
        openSettingsButton.tap()

        let settingsApp = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(settingsApp.waitForExistence(timeout: 10), "Expected Open Settings to switch to the Settings app.")
    }

    @MainActor
    func testSettingsShowsNotificationAvailabilityCopyWhenAuthorizationAuthorized() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_FORCE_ONBOARDING_COMPLETE"] = "1"
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = "authorized"
        app.launchEnvironment["UI_TESTS_SUPPRESS_LOCATION_RESTRICTED_SHEET"] = "1"
        app.launchEnvironment["UI_TESTS_NOTIFICATION_AUTH_MODE"] = "authorized"
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Expected Settings tab to exist.")
        settingsTab.tap()

        XCTAssertTrue(
            app.staticTexts["iOS can deliver SkyAware notifications normally."].waitForExistence(timeout: 10),
            "Expected authorized notification copy to appear when authorization is granted."
        )
        XCTAssertFalse(app.buttons["Open Settings"].exists, "Did not expect Open Settings when authorization is available.")
    }

    @MainActor
    func testSettingsShowsNotificationPendingCopyWhenAuthorizationNotDetermined() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_FORCE_ONBOARDING_COMPLETE"] = "1"
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = "authorized"
        app.launchEnvironment["UI_TESTS_SUPPRESS_LOCATION_RESTRICTED_SHEET"] = "1"
        app.launchEnvironment["UI_TESTS_NOTIFICATION_AUTH_MODE"] = "notDetermined"
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Expected Settings tab to exist.")
        settingsTab.tap()

        XCTAssertTrue(
            app.staticTexts["SkyAware can ask iOS for notification access. Your preferences are saved now and will apply if you allow notifications."].waitForExistence(timeout: 10),
            "Expected pending notification copy to appear when authorization is not determined."
        )
        XCTAssertFalse(app.buttons["Open Settings"].exists, "Did not expect Open Settings while authorization is not determined.")
    }

    @MainActor
    func testFirstLaunchOnboardingCompletesSuccessfully() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_RESET_ONBOARDING"] = "1"
        app.launch()

        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 10), "Expected onboarding welcome screen on first launch.")
        getStartedButton.tap()

        let understandButton = app.buttons["I Understand"]
        XCTAssertTrue(understandButton.waitForExistence(timeout: 10), "Expected onboarding disclaimer screen.")
        understandButton.tap()

        let locationSkipButton = app.buttons["Skip for Now"]
        XCTAssertTrue(locationSkipButton.waitForExistence(timeout: 10), "Expected location permission onboarding step.")
        locationSkipButton.tap()

        let notificationSkipButton = app.buttons["Skip for Now"]
        XCTAssertTrue(notificationSkipButton.waitForExistence(timeout: 10), "Expected notification permission onboarding step.")
        notificationSkipButton.tap()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10), "Expected app home tabs after onboarding completion.")
    }

    @MainActor
    func testLaunchPresentsDisclaimerBeforeRestrictedLocationWhenBothApply() throws {
        configureLaunchDefaults(onboardingComplete: true, disclaimerAcceptedVersion: 0)

        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = "restricted"
        app.launch()

        let disclaimerButton = app.buttons["I Understand"]
        XCTAssertTrue(disclaimerButton.waitForExistence(timeout: 10), "Expected the disclaimer sheet to appear first.")
        XCTAssertFalse(app.buttons["Enable Location"].exists, "Did not expect the restricted-location sheet before the disclaimer was accepted.")

        disclaimerButton.tap()

        let locationButton = app.buttons["Enable Location"]
        XCTAssertTrue(locationButton.waitForExistence(timeout: 10), "Expected the restricted-location sheet after accepting the disclaimer.")
    }

    @MainActor
    func testLaunchPresentsDisclaimerOnlyWhenDisclaimerIsStale() throws {
        configureLaunchDefaults(onboardingComplete: true, disclaimerAcceptedVersion: 0)

        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = "authorized"
        app.launch()

        let disclaimerButton = app.buttons["I Understand"]
        XCTAssertTrue(disclaimerButton.waitForExistence(timeout: 10), "Expected the disclaimer sheet to appear when the stored version is stale.")
        XCTAssertFalse(app.buttons["Enable Location"].exists, "Did not expect a restricted-location sheet when location is authorized.")

        disclaimerButton.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10), "Expected home after accepting the disclaimer when no launch sheets remain.")
    }

    @MainActor
    func testLaunchPresentsRestrictedLocationOnlyWhenDisclaimerIsCurrent() throws {
        configureLaunchDefaults(onboardingComplete: true, disclaimerAcceptedVersion: 1)

        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = "restricted"
        app.launch()

        let locationButton = app.buttons["Enable Location"]
        XCTAssertTrue(locationButton.waitForExistence(timeout: 10), "Expected the restricted-location sheet when the disclaimer is current.")
        XCTAssertFalse(app.buttons["I Understand"].exists, "Did not expect the disclaimer sheet when the stored version is current.")
    }

    @MainActor
    func testOnboardingWhileUsingShowsAlwaysUpgradePageAndAllowsNotNow() throws {
        resetReliabilityLedgerDefaults()
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_RESET_ONBOARDING"] = "1"
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = "authorized"
        app.launch()

        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 10), "Expected onboarding welcome screen.")
        app.buttons["Get Started"].tap()

        XCTAssertTrue(app.buttons["I Understand"].waitForExistence(timeout: 10), "Expected onboarding disclaimer screen.")
        app.buttons["I Understand"].tap()

        let enableLocationButton = app.buttons["Enable Location"]
        XCTAssertTrue(enableLocationButton.waitForExistence(timeout: 10), "Expected location permission step.")
        enableLocationButton.tap()

        let enableAlwaysButton = app.buttons["Enable Always"]
        XCTAssertTrue(enableAlwaysButton.waitForExistence(timeout: 10), "Expected Always upgrade onboarding page.")

        let notNowButton = app.buttons["Not Now"]
        XCTAssertTrue(notNowButton.waitForExistence(timeout: 10), "Expected Not Now action on Always upgrade page.")
        notNowButton.tap()

        let notificationSkipButton = app.buttons["Skip for Now"]
        XCTAssertTrue(notificationSkipButton.waitForExistence(timeout: 10), "Expected notification permission onboarding step.")
        notificationSkipButton.tap()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10), "Expected app home tabs after onboarding completion.")
        assertReliabilityAskCountEquals(0)
    }

    @MainActor
    func testOnboardingSwipeCannotBypassRequiredSteps() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_RESET_ONBOARDING"] = "1"
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = "authorized"
        app.launch()

        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 10), "Expected onboarding welcome screen.")
        app.swipeLeft()
        XCTAssertTrue(getStartedButton.exists, "Expected the welcome page to ignore swipe navigation.")

        getStartedButton.tap()

        let understandButton = app.buttons["I Understand"]
        XCTAssertTrue(understandButton.waitForExistence(timeout: 10), "Expected onboarding disclaimer screen.")
        app.swipeLeft()
        XCTAssertTrue(understandButton.exists, "Expected the disclaimer page to ignore swipe navigation.")

        understandButton.tap()

        let enableLocationButton = app.buttons["Enable Location"]
        XCTAssertTrue(enableLocationButton.waitForExistence(timeout: 10), "Expected the location permission step.")
        app.swipeLeft()
        XCTAssertTrue(enableLocationButton.exists, "Expected the location permission page to ignore swipe navigation.")
        XCTAssertFalse(app.buttons["Allow Notifications"].exists, "Swipe should not jump straight to notifications.")
    }

    @MainActor
    func testSummaryShowsTwoLocationRequiredBlocksWhenLocationIsRestricted() throws {
        let app = launchHomeForLocationPermissionScenario(mode: "restricted")
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10), "Expected Today tab to exist.")

        let locationRequiredLabels = app.staticTexts.matching(NSPredicate(format: "label == %@", "Location Required"))
        let labelsExpectation = expectation(
            for: NSPredicate(format: "count == 2"),
            evaluatedWith: locationRequiredLabels
        )
        wait(for: [labelsExpectation], timeout: 12)

        XCTAssertEqual(
            locationRequiredLabels.count,
            2,
            "Expected exactly two 'Location Required' blocks on summary when location permission is restricted."
        )
    }

    @MainActor
    func testSummaryDoesNotShowLocationRequiredBlocksWhenLocationIsAuthorized() throws {
        let app = launchHomeForLocationPermissionScenario(mode: "authorized")
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10), "Expected Today tab to exist.")

        let locationRequiredLabels = app.staticTexts.matching(NSPredicate(format: "label == %@", "Location Required"))
        XCTAssertEqual(
            locationRequiredLabels.count,
            0,
            "Did not expect 'Location Required' blocks when location permission is authorized."
        )
    }

    @MainActor
    func testSummaryAlertTapShowsSheetAndAlertTabTapShowsWatchDetailView() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_FORCE_ONBOARDING_COMPLETE"] = "1"
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = "authorized"
        app.launchEnvironment["UI_TESTS_SUPPRESS_LOCATION_RESTRICTED_SHEET"] = "1"
        app.launchEnvironment["UI_TESTS_STATIC_HOME"] = "1"
        app.launch()

        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 10), "Expected Today tab to exist.")

        let summaryWatchRow = app.buttons["watches-row-ui-test-watch-001"]
        XCTAssertTrue(summaryWatchRow.waitForExistence(timeout: 10), "Expected seeded watch row to appear in Summary local alerts.")
        summaryWatchRow.tap()

        let summarySheetDetail = app.otherElements["summary-watch-detail-sheet"]
        XCTAssertTrue(summarySheetDetail.waitForExistence(timeout: 10), "Expected WatchDetailView sheet to appear from Summary tap.")
        XCTAssertFalse(app.navigationBars["Weather Alert"].exists, "Summary local alert should open as a sheet, not push full detail.")

        summarySheetDetail.swipeDown()
        XCTAssertTrue(
            summarySheetDetail.waitForNonExistence(timeout: 10),
            "Expected Summary watch detail sheet to dismiss before continuing."
        )
        XCTAssertTrue(summaryWatchRow.waitForExistence(timeout: 10), "Expected sheet dismissal to return to Summary.")

        let alertsTab = app.tabBars.buttons["Alerts"]
        XCTAssertTrue(alertsTab.waitForExistence(timeout: 10), "Expected Alerts tab to exist.")
        alertsTab.tap()

        let alertCenterWatchText = app.staticTexts["UI Test Tornado Watch"].firstMatch
        XCTAssertTrue(alertCenterWatchText.waitForExistence(timeout: 10), "Expected seeded watch to appear in Alerts tab.")
        alertCenterWatchText.tap()

        XCTAssertTrue(app.navigationBars["Weather Alert"].waitForExistence(timeout: 10), "Expected Alert tab watch tap to push WatchDetailView.")
    }

    @MainActor
    func testAlertDetailVoiceOverKeepsFullInstructionAndSummaryText() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_FORCE_ONBOARDING_COMPLETE"] = "1"
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = "authorized"
        app.launchEnvironment["UI_TESTS_SUPPRESS_LOCATION_RESTRICTED_SHEET"] = "1"
        app.launchEnvironment["UI_TESTS_STATIC_HOME"] = "1"
        app.launch()

        let alertsTab = app.tabBars.buttons["Alerts"]
        XCTAssertTrue(alertsTab.waitForExistence(timeout: 10), "Expected Alerts tab to exist.")
        alertsTab.tap()

        let alertRow = app.buttons["alert-center-watch-row-ui-test-watch-001"]
        XCTAssertTrue(alertRow.waitForExistence(timeout: 10), "Expected seeded alert row to appear.")
        alertRow.tap()

        XCTAssertTrue(app.navigationBars["Weather Alert"].waitForExistence(timeout: 10), "Expected alert detail to open.")

        let fullInstruction = "Seek shelter immediately if threatening weather approaches, move to an interior room on the lowest floor, and stay away from windows until the warning is lifted."
        let fullSummary = "UI test watch description for navigation and sheet validation. This longer summary text is used to verify that VoiceOver announces the full visible weather content without replacing it with a generic label."

        XCTAssertTrue(
            app.staticTexts[fullInstruction].waitForExistence(timeout: 10),
            "Expected the full instruction text to remain accessible."
        )
        XCTAssertTrue(
            app.staticTexts[fullSummary].waitForExistence(timeout: 10),
            "Expected the full summary text to remain accessible."
        )
        XCTAssertFalse(app.staticTexts["Instructions"].exists, "Did not expect a generic accessibility label to replace instruction text.")
        XCTAssertFalse(app.staticTexts["Summary"].exists, "Did not expect a generic accessibility label to replace summary text.")
    }

    @MainActor
    func testAlertCenterSecondAlertTapPushesExpectedDetailAndBackReturnsToList() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_FORCE_ONBOARDING_COMPLETE"] = "1"
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = "authorized"
        app.launchEnvironment["UI_TESTS_SUPPRESS_LOCATION_RESTRICTED_SHEET"] = "1"
        app.launchEnvironment["UI_TESTS_STATIC_HOME"] = "1"
        app.launch()

        let alertsTab = app.tabBars.buttons["Alerts"]
        XCTAssertTrue(alertsTab.waitForExistence(timeout: 10), "Expected Alerts tab to exist.")
        alertsTab.tap()

        let secondAlertRow = app.buttons["alert-center-watch-row-ui-test-watch-002"]
        XCTAssertTrue(secondAlertRow.waitForExistence(timeout: 10), "Expected second seeded alert row to appear.")
        secondAlertRow.tap()

        XCTAssertTrue(app.navigationBars["Weather Alert"].waitForExistence(timeout: 10), "Expected second alert tap to push detail.")
        XCTAssertTrue(
            app.staticTexts["UI Test Fire Weather Watch"].waitForExistence(timeout: 10),
            "Expected detail to show the second alert, not a stale first alert selection."
        )

        let backButton = app.navigationBars["Weather Alert"].buttons["Active Alerts"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 10), "Expected back button to return to the alert list.")
        backButton.tap()

        XCTAssertTrue(app.navigationBars["Active Alerts"].waitForExistence(timeout: 10), "Expected Back to return to the alert list.")
        XCTAssertTrue(secondAlertRow.waitForExistence(timeout: 10), "Expected second alert row to remain available after returning.")
        XCTAssertFalse(app.navigationBars["Weather Alert"].exists, "Back should not reveal a queued stale alert detail.")
    }

    @MainActor
    func testSummaryReliabilityRailOpensExplanationSheetAndNotNowDismisses() throws {
        resetReliabilityLedgerDefaults()
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_FORCE_ONBOARDING_COMPLETE"] = "1"
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = "authorized"
        app.launchEnvironment["UI_TESTS_SUPPRESS_LOCATION_RESTRICTED_SHEET"] = "1"
        app.launchEnvironment["UI_TESTS_STATIC_HOME"] = "1"
        app.launchEnvironment["UI_TESTS_FORCE_RELIABILITY_RAIL"] = "1"
        app.launch()

        let rail = app.buttons["summary-reliability-rail"]
        XCTAssertTrue(rail.waitForExistence(timeout: 10), "Expected reliability rail in Summary.")
        rail.tap()

        let sheetTitle = app.navigationBars["Enable Always"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 10), "Expected reliability explanation sheet.")

        let statusRow = app.otherElements["summary-reliability-status-row"]
        XCTAssertTrue(statusRow.waitForExistence(timeout: 10), "Expected Current/Recommended status row in sheet.")

        let notNowButton = app.buttons["summary-reliability-sheet-not-now"]
        XCTAssertTrue(notNowButton.waitForExistence(timeout: 10), "Expected Not Now action in reliability sheet.")
        notNowButton.tap()

        XCTAssertTrue(rail.waitForNonExistence(timeout: 10), "Expected same-day suppression to keep rail hidden after dismissal.")
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10), "Expected app to remain on Summary after dismissal.")
    }

    @MainActor
    func testSummaryReliabilityRailPrimaryAndDismissActionsAreIndependentButtons() throws {
        resetReliabilityLedgerDefaults()
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_FORCE_ONBOARDING_COMPLETE"] = "1"
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = "authorized"
        app.launchEnvironment["UI_TESTS_SUPPRESS_LOCATION_RESTRICTED_SHEET"] = "1"
        app.launchEnvironment["UI_TESTS_STATIC_HOME"] = "1"
        app.launchEnvironment["UI_TESTS_FORCE_RELIABILITY_RAIL"] = "1"
        app.launch()

        let railButton = app.buttons["summary-reliability-rail"]
        XCTAssertTrue(railButton.waitForExistence(timeout: 10), "Expected primary reliability rail button in Summary.")

        let notNowButton = app.buttons["summary-reliability-not-now"]
        XCTAssertTrue(notNowButton.waitForExistence(timeout: 10), "Expected Not Now button in Summary reliability rail.")

        notNowButton.tap()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10), "Expected app to remain on Summary after dismissing the rail.")
        XCTAssertFalse(
            app.navigationBars["Enable Always"].exists,
            "Tapping Not Now on the rail must not open the explanation sheet."
        )
        XCTAssertTrue(railButton.waitForNonExistence(timeout: 10), "Expected same-day suppression to hide the rail after dismissal.")
    }

    @MainActor
    private func completeOnboardingIfNeeded(in app: XCUIApplication) {
        if app.buttons["Get Started"].waitForExistence(timeout: 2) {
            app.buttons["Get Started"].tap()
        }

        if app.buttons["I Understand"].waitForExistence(timeout: 2) {
            app.buttons["I Understand"].tap()
        }

        if app.buttons["Skip for Now"].waitForExistence(timeout: 2) {
            app.buttons["Skip for Now"].tap()
        }

        if app.buttons["Skip for Now"].waitForExistence(timeout: 2) {
            app.buttons["Skip for Now"].tap()
        }
    }

    @MainActor
    private func dismissBlockingSheetsIfNeeded(in app: XCUIApplication) {
        if app.buttons["I Understand"].waitForExistence(timeout: 2) {
            app.buttons["I Understand"].tap()
        }

        if app.buttons["Skip for Now"].waitForExistence(timeout: 2) {
            app.buttons["Skip for Now"].tap()
        }
    }

    @MainActor
    private func launchHomeForLocationPermissionScenario(mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_FORCE_ONBOARDING_COMPLETE"] = "1"
        app.launchEnvironment["UI_TESTS_SUPPRESS_LOCATION_RESTRICTED_SHEET"] = "1"
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = mode
        app.launch()
        return app
    }

    private func resetReliabilityLedgerDefaults() {
        guard let defaults = UserDefaults(suiteName: sharedDefaultsSuiteName) else { return }
        defaults.removeObject(forKey: reliabilityAskCountKey)
        defaults.removeObject(forKey: reliabilityLastImpressionKey)
        defaults.removeObject(forKey: reliabilityLastCountedDayKey)
        defaults.removeObject(forKey: reliabilitySuppressedDayKey)
        defaults.synchronize()
    }

    private func configureLaunchDefaults(onboardingComplete: Bool, disclaimerAcceptedVersion: Int) {
        guard let defaults = UserDefaults(suiteName: sharedDefaultsSuiteName) else { return }
        defaults.set(onboardingComplete, forKey: "onboardingComplete")
        defaults.set(disclaimerAcceptedVersion, forKey: "disclaimerAcceptedVersion")
        defaults.synchronize()
        UserDefaults.standard.set(onboardingComplete, forKey: "onboardingComplete")
        UserDefaults.standard.set(disclaimerAcceptedVersion, forKey: "disclaimerAcceptedVersion")
        UserDefaults.standard.synchronize()
    }

    private func assertReliabilityAskCountEquals(_ expected: Int, file: StaticString = #filePath, line: UInt = #line) {
        guard let defaults = UserDefaults(suiteName: sharedDefaultsSuiteName) else {
            XCTFail("Expected shared defaults suite \(sharedDefaultsSuiteName)", file: file, line: line)
            return
        }
        let value = defaults.integer(forKey: reliabilityAskCountKey)
        XCTAssertEqual(value, expected, file: file, line: line)
    }

}
