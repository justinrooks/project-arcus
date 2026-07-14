import Foundation
import CoreLocation
import SwiftUI
import Testing
@testable import SkyAware

@Suite("SummaryView Local Alerts")
@MainActor
struct SummaryViewLocalAlertsTests {
    private let loadedAt = Date(timeIntervalSince1970: 1_000)

    @Test("display states map to presentation states")
    func localAlertsPresentationState_mapsDisplayStates() {
        #expect(
            LocalAlertsDisplayState.noCacheResolving.presentationState == .loading
        )
        #expect(LocalAlertsDisplayState.noCacheResolving.showsLoadingCopy)
        #expect(LocalAlertsDisplayState.noCacheResolving.usesSummaryResolvingTreatment == false)
        #expect(
            LocalAlertsDisplayState.current(content: .empty, source: .live).presentationState == .empty
        )
        #expect(
            LocalAlertsDisplayState.cachedRefreshing(content: .populated).presentationState == .alerts
        )
        #expect(
            LocalAlertsDisplayState.cachedRefreshing(content: .empty).presentationState == .empty
        )
        #expect(
            LocalAlertsDisplayState.current(content: .populated, source: .cached).presentationState == .alerts
        )
        #expect(
            LocalAlertsDisplayState.unavailable(reason: .locationUnavailable).presentationState == .unavailable
        )
    }

    @Test("existing alerts stay visible when loading arrives transiently")
    func localAlerts_existingAlertsOverrideTransientLoading() {
        #expect(
            ActiveAlertSummaryView.contentState(
                for: .noCacheResolving,
                hasRenderableAlerts: true
            ) == .alerts
        )
    }

    @Test("cached populated alerts stay calm during refresh")
    func localAlerts_refreshTreatment_cachedPopulated() {
        let state = LocalAlertsDisplayState.from(
            todayContentState: .cachedRefreshing,
            hasCachedProjection: true,
            isCurrentContextResolvedInPipeline: false,
            lastHotAlertsLoadAt: loadedAt,
            hasActiveAlerts: true,
            isLocationUnavailable: false
        )

        #expect(state == .cachedRefreshing(content: .populated))
        #expect(state.usesSummaryResolvingTreatment == false)
        #expect(state.showsLoadingCopy == false)
        #expect(state.showsOfflineStatusCopy == false)
    }

    @Test("cached refreshing populated alerts never fall back to loading")
    func localAlerts_refreshTreatment_cachedRefreshingPopulatedNeverLoads() {
        let state = LocalAlertsDisplayState.from(
            todayContentState: .cachedRefreshing,
            hasCachedProjection: true,
            isCurrentContextResolvedInPipeline: false,
            lastHotAlertsLoadAt: loadedAt,
            hasActiveAlerts: true,
            isLocationUnavailable: false
        )

        #expect(state.presentationState == .alerts)
        #expect(
            ActiveAlertSummaryView.contentState(
                for: state,
                hasRenderableAlerts: true
            ) == .alerts
        )
    }

    @Test("cached refreshing populated alerts stay alerts in the card")
    func localAlerts_cardState_cachedRefreshingPopulated() {
        #expect(
            ActiveAlertSummaryView.contentState(
                for: .cachedRefreshing(content: .populated),
                hasRenderableAlerts: true
            ) == .alerts
        )
    }

    @Test("cached refreshing known empty alerts stay empty in the card")
    func localAlerts_cardState_cachedRefreshingEmpty() {
        #expect(
            ActiveAlertSummaryView.contentState(
                for: .cachedRefreshing(content: .empty),
                hasRenderableAlerts: false
            ) == .empty
        )
    }

    @Test("no-cache resolving without useful content can still show loading")
    func localAlerts_cardState_noCacheResolvingWithoutContent() {
        #expect(
            ActiveAlertSummaryView.contentState(
                for: .noCacheResolving,
                hasRenderableAlerts: false
            ) == .loading
        )
    }

    @Test("alerts-to-empty transitions keep flexible height smoothing")
    func localAlerts_heightPolicy_alertsToEmpty() {
        #expect(
            ActiveAlertSummaryView.usesFlexibleAlertHeight(
                currentState: .empty,
                isLeavingAlerts: true
            )
        )
    }

    @Test("routine cached refresh stays on the alerts height path")
    func localAlerts_heightPolicy_cachedRefreshingPopulatedStaysOnAlertsHeightPath() {
        #expect(
            ActiveAlertSummaryView.usesFlexibleAlertHeight(
                currentState: .alerts,
                isLeavingAlerts: false
            )
        )
        #expect(
            ActiveAlertSummaryView.shouldAnimateContentStateTransition(
                from: .alerts,
                to: .alerts,
                suppressesRoutineRefreshMotion: true
            ) == false
        )
    }

    @Test("loading to alerts does not animate the card branch")
    func localAlerts_animationPolicy_loadingToAlertsDoesNotAnimate() {
        #expect(
            ActiveAlertSummaryView.shouldAnimateContentStateTransition(
                from: .loading,
                to: .alerts,
                suppressesRoutineRefreshMotion: false
            ) == false
        )
    }

    @Test("empty to alerts can still animate the card branch")
    func localAlerts_animationPolicy_emptyToAlertsCanAnimate() {
        #expect(
            ActiveAlertSummaryView.shouldAnimateContentStateTransition(
                from: .empty,
                to: .alerts,
                suppressesRoutineRefreshMotion: false
            )
        )
    }

    @Test("known empty alerts stay calm during refresh")
    func localAlerts_refreshTreatment_cachedEmpty() {
        let state = LocalAlertsDisplayState.from(
            todayContentState: .cachedRefreshing,
            hasCachedProjection: true,
            isCurrentContextResolvedInPipeline: false,
            lastHotAlertsLoadAt: loadedAt,
            hasActiveAlerts: false,
            isLocationUnavailable: false
        )

        #expect(state == .cachedRefreshing(content: .empty))
        #expect(state.usesSummaryResolvingTreatment == false)
        #expect(state.showsLoadingCopy == false)
        #expect(state.showsOfflineStatusCopy == false)
        #expect(
            ActiveAlertSummaryView.contentState(
                for: state,
                hasRenderableAlerts: false
            ) == .empty
        )
    }

    @Test("no-cache resolving preserves first-load feedback")
    func localAlerts_refreshTreatment_noCacheResolving() {
        let state = LocalAlertsDisplayState.from(
            todayContentState: .noCacheResolving,
            hasCachedProjection: false,
            isCurrentContextResolvedInPipeline: false,
            lastHotAlertsLoadAt: nil,
            hasActiveAlerts: false,
            isLocationUnavailable: false
        )

        #expect(state == .noCacheResolving)
        #expect(state.usesSummaryResolvingTreatment == false)
        #expect(state.showsLoadingCopy)
        #expect(state.showsOfflineStatusCopy == false)
    }

    @Test("offline cached populated alerts stay visible without duplicate treatment")
    func localAlerts_refreshTreatment_offlineCachedPopulated() {
        let state = LocalAlertsDisplayState.from(
            todayContentState: .staleRefreshing,
            hasCachedProjection: true,
            isCurrentContextResolvedInPipeline: false,
            lastHotAlertsLoadAt: loadedAt,
            hasActiveAlerts: true,
            isLocationUnavailable: false
        )

        #expect(state == .staleOrDegraded(content: .populated))
        #expect(state.usesSummaryResolvingTreatment == false)
        #expect(state.showsLoadingCopy == false)
        #expect(state.showsOfflineStatusCopy)
    }

    @Test("offline known empty alerts stay calm without duplicate treatment")
    func localAlerts_refreshTreatment_offlineCachedEmpty() {
        let state = LocalAlertsDisplayState.from(
            todayContentState: .staleRefreshing,
            hasCachedProjection: true,
            isCurrentContextResolvedInPipeline: false,
            lastHotAlertsLoadAt: loadedAt,
            hasActiveAlerts: false,
            isLocationUnavailable: false
        )

        #expect(state == .staleOrDegraded(content: .empty))
        #expect(state.usesSummaryResolvingTreatment == false)
        #expect(state.showsLoadingCopy == false)
        #expect(state.showsOfflineStatusCopy == false)
        #expect(
            ActiveAlertSummaryView.contentState(
                for: state,
                hasRenderableAlerts: false
            ) == .empty
        )
    }

    @Test("degraded cached populated alerts stay visible without duplicate treatment")
    func localAlerts_refreshTreatment_degradedCachedPopulated() {
        let state = LocalAlertsDisplayState.from(
            todayContentState: .degraded,
            hasCachedProjection: true,
            isCurrentContextResolvedInPipeline: false,
            lastHotAlertsLoadAt: loadedAt,
            hasActiveAlerts: true,
            isLocationUnavailable: false
        )

        #expect(state == .staleOrDegraded(content: .populated))
        #expect(state.usesSummaryResolvingTreatment == false)
        #expect(state.showsLoadingCopy == false)
        #expect(state.showsOfflineStatusCopy)
    }

    @Test("degraded known empty alerts stay calm without duplicate treatment")
    func localAlerts_refreshTreatment_degradedCachedEmpty() {
        let state = LocalAlertsDisplayState.from(
            todayContentState: .degraded,
            hasCachedProjection: true,
            isCurrentContextResolvedInPipeline: false,
            lastHotAlertsLoadAt: loadedAt,
            hasActiveAlerts: false,
            isLocationUnavailable: false
        )

        #expect(state == .staleOrDegraded(content: .empty))
        #expect(state.usesSummaryResolvingTreatment == false)
        #expect(state.showsLoadingCopy == false)
        #expect(state.showsOfflineStatusCopy == false)
        #expect(
            ActiveAlertSummaryView.contentState(
                for: state,
                hasRenderableAlerts: false
            ) == .empty
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
                todayContentState: .current,
                hasCachedProjection: true,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: nil,
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ) == .unavailable(reason: .noUsefulAlertState)
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


