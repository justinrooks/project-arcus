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

    private func makeContextRefreshKey() -> LocationContext.RefreshKey {
        LocationContext.RefreshKey(
            h3Cell: 0x882681b485fffff,
            countyCode: "OKC109",
            fireZone: "OKZ025",
            gridKey: GridRefreshKey(coord: .init(latitude: 35.2226, longitude: -97.4395))
        )
    }

    @Test("context-driven refresh waits for a ready context")
    func contextDrivenRefresh_waitsForReadyContext() {
        #expect(
            HomeView.shouldRunContextDrivenRefresh(scenePhase: .active, refreshKey: nil) == false
        )
        #expect(
            HomeView.shouldRunContextDrivenRefresh(
                scenePhase: .background,
                refreshKey: makeContextRefreshKey()
            ) == false
        )
        #expect(
            HomeView.shouldRunContextDrivenRefresh(
                scenePhase: .active,
                refreshKey: makeContextRefreshKey()
            )
        )
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
