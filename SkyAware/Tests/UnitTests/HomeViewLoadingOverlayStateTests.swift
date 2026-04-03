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

@Suite("Summary Resolution State")
struct SummaryResolutionStateTests {
    @Test("begin tracks provider message and resolving sections")
    func begin_tracksProviderMessageAndSections() {
        var state = SummaryResolutionState()

        state.begin(task: .alerts, sections: [.alerts])

        #expect(state.isRefreshing)
        #expect(state.activeMessages == ["Bringing in local alerts…"])
        #expect(state.isResolving(.alerts))
    }

    @Test("finishing one section keeps the provider active for remaining work")
    func finish_keepsProviderActiveUntilAllSectionsResolve() {
        var state = SummaryResolutionState()

        state.begin(task: .stormRisk, sections: [.stormRisk, .severeRisk])
        state.finish(task: .stormRisk, resolvedSections: [.stormRisk])

        #expect(state.isRefreshing)
        #expect(state.activeMessages == ["Getting storm risk…"])
        #expect(state.isResolving(.stormRisk) == false)
        #expect(state.isResolving(.severeRisk))
    }

    @Test("finishing remaining sections clears refresh activity")
    func finish_clearsRefreshWhenTaskCompletes() {
        var state = SummaryResolutionState()

        state.begin(task: .weather, sections: [.conditions, .atmosphere])
        state.finish(task: .weather, resolvedSections: [.conditions, .atmosphere])

        #expect(state.isRefreshing == false)
        #expect(state.isResolving(.conditions) == false)
        #expect(state.isResolving(.atmosphere) == false)
        #expect(state.recentCompletedMessage == "Updating your conditions…")
    }

    @Test("reset clears active tasks and sections")
    func reset_clearsTrackedState() {
        var state = SummaryResolutionState()

        state.begin(task: .location, sections: [.conditions])
        state.reset()

        #expect(state.isRefreshing == false)
        #expect(state.activeMessages.isEmpty)
        #expect(state.isResolving(.conditions) == false)
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
