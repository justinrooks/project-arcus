//
//  SkyAwareUITests.swift
//  SkyAwareUITests
//
//  Created by Justin Rooks on 7/3/25.
//

import XCTest

final class SkyAwareUITests: XCTestCase {

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

    private func launchHomeForLocationPermissionScenario(mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_FORCE_ONBOARDING_COMPLETE"] = "1"
        app.launchEnvironment["UI_TESTS_SUPPRESS_LOCATION_RESTRICTED_SHEET"] = "1"
        app.launchEnvironment["UI_TESTS_LOCATION_AUTH_MODE"] = mode
        app.launch()
        return app
    }

}
