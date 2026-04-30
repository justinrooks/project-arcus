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

    @Test("foreground refresh triggers map to the unified ingestion triggers")
    func refreshTrigger_mapsToUnifiedIngestionTrigger() {
        #expect(HomeView.RefreshTrigger.sceneActive.ingestionTrigger == .foregroundActivate)
        #expect(HomeView.RefreshTrigger.manual.ingestionTrigger == .manualRefresh)
        #expect(HomeView.RefreshTrigger.contextChanged.ingestionTrigger == .foregroundLocationChange)
        #expect(HomeView.RefreshTrigger.timer.ingestionTrigger == .sessionTick)
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
                hasResolvedLocalData: false,
                stormRisk: nil,
                severeRisk: nil,
                fireRisk: nil
            ) == .loadingLocation
        )
        #expect(
            HomeView.readinessState(
                startupState: .acquiringLocation,
                hasContext: false,
                hasResolvedLocalData: false,
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
                hasResolvedLocalData: false,
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
                hasResolvedLocalData: false,
                stormRisk: .slight,
                severeRisk: nil,
                fireRisk: .elevated
            ) == .loadingLocalData
        )
    }

    @Test("maps completed local data attempt with missing risks into ready")
    func readinessState_mapsCompletedAttemptWithMissingRiskData() {
        #expect(
            HomeView.readinessState(
                startupState: .ready,
                hasContext: true,
                hasResolvedLocalData: true,
                stormRisk: nil,
                severeRisk: nil,
                fireRisk: nil
            ) == .ready
        )
    }

    @Test("maps failed startup into location unavailable readiness")
    func readinessState_mapsFailure() {
        #expect(
            HomeView.readinessState(
                startupState: .failed("location-unavailable"),
                hasContext: false,
                hasResolvedLocalData: false,
                stormRisk: nil,
                severeRisk: nil,
                fireRisk: nil
            ) == .locationUnavailable
        )
    }
}

@Suite("HomeView Projection Launch")
@MainActor
struct HomeViewProjectionLaunchTests {
    @Test("cached launch prefers the projection for the current resolved context")
    func cachedLaunch_prefersCurrentContextProjection() {
        let currentContext = makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214")
        let matching = makeProjectionRecord(
            context: currentContext,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let newerFallback = makeProjectionRecord(
            context: makeContext(h3Cell: 222, countyCode: "COC001", fireZone: "COZ200"),
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let selected = HomeView.selectProjection(
            from: [newerFallback, matching],
            currentContext: currentContext
        )

        #expect(selected == matching)
    }

    @Test("launch falls back to the newest cached projection while context is still resolving")
    func cachedLaunch_fallsBackToLatestProjectionWhileContextUnavailable() {
        let older = makeProjectionRecord(
            context: makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214"),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = makeProjectionRecord(
            context: makeContext(h3Cell: 222, countyCode: "COC001", fireZone: "COZ200"),
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let selected = HomeView.selectProjection(
            from: [older, newer],
            currentContext: nil
        )

        #expect(selected == newer)
    }

    @Test("bootstrap loading stays visible until a cached projection exists")
    func bootstrapLoading_requiresCachedProjection() {
        #expect(
            HomeView.showsBootstrapLoading(
                readinessState: .loadingLocalData,
                resolutionState: SummaryResolutionState(),
                hasProjection: false
            )
        )
        #expect(
            HomeView.showsBootstrapLoading(
                readinessState: .loadingLocalData,
                resolutionState: SummaryResolutionState(),
                hasProjection: true
            ) == false
        )
        #expect(
            HomeView.showsBootstrapLoading(
                readinessState: .locationUnavailable,
                resolutionState: SummaryResolutionState(),
                hasProjection: false
            ) == false
        )
    }

    @Test("bootstrap loading remains visible with no cache during active refresh even when readiness is ready")
    func bootstrapLoading_noCacheActiveRefresh() {
        var resolutionState = SummaryResolutionState()
        resolutionState.begin(task: .weather, sections: [.conditions])

        #expect(
            HomeView.showsBootstrapLoading(
                readinessState: .ready,
                resolutionState: resolutionState,
                hasProjection: false
            )
        )
    }

    @Test("bootstrap loading hides when no cache is present but readiness is ready and refresh is idle")
    func bootstrapLoading_noCacheReadyIdle() {
        #expect(
            HomeView.showsBootstrapLoading(
                readinessState: .ready,
                resolutionState: SummaryResolutionState(),
                hasProjection: false
            ) == false
        )
    }

    @Test("bootstrap loading stays hidden while cached projection is available during active refresh")
    func bootstrapLoading_cacheActiveRefresh() {
        var resolutionState = SummaryResolutionState()
        resolutionState.begin(task: .alerts, sections: [.alerts])

        #expect(
            HomeView.showsBootstrapLoading(
                readinessState: .loadingLocalData,
                resolutionState: resolutionState,
                hasProjection: true
            ) == false
        )
    }

    private func makeContext(
        h3Cell: Int64,
        countyCode: String,
        fireZone: String
    ) -> LocationContext {
        let snapshot = LocationSnapshot(
            coordinates: .init(latitude: 39.75, longitude: -104.44),
            timestamp: Date(timeIntervalSince1970: 100),
            accuracy: 25,
            placemarkSummary: "Bennett, CO",
            h3Cell: h3Cell
        )
        let grid = GridPointSnapshot(
            nwsId: "BOU/10,20",
            latitude: 39.75,
            longitude: -104.44,
            gridId: "BOU",
            gridX: 10,
            gridY: 20,
            forecastURL: nil,
            forecastHourlyURL: nil,
            forecastGridDataURL: nil,
            observationStationsURL: nil,
            city: "Bennett",
            state: "CO",
            timeZoneId: "America/Denver",
            radarStationId: nil,
            forecastZone: "COZ038",
            countyCode: countyCode,
            fireZone: fireZone,
            countyLabel: "Arapahoe",
            fireZoneLabel: "Front Range"
        )
        return LocationContext(snapshot: snapshot, h3Cell: h3Cell, grid: grid)
    }

    private func makeProjectionRecord(
        context: LocationContext,
        updatedAt: Date
    ) -> HomeProjectionRecord {
        HomeProjectionRecord(
            id: UUID(),
            projectionKey: HomeProjection.projectionKey(for: context),
            latitude: context.snapshot.coordinates.latitude,
            longitude: context.snapshot.coordinates.longitude,
            h3Cell: context.h3Cell,
            countyCode: context.grid.countyCode ?? "",
            forecastZone: context.grid.forecastZone,
            fireZone: context.grid.fireZone ?? "",
            placemarkSummary: context.snapshot.placemarkSummary,
            timeZoneId: context.grid.timeZoneId,
            locationTimestamp: context.snapshot.timestamp,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            lastViewedAt: updatedAt,
            weather: nil,
            stormRisk: nil,
            severeRisk: nil,
            fireRisk: nil,
            activeAlerts: [],
            activeMesos: [],
            lastHotAlertsLoadAt: nil,
            lastSlowProductsLoadAt: nil,
            lastWeatherLoadAt: nil
        )
    }
}

@Suite("SummaryView Local Alerts")
@MainActor
struct SummaryViewLocalAlertsTests {
    @Test("shows empty state when no local alerts are available after context resolution")
    func localAlertsPresentationState_showsEmptyStateWithoutAlerts() {
        #expect(
            SummaryView.localAlertsPresentationState(
                readinessState: .loadingLocalData,
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ) == .empty
        )
        #expect(
            SummaryView.localAlertsPresentationState(
                readinessState: .ready,
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ) == .empty
        )
    }

    @Test("keeps placeholder only while location context is still loading")
    func localAlertsPresentationState_limitsPlaceholderToLocationResolution() {
        #expect(
            SummaryView.localAlertsPresentationState(
                readinessState: .loadingLocation,
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ) == .loading
        )
        #expect(
            SummaryView.localAlertsPresentationState(
                readinessState: .resolvingLocalContext,
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ) == .loading
        )
    }

    @Test("location unavailable always wins local alerts presentation")
    func localAlertsPresentationState_locationUnavailableWins() {
        #expect(
            SummaryView.localAlertsPresentationState(
                readinessState: .ready,
                hasActiveAlerts: false,
                isLocationUnavailable: true
            ) == .unavailable
        )
    }

    @Test("active alerts are shown even while readiness is loading")
    func localAlertsPresentationState_activeAlertsWhileLoading() {
        #expect(
            SummaryView.localAlertsPresentationState(
                readinessState: .loadingLocation,
                hasActiveAlerts: true,
                isLocationUnavailable: false
            ) == .alerts
        )
        #expect(
            SummaryView.localAlertsPresentationState(
                readinessState: .resolvingLocalContext,
                hasActiveAlerts: true,
                isLocationUnavailable: false
            ) == .alerts
        )
    }

    @Test("empty local alerts state is used after local data loading completes")
    func localAlertsPresentationState_emptyAfterLocalDataLoad() {
        #expect(
            SummaryView.localAlertsPresentationState(
                readinessState: .loadingLocalData,
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ) == .empty
        )
    }
}

@Suite("SummaryView Empty Resolving")
@MainActor
struct SummaryViewEmptyResolvingTests {
    @Test("no content with active refresh shows full-screen resolving")
    func showsEmptyResolving_noContentActiveRefresh() {
        var resolutionState = SummaryResolutionState()
        resolutionState.begin(task: .stormRisk, sections: [.stormRisk])

        #expect(
            SummaryView.showsEmptyResolving(
                readinessState: .ready,
                resolutionState: resolutionState,
                hasMeaningfulContent: false,
                isLocationUnavailable: false
            )
        )
    }

    @Test("no content while loading local data shows full-screen resolving")
    func showsEmptyResolving_noContentLoadingLocalData() {
        #expect(
            SummaryView.showsEmptyResolving(
                readinessState: .loadingLocalData,
                resolutionState: SummaryResolutionState(),
                hasMeaningfulContent: false,
                isLocationUnavailable: false
            )
        )
    }

    @Test("meaningful content suppresses full-screen resolving even during refresh")
    func showsEmptyResolving_contentDuringRefresh() {
        var resolutionState = SummaryResolutionState()
        resolutionState.begin(task: .alerts, sections: [.alerts])

        #expect(
            SummaryView.showsEmptyResolving(
                readinessState: .loadingLocalData,
                resolutionState: resolutionState,
                hasMeaningfulContent: true,
                isLocationUnavailable: false
            ) == false
        )
    }

    @Test("location unavailable suppresses full-screen resolving")
    func showsEmptyResolving_locationUnavailable() {
        #expect(
            SummaryView.showsEmptyResolving(
                readinessState: .locationUnavailable,
                resolutionState: SummaryResolutionState(),
                hasMeaningfulContent: false,
                isLocationUnavailable: true
            ) == false
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
