import Foundation
import CoreLocation
import SwiftUI
import Testing
@testable import SkyAware

@Suite("HomeView Refresh Triggers")
@MainActor
struct HomeViewRefreshTriggerTests {
    private func makeSnapshot(lat: Double, lon: Double, timestamp: TimeInterval) -> LocationSnapshot {
        LocationSnapshot(
            coordinates: .init(latitude: lat, longitude: lon),
            timestamp: Date(timeIntervalSince1970: timestamp),
            accuracy: 50,
            placemarkSummary: nil,
            h3Cell: nil
        )
    }

    @Test("scene active absorbs context changed follow-up work")
    func sceneActive_absorbsContextChanged() {
        #expect(HomeView.RefreshTrigger.sceneActive.absorbs(.contextChanged))
        #expect(HomeView.RefreshTrigger.sceneActive.absorbs(.timer))
        #expect(HomeView.RefreshTrigger.manual.absorbs(.sceneActive))
    }

    @Test("duplicate activation refresh is skipped for the same snapshot")
    func duplicateActivationRefresh_isSkippedForSameSnapshot() {
        let snapshot = makeSnapshot(lat: 39.75, lon: -104.44, timestamp: 100)
        let lastRefresh = RefreshContext(
            coordinates: snapshot.coordinates,
            refreshedAt: snapshot.timestamp
        )

        #expect(
            HomeView.shouldPerformLocationRefresh(
                lastRefreshContext: lastRefresh,
                snapshot: snapshot,
                force: false
            ) == false
        )
    }

    @Test("force refresh still bypasses duplicate suppression")
    func forceRefresh_bypassesDuplicateSuppression() {
        let snapshot = makeSnapshot(lat: 39.75, lon: -104.44, timestamp: 100)
        let lastRefresh = RefreshContext(
            coordinates: snapshot.coordinates,
            refreshedAt: snapshot.timestamp
        )

        #expect(
            HomeView.shouldPerformLocationRefresh(
                lastRefreshContext: lastRefresh,
                snapshot: snapshot,
                force: true
            )
        )
    }

    @Test("maps startup location acquisition states into loading location readiness")
    func readinessState_mapsLocationAcquisitionStates() {
        #expect(
            HomeView.readinessState(
                startupState: .idle,
                hasContext: false,
                stormRisk: nil,
                severeRisk: nil,
                fireRisk: nil
            ) == .loadingLocation
        )
        #expect(
            HomeView.readinessState(
                startupState: .acquiringLocation,
                hasContext: false,
                stormRisk: nil,
                severeRisk: nil,
                fireRisk: nil
            ) == .loadingLocation
        )
    }

    @Test("maps resolving context into local context readiness")
    func readinessState_mapsResolvingContext() {
        #expect(
            HomeView.readinessState(
                startupState: .resolvingContext,
                hasContext: false,
                stormRisk: nil,
                severeRisk: nil,
                fireRisk: nil
            ) == .resolvingLocalContext
        )
    }

    @Test("maps ready state with missing local risks into loading local data")
    func readinessState_mapsReadyWithMissingRiskData() {
        #expect(
            HomeView.readinessState(
                startupState: .ready,
                hasContext: true,
                stormRisk: .slight,
                severeRisk: nil,
                fireRisk: .elevated
            ) == .loadingLocalData
        )
    }

    @Test("maps failed startup into location unavailable readiness")
    func readinessState_mapsFailure() {
        #expect(
            HomeView.readinessState(
                startupState: .failed("location-unavailable"),
                hasContext: false,
                stormRisk: nil,
                severeRisk: nil,
                fireRisk: nil
            ) == .locationUnavailable
        )
    }
}

@Suite("Foreground Refresh Policies")
struct ForegroundRefreshPolicyTests {
    private let alertPolicy = AlertRefreshPolicy(minimumSyncInterval: 120)
    private let mapPolicy = MapProductRefreshPolicy(minimumSyncInterval: 600)

    @Test("alert policy syncs when there is no previous sync")
    func alertPolicy_syncsWithoutPreviousSync() {
        let now = Date(timeIntervalSince1970: 10_000)
        #expect(alertPolicy.shouldSync(now: now, lastSync: nil, force: false))
    }

    @Test("alert policy skips before minimum interval")
    func alertPolicy_skipsBeforeMinimumInterval() {
        let now = Date(timeIntervalSince1970: 10_000)
        let recent = now.addingTimeInterval(-30)
        #expect(alertPolicy.shouldSync(now: now, lastSync: recent, force: false) == false)
    }

    @Test("map policy skips before minimum interval")
    func mapPolicy_skipsBeforeMinimumInterval() {
        let now = Date(timeIntervalSince1970: 10_000)
        let recent = now.addingTimeInterval(-300)
        #expect(mapPolicy.shouldSync(now: now, lastSync: recent, force: false) == false)
    }

    @Test("map policy force refresh bypasses interval guard")
    func mapPolicy_forceBypassesIntervalGuard() {
        let now = Date(timeIntervalSince1970: 10_000)
        let recent = now.addingTimeInterval(-5)
        #expect(mapPolicy.shouldSync(now: now, lastSync: recent, force: true))
    }
}

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
