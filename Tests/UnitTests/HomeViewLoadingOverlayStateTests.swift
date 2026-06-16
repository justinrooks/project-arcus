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
                isRefreshInFlight: false,
                hasProjection: false
            )
        )
        #expect(
            HomeView.showsBootstrapLoading(
                readinessState: .loadingLocalData,
                isRefreshInFlight: false,
                hasProjection: true
            ) == false
        )
        #expect(
            HomeView.showsBootstrapLoading(
                readinessState: .locationUnavailable,
                isRefreshInFlight: false,
                hasProjection: false
            ) == false
        )
    }

    @Test("bootstrap loading remains visible with no cache during active refresh even when readiness is ready")
    func bootstrapLoading_noCacheActiveRefresh() {
        #expect(
            HomeView.showsBootstrapLoading(
                readinessState: .ready,
                isRefreshInFlight: true,
                hasProjection: false
            )
        )
    }

    @Test("bootstrap loading hides when no cache is present but readiness is ready and refresh is idle")
    func bootstrapLoading_noCacheReadyIdle() {
        #expect(
            HomeView.showsBootstrapLoading(
                readinessState: .ready,
                isRefreshInFlight: false,
                hasProjection: false
            ) == false
        )
    }

    @Test("bootstrap loading stays hidden while cached projection is available during active refresh")
    func bootstrapLoading_cacheActiveRefresh() {
        #expect(
            HomeView.showsBootstrapLoading(
                readinessState: .loadingLocalData,
                isRefreshInFlight: true,
                hasProjection: true
            ) == false
        )
    }

    @Test("summary prefers pipeline risk values once current context resolves in pipeline")
    func summaryValue_prefersPipelineWhenContextResolved() {
        let selected = HomeView.preferredSummaryValue(
            projectionValue: StormRiskLevel.slight,
            pipelineValue: StormRiskLevel.enhanced,
            prefersPipelineValue: true
        )
        #expect(selected == .enhanced)
    }

    @Test("summary falls back to projection values when pipeline has no value")
    func summaryValue_fallsBackToProjectionWhenPipelineMissing() {
        let selected = HomeView.preferredSummaryValue(
            projectionValue: SevereWeatherThreat.tornado(probability: 0.10),
            pipelineValue: nil,
            prefersPipelineValue: true
        )
        #expect(selected == .tornado(probability: 0.10))
    }

    @Test("summary prefers projection values when pipeline is not authoritative")
    func summaryValue_prefersProjectionWhenPipelineNotAuthoritative() {
        let selected = HomeView.preferredSummaryValue(
            projectionValue: FireRiskLevel.critical,
            pipelineValue: FireRiskLevel.clear,
            prefersPipelineValue: false
        )
        #expect(selected == .critical)
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
    @Test("display states map to presentation states")
    func localAlertsPresentationState_mapsDisplayStates() {
        #expect(
            LocalAlertsDisplayState.noCacheResolving.presentationState == .loading
        )
        #expect(
            LocalAlertsDisplayState.current(content: .empty, source: .live).presentationState == .empty
        )
        #expect(
            LocalAlertsDisplayState.current(content: .populated, source: .cached).presentationState == .alerts
        )
        #expect(
            LocalAlertsDisplayState.unavailable(reason: .locationUnavailable).presentationState == .unavailable
        )
    }

    @Test("loading local alerts do not receive whole-card resolving treatment")
    func localAlertsResolvingTreatment_suppressesLoadingCardOpacity() {
        var resolutionState = SummaryResolutionState()
        resolutionState.begin(task: .alerts, sections: [.alerts])

        #expect(
            SummaryView.appliesLocalAlertsResolving(
                presentationState: .loading,
                resolutionState: resolutionState,
                showsOfflineToken: false
            ) == false
        )
    }

    @Test("active or empty local alerts keep whole-card resolving treatment during refresh")
    func localAlertsResolvingTreatment_preservesSettledCardOpacity() {
        var resolutionState = SummaryResolutionState()
        resolutionState.begin(task: .alerts, sections: [.alerts])

        #expect(
            SummaryView.appliesLocalAlertsResolving(
                presentationState: .alerts,
                resolutionState: resolutionState,
                showsOfflineToken: false
            )
        )
        #expect(
            SummaryView.appliesLocalAlertsResolving(
                presentationState: .empty,
                resolutionState: resolutionState,
                showsOfflineToken: false
            )
        )
    }

    @Test("local alerts resolving treatment stays off when alerts are not resolving or offline")
    func localAlertsResolvingTreatment_requiresResolvingOnlineAlerts() {
        var resolutionState = SummaryResolutionState()
        resolutionState.begin(task: .alerts, sections: [.alerts])

        #expect(
            SummaryView.appliesLocalAlertsResolving(
                presentationState: .alerts,
                resolutionState: SummaryResolutionState(),
                showsOfflineToken: false
            ) == false
        )
        #expect(
            SummaryView.appliesLocalAlertsResolving(
                presentationState: .alerts,
                resolutionState: resolutionState,
                showsOfflineToken: true
            ) == false
        )
    }
}

@Suite("Local Alerts Display State")
@MainActor
struct LocalAlertsDisplayStateTests {
    private let loadedAt = Date(timeIntervalSince1970: 1_000)

    @Test("no-cache resolving stays calm")
    func noCacheResolving_staysCalm() {
        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .noCacheResolving,
                hasCachedProjection: false,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: nil,
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ) == .noCacheResolving
        )
    }

    @Test("current live empty and populated states stay distinct")
    func currentLiveStates_stayDistinct() {
        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .current,
                hasCachedProjection: false,
                isCurrentContextResolvedInPipeline: true,
                lastHotAlertsLoadAt: nil,
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ) == .current(content: .empty, source: .live)
        )
        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .current,
                hasCachedProjection: false,
                isCurrentContextResolvedInPipeline: true,
                lastHotAlertsLoadAt: nil,
                hasActiveAlerts: true,
                isLocationUnavailable: false
            ) == .current(content: .populated, source: .live)
        )
    }

    @Test("cached empty and populated states stay explicit")
    func cachedStates_stayExplicit() {
        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .current,
                hasCachedProjection: true,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: loadedAt,
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ) == .current(content: .empty, source: .cached)
        )
        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .current,
                hasCachedProjection: true,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: loadedAt,
                hasActiveAlerts: true,
                isLocationUnavailable: false
            ) == .current(content: .populated, source: .cached)
        )
    }

    @Test("cached refreshing states stay explicit while refresh is active")
    func cachedRefreshingStates_stayExplicit() {
        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .cachedRefreshing,
                hasCachedProjection: true,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: loadedAt,
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ) == .cachedRefreshing(content: .empty)
        )
        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .cachedRefreshing,
                hasCachedProjection: true,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: loadedAt,
                hasActiveAlerts: true,
                isLocationUnavailable: false
            ) == .cachedRefreshing(content: .populated)
        )
    }

    @Test("offline stale and degraded states retain cached content")
    func staleOrDegradedStates_retainCachedContent() {
        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .degraded,
                hasCachedProjection: true,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: loadedAt,
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ) == .staleOrDegraded(content: .empty)
        )
        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .staleRefreshing,
                hasCachedProjection: true,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: loadedAt,
                hasActiveAlerts: true,
                isLocationUnavailable: false
            ) == .staleOrDegraded(content: .populated)
        )
    }

    @Test("location unavailable and true unavailable states stay distinct")
    func unavailableStates_stayDistinct() {
        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .current,
                hasCachedProjection: false,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: nil,
                hasActiveAlerts: false,
                isLocationUnavailable: true
            ) == .unavailable(reason: .locationUnavailable)
        )
        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .unavailable,
                hasCachedProjection: false,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: nil,
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ) == .unavailable(reason: .noUsefulAlertState)
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

@Suite("SummaryView Risk Placeholder Presentation")
@MainActor
struct SummaryViewRiskPlaceholderPresentationTests {
    @Test("nil risk shows resolving placeholder only during no-cache resolving")
    func riskPlaceholder_nilRiskWhileNoCacheResolving() {
        #expect(
            SummaryView.showsRiskResolvingPlaceholder(
                hasRiskValue: false,
                todayContentState: .noCacheResolving,
                showsOfflineToken: false
            )
        )
    }

    @Test("nil risk stays hidden during cached refreshes")
    func riskPlaceholder_nilRiskDuringCachedRefresh() {
        #expect(
            SummaryView.showsRiskResolvingPlaceholder(
                hasRiskValue: false,
                todayContentState: .cachedRefreshing,
                showsOfflineToken: false,
            ) == false
        )
    }

    @Test("nil risk does not show resolving placeholder after completed local data attempt")
    func riskPlaceholder_nilRiskWhenReadyAfterCompletedAttempt() {
        #expect(
            SummaryView.showsRiskResolvingPlaceholder(
                hasRiskValue: false,
                todayContentState: .current,
                showsOfflineToken: false
            ) == false
        )
    }

    @Test("offline bypasses resolving placeholder behavior")
    func riskPlaceholder_offlineBypassesResolvingPlaceholder() {
        #expect(
            SummaryView.showsRiskResolvingPlaceholder(
                hasRiskValue: false,
                todayContentState: .noCacheResolving,
                showsOfflineToken: true
            ) == false
        )
    }
}

@Suite("Summary Content Presentation State")
@MainActor
struct SummaryContentPresentationStateTests {
    @Test("online content stays current")
    func presentationState_onlineContentIsCurrent() {
        #expect(
            SummaryContentPresentationState.from(
                isOffline: false,
                hasContent: true,
                isResolving: false
            ) == .current
        )
    }

    @Test("offline content becomes stale")
    func presentationState_offlineContentIsStale() {
        #expect(
            SummaryContentPresentationState.from(
                isOffline: true,
                hasContent: true,
                isResolving: false
            ) == .stale
        )
    }

    @Test("resolving content remains resolving while online and empty")
    func presentationState_resolvingContentIsResolving() {
        #expect(
            SummaryContentPresentationState.from(
                isOffline: false,
                hasContent: false,
                isResolving: true
            ) == .resolving
        )
    }

    @Test("offline without content is unavailable")
    func presentationState_offlineWithoutContentIsUnavailable() {
        #expect(
            SummaryContentPresentationState.from(
                isOffline: true,
                hasContent: false,
                isResolving: true
            ) == .unavailable
        )
    }

    @Test("confirmed empty beats unavailable when the latest successful result is empty")
    func presentationState_confirmedEmptyWins() {
        #expect(
            SummaryContentPresentationState.from(
                isOffline: false,
                hasContent: false,
                isResolving: false,
                isConfirmedEmpty: true
            ) == .confirmedEmpty
        )
    }
}

@Suite("Today Content State")
@MainActor
struct TodayContentStateTests {
    @Test("cached refreshing exposes the calm page cue and suppresses section loading branches")
    func cachedRefreshing_exposesCalmCueAndSuppressesSectionLoadingBranches() {
        #expect(TodayContentState.cachedRefreshing.showsCalmUpdatingCue)
        #expect(TodayContentState.cachedRefreshing.allowsSectionResolvingTreatment == false)
        #expect(TodayContentState.cachedRefreshing.suppressesRoutineRefreshMotion)
        #expect(TodayContentState.noCacheResolving.suppressesRoutineRefreshMotion == false)

        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .cachedRefreshing,
                hasCachedProjection: true,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: Date(timeIntervalSince1970: 1_000),
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ).presentationState == .empty
        )

        #expect(
            SummaryAwarenessPrimaryState.resolve(
                stormRisk: nil,
                severeRisk: nil,
                fireRisk: nil,
                alerts: [],
                todayContentState: .cachedRefreshing,
                isStormRiskResolving: true,
                isSevereRiskResolving: true,
                isFireRiskResolving: true,
                isOffline: false
            ) == .quiet
        )

        #expect(
            OutlookSummaryCard.outlookSummaryText(
                outlook: nil,
                todayContentState: .cachedRefreshing,
                isLoading: false,
                isPending: true
            ) == "Outlook details will appear here when available."
        )
    }

    @Test("no cache while resolving maps to the resolving state")
    func noCacheResolving_mapsToResolvingState() {
        #expect(
            TodayContentState.from(
                readinessState: .loadingLocalData,
                hasCachedContent: false,
                hasLiveContent: false,
                isRefreshing: false,
                isOffline: false
            ) == .noCacheResolving
        )
    }

    @Test("cached content refreshes while online")
    func cachedContentRefreshing_mapsToCachedRefreshingState() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: true,
                isOffline: false
            ) == .cachedRefreshing
        )
    }

    @Test("cached content remains current while idle and online")
    func cachedContentIdle_mapsToCurrentState() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: false,
                isOffline: false
            ) == .current
        )
    }

    @Test("live fallback content without cache is still current when idle")
    func liveFallbackContentIdle_mapsToCurrentState() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: false,
                hasLiveContent: true,
                isRefreshing: false,
                isOffline: false
            ) == .current
        )
    }

    @Test("cached content becomes stale while refreshing offline")
    func cachedContentRefreshingOffline_mapsToStaleRefreshingState() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: true,
                isOffline: true
            ) == .staleRefreshing
        )
    }

    @Test("cached content becomes degraded while offline and idle")
    func cachedContentOfflineIdle_mapsToDegradedState() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: false,
                isOffline: true
            ) == .degraded
        )
    }

    @Test("stale refreshing keeps cached content visible instead of collapsing to unavailable")
    func staleRefreshing_keepsCachedContentVisible() {
        #expect(TodayContentState.staleRefreshing.showsCalmUpdatingCue)
        #expect(TodayContentState.staleRefreshing.showsResolvingSurface == false)
        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .staleRefreshing,
                hasCachedProjection: true,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: Date(timeIntervalSince1970: 1_000),
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ).presentationState == .empty
        )
    }

    @Test("no cache and no content maps to unavailable")
    func noCacheNoContent_mapsToUnavailableState() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: false,
                hasLiveContent: false,
                isRefreshing: false,
                isOffline: false
            ) == .unavailable
        )
    }
}

@Suite("HomeView Outlook Display")
@MainActor
struct HomeViewOutlookDisplayTests {
    @Test("cached outlooks stay visible when a fresh snapshot returns no outlooks")
    func cachedOutlooks_stayVisibleWhenLiveResultsAreEmpty() {
        let cachedOutlooks = [
            makeOutlook(title: "Cached Outlook A"),
            makeOutlook(title: "Cached Outlook B")
        ]

        #expect(
            HomeView.preferredOutlooks(
                cachedOutlooks: cachedOutlooks,
                liveOutlooks: []
            ) == cachedOutlooks
        )
        #expect(
            HomeView.preferredOutlook(
                cachedOutlook: cachedOutlooks.first,
                liveOutlooks: [],
                liveOutlook: nil
            ) == cachedOutlooks.first
        )
    }

    private func makeOutlook(title: String) -> ConvectiveOutlookDTO {
        guard let url = URL(string: "https://www.weather.gov") else {
            preconditionFailure("Invalid outlook URL")
        }

        return ConvectiveOutlookDTO(
            title: title,
            link: url,
            published: Date(timeIntervalSince1970: 1_000),
            summary: "Summary for \(title)",
            fullText: "Full text for \(title)",
            day: 1,
            riskLevel: "SLGT",
            issued: Date(timeIntervalSince1970: 900),
            validUntil: Date(timeIntervalSince1970: 2_000)
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
        #expect(state.primaryActiveMessage == "Bringing in local alerts…")
        #expect(state.isResolving(.alerts))
    }

    @Test("finishing one section keeps the provider active for remaining work")
    func finish_keepsProviderActiveUntilAllSectionsResolve() {
        var state = SummaryResolutionState()

        state.begin(task: .stormRisk, sections: [.stormRisk, .severeRisk])
        state.finish(task: .stormRisk, resolvedSections: [.stormRisk])

        #expect(state.isRefreshing)
        #expect(state.activeMessages == ["Getting storm risk…"])
        #expect(state.primaryActiveMessage == "Getting storm risk…")
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
        #expect(state.recentCompletedMessage == "Updated conditions")
    }

    @Test("reset clears active tasks and sections")
    func reset_clearsTrackedState() {
        var state = SummaryResolutionState()

        state.begin(task: .location, sections: [.conditions])
        state.reset()

        #expect(state.isRefreshing == false)
        #expect(state.activeMessages.isEmpty)
        #expect(state.primaryActiveMessage == nil)
        #expect(state.isResolving(.conditions) == false)
    }

    @Test("finish all clears every active task and section")
    func finishAll_clearsEveryActiveTaskAndSection() {
        var state = SummaryResolutionState()

        state.begin(task: .weather, sections: [.conditions, .atmosphere])
        state.begin(task: .alerts, sections: [.alerts])
        state.finishAll(completedTask: .finalizing)

        #expect(state.isRefreshing == false)
        #expect(state.activeMessages.isEmpty)
        #expect(state.primaryActiveMessage == nil)
        for section in SummarySection.resolveForwardSections {
            #expect(state.isResolving(section) == false)
        }
        #expect(state.recentCompletedMessage == "Updated conditions")
    }

    @Test("primary active message prefers location readiness over other active tasks")
    func primaryActiveMessage_prioritizesLocationTask() {
        var state = SummaryResolutionState()

        state.begin(task: .alerts, sections: [.alerts])
        state.begin(task: .weather, sections: [.conditions])
        state.begin(task: .location, sections: [.conditions])

        #expect(state.primaryActiveMessage == "Getting your conditions ready…")
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

@Suite("Today Visible Weather State")
struct TodayVisibleWeatherStateTests {
    @Test("keeps displayed weather during refresh when location identity is unchanged")
    func keepsDisplayedWeather_sameIdentityRefreshing() {
        let weather = makeWeather()
        let identity = makeIdentity(latitude: 39.7392, longitude: -104.9903, placemark: "Denver, CO")

        let resolved = TodayVisibleWeatherState.resolve(
            liveWeather: nil,
            displayedWeather: weather,
            isRefreshing: true,
            displayedWeatherLocationIdentity: identity,
            weatherLocationIdentity: identity
        )

        #expect(resolved.weather == weather)
        #expect(resolved.locationIdentity == identity)
    }

    @Test("clears displayed weather during refresh when location identity changes")
    func clearsDisplayedWeather_changedIdentityRefreshing() {
        let weather = makeWeather()
        let previousIdentity = makeIdentity(latitude: 39.7392, longitude: -104.9903, placemark: "Denver, CO")
        let newIdentity = makeIdentity(latitude: 34.0522, longitude: -118.2437, placemark: "Los Angeles, CA")

        let resolved = TodayVisibleWeatherState.resolve(
            liveWeather: nil,
            displayedWeather: weather,
            isRefreshing: true,
            displayedWeatherLocationIdentity: previousIdentity,
            weatherLocationIdentity: newIdentity
        )

        #expect(resolved.weather == nil)
        #expect(resolved.locationIdentity == nil)
    }

    @Test("clears displayed weather when refresh is inactive even if identity matches")
    func clearsDisplayedWeather_sameIdentityNotRefreshing() {
        let weather = makeWeather()
        let identity = makeIdentity(latitude: 39.7392, longitude: -104.9903, placemark: "Denver, CO")

        let resolved = TodayVisibleWeatherState.resolve(
            liveWeather: nil,
            displayedWeather: weather,
            isRefreshing: false,
            displayedWeatherLocationIdentity: identity,
            weatherLocationIdentity: identity
        )

        #expect(resolved.weather == nil)
        #expect(resolved.locationIdentity == nil)
    }

    @Test("prefers live weather and current location identity")
    func prefersLiveWeatherAndCurrentIdentity() {
        let liveWeather = makeWeather(temperatureF: 64)
        let previousWeather = makeWeather(temperatureF: 72)
        let previousIdentity = makeIdentity(latitude: 39.7392, longitude: -104.9903, placemark: "Denver, CO")
        let currentIdentity = makeIdentity(latitude: 34.0522, longitude: -118.2437, placemark: "Los Angeles, CA")

        let resolved = TodayVisibleWeatherState.resolve(
            liveWeather: liveWeather,
            displayedWeather: previousWeather,
            isRefreshing: true,
            displayedWeatherLocationIdentity: previousIdentity,
            weatherLocationIdentity: currentIdentity
        )

        #expect(resolved.weather == liveWeather)
        #expect(resolved.locationIdentity == currentIdentity)
    }

    @Test("rendered weather clears immediately when location identity changes during refresh")
    func renderedWeather_clearsImmediatelyOnIdentityChange() {
        let retainedWeather = makeWeather()
        let oldIdentity = makeIdentity(latitude: 39.7392, longitude: -104.9903, placemark: "Denver, CO")
        let newIdentity = makeIdentity(latitude: 47.6062, longitude: -122.3321, placemark: "Seattle, WA")

        let rendered = TodayVisibleWeatherState.resolve(
            liveWeather: nil,
            displayedWeather: retainedWeather,
            isRefreshing: true,
            displayedWeatherLocationIdentity: oldIdentity,
            weatherLocationIdentity: newIdentity
        )

        #expect(rendered.weather == nil)
    }

    private func makeIdentity(latitude: Double, longitude: Double, placemark: String) -> SummaryWeatherLocationIdentity {
        SummaryWeatherLocationIdentity(
            snapshot: .init(
                coordinates: .init(latitude: latitude, longitude: longitude),
                timestamp: .now,
                accuracy: 20,
                placemarkSummary: placemark,
                h3Cell: nil
            )
        )
    }

    private func makeWeather(temperatureF: Double = 72) -> SummaryWeather {
        SummaryWeather(
            temperature: Measurement(value: temperatureF, unit: .fahrenheit),
            symbolName: "sun.max.fill",
            conditionText: "Clear",
            asOf: .now,
            dewPoint: Measurement(value: 50, unit: .fahrenheit),
            humidity: 0.35,
            windSpeed: Measurement(value: 8, unit: .milesPerHour),
            windGust: nil,
            windDirection: "NW",
            pressure: Measurement(value: 29.92, unit: .inchesOfMercury),
            pressureTrend: "steady"
        )
    }
}
