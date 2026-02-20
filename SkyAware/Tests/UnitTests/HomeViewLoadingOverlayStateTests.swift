import Foundation
import Testing
@testable import SkyAware

@Suite("HomeView Loading Overlay State")
struct HomeViewLoadingOverlayStateTests {
    @Test("begin shows overlay and message")
    func begin_showsOverlayAndMessage() {
        var state = HomeView.LoadingOverlayState()

        state.begin(message: "Refreshing alerts...")

        #expect(state.activeRefreshes == 1)
        #expect(state.isVisible)
        #expect(state.displayMessage == "Refreshing alerts...")
    }

    @Test("nested begin/end keeps overlay until all refreshes complete")
    func nestedBeginEnd_keepsOverlayUntilZero() {
        var state = HomeView.LoadingOverlayState()

        state.begin(message: "Refreshing data...")
        state.begin(message: "Syncing outlooks...")
        state.end()

        #expect(state.activeRefreshes == 1)
        #expect(state.isVisible)
        #expect(state.displayMessage == "Syncing outlooks...")

        state.end()

        #expect(state.activeRefreshes == 0)
        #expect(state.isVisible == false)
        #expect(state.message == nil)
        #expect(state.displayMessage == "Refreshing data...")
    }

    @Test("setMessage updates display text while active")
    func setMessage_updatesDisplayMessage() {
        var state = HomeView.LoadingOverlayState()
        state.begin(message: "Refreshing data...")

        state.setMessage("Updating local risks...")

        #expect(state.displayMessage == "Updating local risks...")
    }

    @Test("end clamps at zero and keeps state hidden")
    func end_clampsAtZero() {
        var state = HomeView.LoadingOverlayState()

        state.end()

        #expect(state.activeRefreshes == 0)
        #expect(state.isVisible == false)
        #expect(state.message == nil)
    }
}

@Suite("Outlook Refresh Policy")
struct OutlookRefreshPolicyTests {
    private let policy = OutlookRefreshPolicy(minimumSyncInterval: 900)

    @Test("syncs when there is no previous sync")
    func syncs_withoutPreviousSync() {
        let now = Date(timeIntervalSince1970: 10_000)
        #expect(policy.shouldSync(now: now, lastSync: nil, force: false))
    }

    @Test("skips sync before minimum interval")
    func skips_beforeMinimumInterval() {
        let now = Date(timeIntervalSince1970: 10_000)
        let recent = now.addingTimeInterval(-300)
        #expect(policy.shouldSync(now: now, lastSync: recent, force: false) == false)
    }

    @Test("syncs at or beyond minimum interval")
    func syncs_atOrBeyondMinimumInterval() {
        let now = Date(timeIntervalSince1970: 10_000)
        let due = now.addingTimeInterval(-900)
        #expect(policy.shouldSync(now: now, lastSync: due, force: false))
    }

    @Test("force refresh bypasses interval guard")
    func forceBypassesIntervalGuard() {
        let now = Date(timeIntervalSince1970: 10_000)
        let recent = now.addingTimeInterval(-5)
        #expect(policy.shouldSync(now: now, lastSync: recent, force: true))
    }
}

@Suite("WeatherKit Refresh Policy")
struct WeatherKitRefreshPolicyTests {
    private let policy = WeatherKitRefreshPolicy(minimumSyncInterval: 1800)

    @Test("syncs when there is no previous sync")
    func syncs_withoutPreviousSync() {
        let now = Date(timeIntervalSince1970: 10_000)
        #expect(policy.shouldSync(now: now, lastSync: nil, force: false))
    }

    @Test("skips sync before minimum interval")
    func skips_beforeMinimumInterval() {
        let now = Date(timeIntervalSince1970: 10_000)
        let recent = now.addingTimeInterval(-300)
        #expect(policy.shouldSync(now: now, lastSync: recent, force: false) == false)
    }

    @Test("syncs at or beyond minimum interval")
    func syncs_atOrBeyondMinimumInterval() {
        let now = Date(timeIntervalSince1970: 10_000)
        let due = now.addingTimeInterval(-1800)
        #expect(policy.shouldSync(now: now, lastSync: due, force: false))
    }

    @Test("force refresh bypasses interval guard")
    func forceBypassesIntervalGuard() {
        let now = Date(timeIntervalSince1970: 10_000)
        let recent = now.addingTimeInterval(-5)
        #expect(policy.shouldSync(now: now, lastSync: recent, force: true))
    }
}
