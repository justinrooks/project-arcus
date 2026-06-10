# Notification Preference And Authorization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate stored notification preferences from iOS notification authorization in Settings without changing delivery or sync contracts.

**Architecture:** Add a small, deterministic helper that derives effective notification availability and recovery copy from `UNAuthorizationStatus` plus the stored preference booleans. Keep `SettingsView` as the UI surface, but move authorization-dependent presentation into the helper so the view can show preserved preferences, blocked-state messaging, and an `Open Settings` action without mutating stored choices.

**Tech Stack:** Swift 6, SwiftUI, UserNotifications, Swift Testing

---

### Task 1: Add deterministic notification preference state

**Files:**
- Modify: `Sources/Features/Settings/SettingsView.swift`
- Test: `Tests/UnitTests/RemoteNotificationRegistrarTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test("notification preferences remain stored when authorization is denied")
func notificationPreferenceState_preservesStoredPreferencesWhenDenied() {
    let state = NotificationPreferenceState(
        authorizationStatus: .denied,
        morningSummariesEnabled: true,
        mesoNotificationsEnabled: true,
        serverNotificationsEnabled: true
    )

    #expect(state.effectiveMorningSummariesEnabled == false)
    #expect(state.effectiveMesoNotificationsEnabled == false)
    #expect(state.effectiveServerNotificationsEnabled == false)
    #expect(state.recoveryActionTitle == "Open Settings")
    #expect(state.systemAvailabilityCopy.contains("preserved"))
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter NotificationPreferenceStateTests`
Expected: fail because `NotificationPreferenceState` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
struct NotificationPreferenceState {
    let authorizationStatus: UNAuthorizationStatus
    let morningSummariesEnabled: Bool
    let mesoNotificationsEnabled: Bool
    let serverNotificationsEnabled: Bool

    var effectiveMorningSummariesEnabled: Bool { morningSummariesEnabled && authorizationStatus.allowsNotificationDelivery }
    var effectiveMesoNotificationsEnabled: Bool { mesoNotificationsEnabled && authorizationStatus.allowsNotificationDelivery }
    var effectiveServerNotificationsEnabled: Bool { serverNotificationsEnabled && authorizationStatus.allowsNotificationDelivery }
    var recoveryActionTitle: String? { authorizationStatus.recoveryActionTitle }
    var systemAvailabilityCopy: String { authorizationStatus.systemAvailabilityCopy }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter NotificationPreferenceStateTests`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Features/Settings/SettingsView.swift Tests/UnitTests/RemoteNotificationRegistrarTests.swift
git commit -m "Separate notification preference from authorization"
```

### Task 2: Wire Settings presentation and validate the app target

**Files:**
- Modify: `Sources/Features/Settings/SettingsView.swift`
- Modify: `Tests/UITests/SkyAwareUITests.swift`

- [ ] **Step 1: Write the failing UI assertion**

```swift
@MainActor
func testSettingsShowsNotificationRecoveryCopyWhenAuthorizationDenied() throws {
    let app = XCUIApplication()
    app.launchEnvironment["UI_TESTS_FORCE_ONBOARDING_COMPLETE"] = "1"
    app.launchEnvironment["UI_TESTS_NOTIFICATION_AUTH_MODE"] = "denied"
    app.launch()

    app.tabBars.buttons["Settings"].tap()

    XCTAssertTrue(app.staticTexts["Notifications are disabled for SkyAware in iOS Settings. Enable notifications to edit these preferences."].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["Open Settings"].exists)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareUITests/testSettingsShowsNotificationRecoveryCopyWhenAuthorizationDenied test`
Expected: fail because the UI still clears preferences and does not expose the new recovery state.

- [ ] **Step 3: Write minimal implementation**

```swift
// Keep stored values untouched when notification authorization is denied.
// Render a separate blocked-state message and Open Settings action.
```

- [ ] **Step 4: Run the focused tests and app build**

Run:
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/RemoteNotificationRegistrarTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add Sources/Features/Settings/SettingsView.swift Tests/UITests/SkyAwareUITests.swift
git commit -m "Surface notification authorization separately in Settings"
```
