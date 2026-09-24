import Foundation
import CoreLocation
import SwiftUI
import SwiftData
import UIKit
import Testing
import Observation
import ArcusCore
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

@Suite("Home visible revision contract")
struct HomeVisibleRevisionTests {
    private let key = "h3:1|county:COC001|forecast:COZ001|fire:COZ201"

    @Test("repository observation promotes core only at an accepted core boundary")
    func observedRevisionPromotesAtomically() {
        let old = record(at: 100, stormRisk: .slight)
        let hotOnly = record(at: 200, acceptedWeather: false, acceptedRisks: false, acceptedAlerts: true)
        let enrichmentOnly = record(at: 300, acceptedWeather: false, acceptedRisks: false, acceptedEnrichment: true)
        let accepted = record(at: 400, stormRisk: .enhanced)

        let warm = HomeVisibleRevision.derive(previous: nil, observed: old, projectionKey: key)
        #expect(warm?.core == old)
        let alerts = HomeVisibleRevision.derive(previous: warm, observed: hotOnly, projectionKey: key)
        #expect(alerts?.core == old)
        #expect(alerts?.alerts == hotOnly)
        let enriched = HomeVisibleRevision.derive(previous: alerts, observed: enrichmentOnly, projectionKey: key)
        #expect(enriched?.core == old)
        #expect(enriched?.enrichment == enrichmentOnly)
        let promoted = HomeVisibleRevision.derive(previous: enriched, observed: accepted, projectionKey: key)
        #expect(promoted?.core == accepted)
        #expect(promoted?.stormRisk == .enhanced)
    }

    @Test("cold start, failed read, and location transition respect the visible context")
    func observedRevisionPreservesAcceptedContext() {
        let hotOnly = record(at: 100, acceptedWeather: false, acceptedRisks: false, acceptedAlerts: true)
        let accepted = record(at: 200, stormRisk: .slight)
        let otherKey = "h3:2|county:COC003|forecast:COZ002|fire:COZ202"
        let other = record(at: 300, key: otherKey, stormRisk: .enhanced)

        #expect(HomeVisibleRevision.derive(previous: nil, observed: nil, projectionKey: key) == nil)
        #expect(HomeVisibleRevision.derive(previous: nil, observed: hotOnly, projectionKey: key) == nil)
        let warm = HomeVisibleRevision.derive(previous: nil, observed: accepted, projectionKey: key)
        #expect(HomeVisibleRevision.derive(previous: warm, observed: nil, projectionKey: key) == warm)
        #expect(HomeVisibleRevision.derive(previous: warm, observed: accepted, projectionKey: otherKey) == nil)
        #expect(HomeVisibleRevision.derive(previous: warm, observed: other, projectionKey: otherKey)?.core == other)
        #expect(HomeVisibleRevision.derive(previous: nil, observed: accepted, projectionKey: accepted.projectionKey)?.core == accepted)
    }

    @Test(
        "accepted core replaces cache only after a coherent persistence acknowledgement",
        arguments: HomeVisiblePresentation.RefreshSource.allCases
    )
    func acceptedCorePromotesForEveryRefreshSource(source: HomeVisiblePresentation.RefreshSource) {
        let cached = record(at: 100, stormRisk: .slight)
        let accepted = record(at: 200)
        let attemptID = UUID()
        var state = HomeVisiblePresentation(contextKey: key)
        state.apply(.persistedFallback(cached))
        state.apply(.refreshStarted(id: attemptID, source: source, projectionKey: key))

        #expect(state.phase == .cachedRefreshing)
        #expect(state.revision?.core == cached)
        #expect(state.refreshSource == source)

        state.apply(.coreAccepted(.init(record: accepted, riskProfileChange: nil), .init(weather: .some(nil))))
        #expect(state.revision?.core == accepted)
        #expect(state.isRefreshing)
        state.apply(.refreshFinished(id: attemptID))
        #expect(state.phase == .current)
    }

    @Test("a hot alert prime cannot certify or replace the core revision")
    func hotPrimeCannotCertifyCore() {
        let cached = record(at: 100, stormRisk: .slight)
        let alertPrime = record(at: 200, acceptedAlerts: true)
        var state = HomeVisiblePresentation(contextKey: key)
        state.apply(.persistedFallback(cached))
        state.apply(.coreAccepted(
            .init(record: alertPrime, riskProfileChange: nil),
            .init(hotAlerts: (alerts: [], mesos: []))
        ))
        #expect(state.revision?.core == cached)

        state.apply(.alertsAccepted(alertPrime))
        #expect(state.revision?.core == cached)
        #expect(state.revision?.alerts == alertPrime)
        state.apply(.persistedFallback(alertPrime))
        #expect(state.revision?.core == cached)

        var noCore = HomeVisiblePresentation(contextKey: key)
        noCore.apply(.persistedFallback(record(
            at: 100,
            acceptedWeather: false,
            acceptedRisks: false,
            acceptedAlerts: true
        )))
        noCore.apply(.alertsAccepted(alertPrime))
        #expect(noCore.revision == nil)
        #expect(noCore.phase == .noCacheResolving)
    }

    @Test("a same-context attempt preserves cache through failure and rejection")
    func sameContextFailuresPreserveCache() {
        let cached = record(at: 100, stormRisk: .slight)
        let failedAttempt = UUID()
        let rejectedAttempt = UUID()
        var state = HomeVisiblePresentation(contextKey: key)
        state.apply(.persistedFallback(cached))
        state.apply(.refreshStarted(id: failedAttempt, source: .manual, projectionKey: key))
        state.apply(.failed(id: failedAttempt))
        #expect(state.phase == .failureWithCache)
        #expect(state.revision?.core == cached)

        state.apply(.refreshStarted(id: rejectedAttempt, source: .timer, projectionKey: key))
        state.apply(.rejected(id: rejectedAttempt))
        #expect(state.phase == .failureWithCache)
        #expect(state.revision?.core == cached)
    }

    @Test("location changes reject prior location content and late old-context acceptance")
    func locationChangeRejectsOldContext() {
        let old = record(at: 100, stormRisk: .slight)
        let newKey = "h3:2|county:COC003|forecast:COZ002|fire:COZ202"
        var state = HomeVisiblePresentation(contextKey: key)
        state.apply(.persistedFallback(old))
        state.apply(.contextChanged(projectionKey: newKey))
        #expect(state.revision == nil)
        #expect(state.phase == .noCacheResolving)

        state.apply(.coreAccepted(.init(record: old, riskProfileChange: nil), .init(weather: .some(nil))))
        state.apply(.persistedFallback(old))
        #expect(state.revision == nil)

        let new = record(at: 150, key: newKey, stormRisk: .slight)
        state.apply(.persistedFallback(new))
        #expect(state.revision?.core == new)
    }

    @Test("accepted empty requires all core and alert acceptance markers")
    func emptyIsDistinctFromUnloadedAndFailure() {
        var state = HomeVisiblePresentation(contextKey: key)
        #expect(state.phase == .noCacheResolving)
        state.apply(.persistedFallback(record(at: 100, acceptedWeather: true, acceptedRisks: false)))
        #expect(state.phase == .current)
        let empty = record(at: 200, acceptedWeather: true, acceptedRisks: true, acceptedAlerts: true)
        state.apply(.coreAccepted(.init(record: empty, riskProfileChange: nil), .init(weather: .some(nil))))
        #expect(state.phase == .authoritativeEmpty)
        let attemptID = UUID()
        state.apply(.refreshStarted(id: attemptID, source: .manual, projectionKey: key))
        state.apply(.failed(id: attemptID))
        #expect(state.phase == .failureWithCache)
    }

    @Test("older accepted core and fallback cannot replace a newer same-context revision")
    func olderCoreCannotReplaceNewerCore() {
        let newer = record(at: 200, stormRisk: .slight)
        let older = record(at: 100)
        var state = HomeVisiblePresentation(contextKey: key)
        state.apply(.coreAccepted(.init(record: newer, riskProfileChange: nil), .init(weather: .some(nil))))
        state.apply(.coreAccepted(.init(record: older, riskProfileChange: nil), .init(weather: .some(nil))))
        state.apply(.persistedFallback(older))
        #expect(state.revision?.core == newer)
    }

    @Test("late terminal events from an old context cannot change the current attempt")
    func lateAttemptCannotChangeNewContext() {
        let oldAttempt = UUID()
        let newAttempt = UUID()
        let newKey = "h3:2|county:COC003|forecast:COZ002|fire:COZ202"
        var state = HomeVisiblePresentation(contextKey: key)
        state.apply(.refreshStarted(id: oldAttempt, source: .foregroundActivate, projectionKey: key))
        state.apply(.contextChanged(projectionKey: newKey))
        state.apply(.refreshStarted(id: oldAttempt, source: .foregroundActivate, projectionKey: key))
        #expect(state.activeAttemptID == nil)
        state.apply(.refreshStarted(id: newAttempt, source: .manual, projectionKey: newKey))

        state.apply(.refreshFinished(id: oldAttempt))
        state.apply(.failed(id: oldAttempt))
        state.apply(.rejected(id: oldAttempt))
        state.apply(.offline(id: oldAttempt))
        #expect(state.isRefreshing)
        #expect(state.refreshSource == .manual)
        #expect(state.activeAttemptID == newAttempt)
        #expect(state.phase == .noCacheResolving)

        state.apply(.refreshFinished(id: newAttempt))
        #expect(state.isRefreshing == false)
        #expect(state.activeAttemptID == nil)
    }

    @Test("optional enrichment and alerts cannot change accepted core risk")
    func enrichmentDoesNotChangeCore() {
        let core = record(at: 100, stormRisk: .slight)
        let enriched = record(at: 200, acceptedAlerts: true, acceptedEnrichment: true)
        var state = HomeVisiblePresentation(contextKey: key)
        state.apply(.persistedFallback(core))
        state.apply(.enrichmentAccepted(enriched))
        state.apply(.alertsAccepted(enriched))
        #expect(state.revision?.stormRisk == .slight)
        #expect(state.revision?.core == core)
        #expect(state.revision?.enrichment == enriched)
    }

    @Test("offline, unavailable location, and unavailable persistence remain distinct")
    func availabilityStates() {
        let cached = record(at: 100, stormRisk: .slight)
        let attemptID = UUID()
        var state = HomeVisiblePresentation(contextKey: key)
        state.apply(.persistedFallback(cached))
        state.apply(.connectivityChanged(isOffline: true))
        #expect(state.phase == .staleOffline)
        state.apply(.connectivityChanged(isOffline: false))
        #expect(state.phase == .current)
        state.apply(.refreshStarted(id: attemptID, source: .manual, projectionKey: key))
        state.apply(.offline(id: attemptID))
        #expect(state.phase == .staleOffline)
        #expect(state.revision?.core == cached)
        let recoveryAttempt = UUID()
        state.apply(.refreshStarted(id: recoveryAttempt, source: .timer, projectionKey: key))
        state.apply(.persistenceUnavailable(projectionKey: key))
        #expect(state.phase == .persistenceUnavailable)
        #expect(state.revision?.core == cached)
        state.apply(.persistenceRecovered(projectionKey: "other-location"))
        #expect(state.phase == .persistenceUnavailable)
        state.apply(.persistenceRecovered(projectionKey: key))
        state.apply(.refreshFinished(id: recoveryAttempt))
        #expect(state.phase == .current)
        #expect(state.revision?.core == cached)
        state.apply(.locationUnavailable)
        #expect(state.phase == .locationUnavailable)
        #expect(state.revision == nil)

        var unresolved = HomeVisiblePresentation()
        unresolved.apply(.persistenceUnavailable(projectionKey: nil))
        #expect(unresolved.phase == .persistenceUnavailable)
        unresolved.apply(.persistenceRecovered(projectionKey: nil))
        #expect(unresolved.phase == .noCacheResolving)
    }

    private func record(
        at timestamp: TimeInterval,
        key projectionKey: String? = nil,
        stormRisk: StormRiskLevel? = nil,
        acceptedWeather: Bool = true,
        acceptedRisks: Bool = true,
        acceptedAlerts: Bool = false,
        acceptedEnrichment: Bool = false
    ) -> HomeProjectionRecord {
        let date = Date(timeIntervalSince1970: timestamp)
        return HomeProjectionRecord(
            id: UUID(),
            projectionKey: projectionKey ?? key,
            latitude: 39,
            longitude: -104,
            h3Cell: 1,
            countyCode: "COC001",
            forecastZone: "COZ001",
            fireZone: "COZ201",
            placemarkSummary: nil,
            timeZoneId: "America/Denver",
            locationTimestamp: date,
            createdAt: date,
            updatedAt: date,
            lastViewedAt: date,
            weather: nil,
            stormRisk: stormRisk,
            severeRisk: nil,
            fireRisk: nil,
            activeAlerts: [],
            activeMesos: [],
            lastHotAlertsLoadAt: acceptedAlerts ? date : nil,
            lastSlowProductsLoadAt: acceptedRisks ? date : nil,
            lastWeatherLoadAt: acceptedWeather ? date : nil,
            lastAirQualityLoadAt: acceptedEnrichment ? date : nil
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

    @Test("storm setup selection prefers the current projection until a matching pipeline value exists")
    func stormSetupSelection_prefersCurrentProjectionUntilMatchingPipelineExists() {
        let currentContext = makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214")
        let stormSetup = makeStormSetupDTO(h3Cell: currentContext.h3Cell, expiresAt: Date(timeIntervalSince1970: 500))
        let projection = makeProjectionRecord(
            context: currentContext,
            updatedAt: Date(timeIntervalSince1970: 100),
            stormSetup: stormSetup
        )

        let selected = HomeView.selectStormSetup(
            projection: projection,
            currentContext: currentContext,
            pipelineValue: nil,
            pipelineRefreshKey: nil,
            now: Date(timeIntervalSince1970: 200)
        )

        #expect(selected == stormSetup)
    }

    @Test("storm setup selection prefers a matching pipeline value and falls back to the projection when needed")
    func stormSetupSelection_prefersMatchingPipelineAndFallsBackToProjection() {
        let currentContext = makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214")
        let projectionStormSetup = makeStormSetupDTO(
            h3Cell: currentContext.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 500),
            summary: "projection guidance"
        )
        let pipelineStormSetup = makeStormSetupDTO(
            h3Cell: currentContext.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 600),
            summary: "pipeline guidance"
        )
        let projection = makeProjectionRecord(
            context: currentContext,
            updatedAt: Date(timeIntervalSince1970: 100),
            stormSetup: projectionStormSetup
        )

        let selectedPipeline = HomeView.selectStormSetup(
            projection: projection,
            currentContext: currentContext,
            pipelineValue: pipelineStormSetup,
            pipelineRefreshKey: currentContext.refreshKey,
            now: Date(timeIntervalSince1970: 200)
        )
        #expect(selectedPipeline == pipelineStormSetup)

        let selectedFallback = HomeView.selectStormSetup(
            projection: projection,
            currentContext: currentContext,
            pipelineValue: nil,
            pipelineRefreshKey: currentContext.refreshKey,
            now: Date(timeIntervalSince1970: 200)
        )
        #expect(selectedFallback == projectionStormSetup)
    }

    @Test("storm setup selection rejects wrong refresh keys, h3 mismatches, and expired guidance")
    func stormSetupSelection_rejectsWrongKeyH3MismatchAndExpiredGuidance() {
        let currentContext = makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214")
        let otherContext = makeContext(h3Cell: 222, countyCode: "COC001", fireZone: "COZ200")
        let validStormSetup = makeStormSetupDTO(h3Cell: currentContext.h3Cell, expiresAt: Date(timeIntervalSince1970: 500))
        let wrongH3StormSetup = makeStormSetupDTO(h3Cell: otherContext.h3Cell, expiresAt: Date(timeIntervalSince1970: 500))
        let expiredStormSetup = makeStormSetupDTO(h3Cell: currentContext.h3Cell, expiresAt: Date(timeIntervalSince1970: 150))
        let projection = makeProjectionRecord(
            context: currentContext,
            updatedAt: Date(timeIntervalSince1970: 100),
            stormSetup: validStormSetup
        )
        let expiredProjection = makeProjectionRecord(
            context: currentContext,
            updatedAt: Date(timeIntervalSince1970: 50),
            stormSetup: expiredStormSetup
        )

        #expect(
            HomeView.selectStormSetup(
                projection: projection,
                currentContext: currentContext,
                pipelineValue: validStormSetup,
                pipelineRefreshKey: otherContext.refreshKey,
                now: Date(timeIntervalSince1970: 200)
            ) == validStormSetup
        )

        #expect(
            HomeView.selectStormSetup(
                projection: projection,
                currentContext: currentContext,
                pipelineValue: wrongH3StormSetup,
                pipelineRefreshKey: currentContext.refreshKey,
                now: Date(timeIntervalSince1970: 200)
            ) == validStormSetup
        )

        #expect(
            HomeView.selectStormSetup(
                projection: expiredProjection,
                currentContext: currentContext,
                pipelineValue: expiredStormSetup,
                pipelineRefreshKey: currentContext.refreshKey,
                now: Date(timeIntervalSince1970: 150)
            ) == nil
        )

        #expect(
            HomeView.selectStormSetup(
                projection: projection,
                currentContext: currentContext,
                pipelineValue: nil,
                pipelineRefreshKey: nil,
                now: Date(timeIntervalSince1970: 200)
            ) == validStormSetup
        )

        let otherProjection = makeProjectionRecord(
            context: otherContext,
            updatedAt: Date(timeIntervalSince1970: 200),
            stormSetup: nil
        )
        #expect(
            HomeView.selectStormSetup(
                projection: otherProjection,
                currentContext: currentContext,
                pipelineValue: nil,
                pipelineRefreshKey: nil,
                now: Date(timeIntervalSince1970: 200)
            ) == nil
        )
    }

    @Test("storm setup selection uses newest startup projection safely when no context exists")
    func stormSetupSelection_usesNewestStartupProjectionWithoutContext() {
        let older = makeProjectionRecord(
            context: makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214"),
            updatedAt: Date(timeIntervalSince1970: 100),
            stormSetup: makeStormSetupDTO(h3Cell: 111, expiresAt: Date(timeIntervalSince1970: 500))
        )
        let newer = makeProjectionRecord(
            context: makeContext(h3Cell: 222, countyCode: "COC001", fireZone: "COZ200"),
            updatedAt: Date(timeIntervalSince1970: 200),
            stormSetup: makeStormSetupDTO(h3Cell: 222, expiresAt: Date(timeIntervalSince1970: 600))
        )

        let selected = HomeView.selectStormSetup(
            projection: newer,
            currentContext: nil,
            pipelineValue: nil,
            pipelineRefreshKey: nil,
            now: Date(timeIntervalSince1970: 250)
        )

        #expect(selected == newer.stormSetup)
        #expect(
            HomeView.selectStormSetup(
                projection: older,
                currentContext: nil,
                pipelineValue: nil,
                pipelineRefreshKey: nil,
                now: Date(timeIntervalSince1970: 250)
            ) == older.stormSetup
        )
    }

    @Test("location time zone resolution falls back deterministically")
    func locationTimeZoneResolution_fallsBackDeterministically() {
        let currentContext = makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214")
        let projection = makeProjectionRecord(
            context: currentContext,
            updatedAt: Date(timeIntervalSince1970: 100),
            timeZoneId: "Invalid/TimeZone"
        )
        let fallback = TimeZone(secondsFromGMT: 0)!
        let selected = HomeView.resolveLocationTimeZone(
            selectedProjection: projection,
            currentContext: currentContext,
            newestStartupProjection: nil,
            fallback: fallback
        )

        #expect(selected.identifier == currentContext.grid.timeZoneId)

        let startupProjection = makeProjectionRecord(
            context: makeContext(h3Cell: 222, countyCode: "COC001", fireZone: "COZ200"),
            updatedAt: Date(timeIntervalSince1970: 200),
            timeZoneId: "America/Chicago"
        )
        let startupSelected = HomeView.resolveLocationTimeZone(
            selectedProjection: nil,
            currentContext: nil,
            newestStartupProjection: startupProjection,
            fallback: fallback
        )
        #expect(startupSelected.identifier == "America/Chicago")

        let fallbackSelected = HomeView.resolveLocationTimeZone(
            selectedProjection: nil,
            currentContext: nil,
            newestStartupProjection: makeProjectionRecord(
                context: currentContext,
                updatedAt: Date(timeIntervalSince1970: 100),
                timeZoneId: "Invalid/TimeZone"
            ),
            fallback: fallback
        )
        #expect(fallbackSelected == fallback)
    }

    @Test("storm setup settings schedule only qualifying enablement transitions")
    func stormSetupSettings_scheduleOnlyQualifyingEnablementTransitions() {
        let preferences = StormSetupPreferences(stormSetupEnabled: false, detailedIngredientsEnabled: true)
        #expect(preferences.effectiveDetailedIngredientsEnabled == false)

        let cases: [(String, StormSetupPreferences, StormSetupPreferences, Bool, Bool, Bool, Bool)] = [
            ("Storm Setup enable with context", .init(), .init(stormSetupEnabled: true), true, false, false, true),
            (
                "Storm Setup re-enable preserves stored Detailed Ingredients",
                .init(detailedIngredientsEnabled: true),
                .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
                true,
                false,
                false,
                true
            ),
            ("Storm Setup enable without context", .init(), .init(stormSetupEnabled: true), false, false, false, false),
            ("Storm Setup disable", .init(stormSetupEnabled: true), .init(), true, false, false, false),
            ("unchanged Storm Setup", .init(stormSetupEnabled: true), .init(stormSetupEnabled: true), true, false, false, false),
            (
                "Detailed Ingredients enable with Storm Setup",
                .init(stormSetupEnabled: true),
                .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
                true,
                false,
                false,
                true
            ),
            (
                "Detailed Ingredients enable without Storm Setup",
                .init(),
                .init(detailedIngredientsEnabled: true),
                true,
                false,
                false,
                false
            ),
            (
                "Detailed Ingredients disable",
                .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
                .init(stormSetupEnabled: true),
                true,
                false,
                false,
                false
            ),
            ("preview mode", .init(), .init(stormSetupEnabled: true), true, true, false, false),
            ("static UI-test mode", .init(), .init(stormSetupEnabled: true), true, false, true, false)
        ]

        for (name, previous, current, hasContext, isPreview, isStaticTest, expected) in cases {
            #expect(
                HomeView.shouldScheduleStormSetupSettingsRefresh(
                    previousPreferences: previous,
                    currentPreferences: current,
                    hasCurrentLocationContext: hasContext,
                    isPreviewMode: isPreview,
                    isUITestStaticMode: isStaticTest
                ) == expected,
                "\\(name)"
            )
        }
    }
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
        updatedAt: Date,
        stormSetup: StormSetupDTO? = nil,
        airQuality: AirQualityCurrentResponse? = nil,
        timeZoneId: String? = nil,
        activeAlerts: [AlertDTO] = [],
        activeMesos: [MdDTO] = []
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
            timeZoneId: timeZoneId ?? context.grid.timeZoneId,
            locationTimestamp: context.snapshot.timestamp,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            lastViewedAt: updatedAt,
            weather: nil,
            stormRisk: nil,
            severeRisk: nil,
            fireRisk: nil,
            activeAlerts: activeAlerts,
            activeMesos: activeMesos,
            lastHotAlertsLoadAt: updatedAt,
            lastSlowProductsLoadAt: updatedAt,
            lastWeatherLoadAt: updatedAt,
            airQuality: airQuality,
            lastAirQualityLoadAt: airQuality == nil ? nil : updatedAt,
            stormSetup: stormSetup,
            lastStormSetupLoadAt: stormSetup == nil ? nil : updatedAt
        )
    }

    

    

    private func makeStormSetupDTO(
        h3Cell: Int64,
        expiresAt: Date,
        summary: String = "guidance"
    ) -> StormSetupDTO {
        StormSetupDTO(
            h3Cell: h3Cell,
            freshness: .init(
                isStale: false,
                isDegraded: false,
                modelRunTime: Date(timeIntervalSince1970: 100),
                sourceValidTime: Date(timeIntervalSince1970: 100),
                forecastHour: 1,
                fetchedAt: Date(timeIntervalSince1970: 100),
                expiresAt: expiresAt
            ),
            source: .init(
                model: "HRRR",
                product: "Storm Setup",
                domain: "severe",
                fieldSetVersion: "1",
                sourceKind: "production",
                runTime: Date(timeIntervalSince1970: 100),
                validTime: Date(timeIntervalSince1970: 100),
                forecastHour: 1,
                bbox: .init(toplat: 41.5, leftlon: -104.3, rightlon: -96.2, bottomlat: 36.8),
                primaryDownloadURL: "https://example.com/storm-setup"
            ),
            raw: .init(
                mlcapeJkg: 1850,
                mucapeJkg: 2200.5,
                sbcapeJkg: 1700,
                mlcinJkg: -42,
                srh01kmM2s2: 125.5,
                srh03kmM2s2: 175,
                shear06kmKt: 42,
                mllclM: 980,
                tempDewPtDeltaF: 4.5,
                threeCapeJkg: 95
            ),
            assessment: .init(
                overall: "supportive",
                summary: summary,
                instability: "supportive",
                moisture: "supportive",
                lowLevelRotation: "supportive",
                deepShear: "supportive",
                cloudBase: "supportive",
                capInhibition: "supportive",
                limitingFactors: ["capping"],
                confidence: "high",
                primaryDrivers: ["instability"],
                stormMode: "supportive",
                stormModeHint: "supportive",
                trend: "supportive",
                compositeSignal: "supportive"
            ),
            anvilEvidence: .init(
                status: "available",
                scp: .init(support: "supportive"),
                stp: .init(support: "supportive"),
                ship: .init(support: "supportive"),
                diagnostics: .init(
                    hasEffectiveLayer: true,
                    hasStormMotion: false,
                    qualityProfileLevelCount: 3,
                    warnings: ["watch heating"]
                )
            ),
            centroid: .init(latitude: 39.5, longitude: -100.0),
            surfaceHeightMslM: 1132.4
        )
}

@Suite("HomeView Keyed Projection Observation")
@MainActor
struct HomeViewKeyedProjectionObservationTests {
    @MainActor
    private final class ObservationRecorder {
        var snapshots: [HomeProjectionObservation.Snapshot] = []
        var contentIdentityTokens: [UUID] = []
    }

    @MainActor
    @Observable
    final class ProjectionKeyState {
        var projectionKey: String?

        init(projectionKey: String?) {
            self.projectionKey = projectionKey
        }
    }

    private struct ObservationHost: View {
        let state: ProjectionKeyState
        let recorder: ObservationRecorder

        var body: some View {
            HomeProjectionObservation(projectionKey: state.projectionKey) { revision, startup in
                let snapshot = HomeProjectionObservation.Snapshot(current: revision?.core, latestObserved: startup)
                ObservationContentProbe(snapshot: snapshot, recorder: recorder)
            }
        }
    }

    private struct ObservationContentProbe: View {
        let snapshot: HomeProjectionObservation.Snapshot
        let recorder: ObservationRecorder
        @State private var identityToken = UUID()

        var body: some View {
            Text("\(snapshot.current?.id.uuidString ?? "missing") / \(snapshot.latestObserved?.id.uuidString ?? "missing")")
                .onAppear {
                    recorder.snapshots.append(snapshot)
                    recorder.contentIdentityTokens.append(identityToken)
                }
                .onChange(of: snapshot) { _, newSnapshot in
                    recorder.snapshots.append(newSnapshot)
                    recorder.contentIdentityTokens.append(identityToken)
                }
        }
    }

    @Test("observation publishes warm startup, keyed travel, replacement, and fallback deletion")
    func observationPublishesRetainedProjectionTransitions() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let modelContext = ModelContext(container)
        let currentLocation = makeContext(h3Cell: 511, countyCode: "COC005", fireZone: "COZ214")
        let travelLocation = makeContext(h3Cell: 522, countyCode: "COC001", fireZone: "COZ200")
        let missingLocation = makeContext(h3Cell: 533, countyCode: "COC031", fireZone: "COZ201")
        let currentProjection = makeProjection(
            in: modelContext,
            location: currentLocation,
            updatedAt: Date(timeIntervalSince1970: 100),
            isDisplayReady: true
        )
        let travelProjection = makeProjection(
            in: modelContext,
            location: travelLocation,
            updatedAt: Date(timeIntervalSince1970: 200),
            isDisplayReady: true
        )
        try modelContext.save()

        let recorder = ObservationRecorder()
        let keyState = ProjectionKeyState(projectionKey: nil)
        let host = UIHostingController(
            rootView: ObservationHost(state: keyState, recorder: recorder).modelContainer(container)
        )
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        try await waitForEmission(in: recorder, afterCount: 0) {
            $0.current?.id == travelProjection.id && $0.latestObserved?.id == travelProjection.id
        }
        #expect(recorder.snapshots.last?.latestObserved?.id == travelProjection.id)

        keyState.projectionKey = HomeProjection.projectionKey(for: currentLocation)
        try await waitForEmission(in: recorder, afterCount: recorder.snapshots.count) {
            $0.current?.id == currentProjection.id
        }
        keyState.projectionKey = HomeProjection.projectionKey(for: travelLocation)
        try await waitForEmission(in: recorder, afterCount: recorder.snapshots.count) {
            $0.current?.id == travelProjection.id
        }
        keyState.projectionKey = HomeProjection.projectionKey(for: missingLocation)
        try await waitForEmission(in: recorder, afterCount: recorder.snapshots.count) { $0.current == nil }

        keyState.projectionKey = HomeProjection.projectionKey(for: currentLocation)
        try await waitForEmission(in: recorder, afterCount: recorder.snapshots.count) {
            $0.current?.id == currentProjection.id
        }
        #expect(Set(recorder.contentIdentityTokens).count == 1)

        var priorEmissionCount = recorder.snapshots.count
        let replacement = makeProjection(
            in: modelContext,
            location: currentLocation,
            updatedAt: Date(timeIntervalSince1970: 300),
            isDisplayReady: true
        )
        try modelContext.save()
        priorEmissionCount = recorder.snapshots.count
        try await waitForEmission(in: recorder, afterCount: priorEmissionCount) { $0.current?.id == replacement.id }

        let newerStartupFallback = makeProjection(
            in: modelContext,
            location: missingLocation,
            updatedAt: Date(timeIntervalSince1970: 400),
            isDisplayReady: true
        )
        try modelContext.save()
        priorEmissionCount = recorder.snapshots.count
        try await waitForEmission(in: recorder, afterCount: priorEmissionCount) {
            $0.latestObserved?.id == newerStartupFallback.id
        }
        modelContext.delete(newerStartupFallback)
        try modelContext.save()
        priorEmissionCount = recorder.snapshots.count
        try await waitForEmission(in: recorder, afterCount: priorEmissionCount) {
            $0.latestObserved?.id == replacement.id
        }

        window.isHidden = true
    }

    @Test("initial warm revision survives its first same-context observation gap")
    func initialWarmRevisionSurvivesFirstGap() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let modelContext = ModelContext(container)
        let location = makeContext(h3Cell: 611, countyCode: "COC005", fireZone: "COZ214")
        let other = makeContext(h3Cell: 622, countyCode: "COC001", fireZone: "COZ200")
        let cached = makeProjection(
            in: modelContext,
            location: location,
            updatedAt: Date(timeIntervalSince1970: 100),
            isDisplayReady: true
        )
        try modelContext.save()

        let recorder = ObservationRecorder()
        let keyState = ProjectionKeyState(projectionKey: HomeProjection.projectionKey(for: location))
        let host = UIHostingController(
            rootView: ObservationHost(state: keyState, recorder: recorder).modelContainer(container)
        )
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        try await waitForEmission(in: recorder, afterCount: 0) { $0.current?.id == cached.id }

        modelContext.delete(cached)
        try modelContext.save()
        let beforeGap = recorder.snapshots.count
        try await waitForEmission(in: recorder, afterCount: beforeGap) {
            $0.current?.id == cached.id && $0.latestObserved == nil
        }

        keyState.projectionKey = HomeProjection.projectionKey(for: other)
        try await waitForEmission(in: recorder, afterCount: recorder.snapshots.count) { $0.current == nil }
        window.isHidden = true
    }

    @Test("projection query observes all sorted rows and preserves readiness selection")
    func projectionQuery_observesAllRowsAndReplacesOlderValues() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let modelContext = ModelContext(container)
        let currentLocation = makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214")
        let travelLocation = makeContext(h3Cell: 222, countyCode: "COC001", fireZone: "COZ200")
        let placeholderLocation = makeContext(h3Cell: 444, countyCode: "COC047", fireZone: "COZ202")

        _ = makeProjection(
            in: modelContext,
            location: currentLocation,
            updatedAt: Date(timeIntervalSince1970: 100),
            isDisplayReady: true
        )
        let replacementCurrent = makeProjection(
            in: modelContext,
            location: currentLocation,
            updatedAt: Date(timeIntervalSince1970: 300),
            isDisplayReady: true
        )
        let newestOtherLocation = makeProjection(
            in: modelContext,
            location: travelLocation,
            updatedAt: Date(timeIntervalSince1970: 200),
            isDisplayReady: true
        )
        let unreadyPlaceholder = makeProjection(
            in: modelContext,
            location: placeholderLocation,
            updatedAt: Date(timeIntervalSince1970: 400),
            isDisplayReady: false
        )
        for offset in 1...55 {
            _ = makeProjection(
                in: modelContext,
                location: placeholderLocation,
                updatedAt: Date(timeIntervalSince1970: TimeInterval(offset)),
                isDisplayReady: false
            )
        }
        try modelContext.save()

        let descriptor = HomeProjection.orderedProjectionsDescriptor()
        let allCandidates = try modelContext.fetch(descriptor)
        #expect(descriptor.predicate == nil)
        #expect(descriptor.fetchLimit == nil)
        #expect(allCandidates.count == 59)
        #expect(allCandidates.contains(where: { $0.id == unreadyPlaceholder.id }))
        let currentCandidates = allCandidates.filter {
            $0.projectionKey == HomeProjection.projectionKey(for: currentLocation)
        }
        #expect(
            HomeProjectionObservation.newestDisplayReadyProjection(in: currentCandidates)?.id == replacementCurrent.id
        )
        #expect(
            HomeProjectionObservation.newestDisplayReadyProjection(in: allCandidates)?.id == replacementCurrent.id
        )

        let store = HomeProjectionStore(modelContainer: container)
        await store.resetOperationMetricsForTesting()
        let newestReady = try await store.newestDisplayReadyProjection()
        #expect(newestReady?.id == replacementCurrent.id)
        let storeMetrics = await store.operationMetricsForTesting()
        #expect(storeMetrics.rowsFetched == allCandidates.count)
        #expect(
            HomeView.selectProjection(
                from: [newestReady].compactMap { $0 },
                currentContext: nil
            ) == replacementCurrent.record
        )

        let travelCandidates = allCandidates.filter {
            $0.projectionKey == HomeProjection.projectionKey(for: travelLocation)
        }
        #expect(HomeProjectionObservation.newestDisplayReadyProjection(in: travelCandidates)?.id == newestOtherLocation.id)

        let missingCandidates = allCandidates.filter {
            $0.projectionKey == HomeProjection.projectionKey(
                for: makeContext(h3Cell: 333, countyCode: "COC031", fireZone: "COZ201")
            )
        }
        #expect(missingCandidates.isEmpty)

        modelContext.delete(replacementCurrent)
        try modelContext.save()
        let fallbackAfterDeletion = try modelContext.fetch(HomeProjection.orderedProjectionsDescriptor())
        #expect(
            HomeProjectionObservation.newestDisplayReadyProjection(in: fallbackAfterDeletion)?.id == newestOtherLocation.id
        )
    }

    private func makeProjection(
        in modelContext: ModelContext,
        location: LocationContext,
        updatedAt: Date,
        isDisplayReady: Bool
    ) -> HomeProjection {
        let projection = HomeProjection(context: location, createdAt: updatedAt)
        projection.updatedAt = updatedAt
        if isDisplayReady {
            projection.lastHotAlertsLoadAt = updatedAt
            projection.lastSlowProductsLoadAt = updatedAt
        }
        modelContext.insert(projection)
        return projection
    }

    private func waitForEmission(
        in recorder: ObservationRecorder,
        afterCount: Int,
        matching predicate: (HomeProjectionObservation.Snapshot) -> Bool
    ) async throws {
        for _ in 0..<100 {
            if recorder.snapshots.dropFirst(afterCount).contains(where: predicate) { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("Timed out waiting for a matching Home projection observation")
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

@Suite("HomeView Alert Ownership")
@MainActor
struct HomeViewAlertOwnershipTests {
    @Test("presentation snapshot applies one location-scoped selection matrix")
    func presentationSnapshot_appliesLocationScopedSelectionMatrix() throws {
        let currentContext = makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214")
        let previousContext = makeContext(h3Cell: 222, countyCode: "COC001", fireZone: "COZ200")
        let cachedAlert = Watch.sampleWatchRows[0]
        let pipelineAlert = Watch.sampleWatchRows[1]
        let cachedMeso = MD.sampleDiscussionDTOs[0]
        let pipelineMeso = MD.sampleDiscussionDTOs[1]
        let cachedAirQuality = try DecoderFactory.iso8601.decode(
            AirQualityCurrentResponse.self,
            from: Data(#"{"aqi":61,"category":{"identifier":2,"name":"Moderate"},"primaryPollutant":"PM2.5","observedAt":"2026-07-12T20:00:00Z","sourceIdentifier":"airnow"}"#.utf8)
        )
        let projection = makeProjectionRecord(
            context: currentContext,
            updatedAt: Date(timeIntervalSince1970: 100),
            airQuality: cachedAirQuality,
            activeAlerts: [cachedAlert],
            activeMesos: [cachedMeso]
        )
        let airQuality = try DecoderFactory.iso8601.decode(
            AirQualityCurrentResponse.self,
            from: Data(#"{"aqi":121,"category":{"identifier":3,"name":"Unhealthy for Sensitive Groups"},"primaryPollutant":"PM2.5","observedAt":"2026-07-12T21:00:00Z","sourceIdentifier":"airnow"}"#.utf8)
        )

        let stale = makePresentationSnapshot(
            projections: [projection],
            newestStartupProjection: projection,
            currentContext: currentContext,
            pipelineAirQuality: airQuality,
            pipelineMesos: [pipelineMeso],
            pipelineAlerts: [pipelineAlert],
            resolvedLocationScopedRefreshKey: previousContext.refreshKey,
            alertSnapshotRefreshKey: previousContext.refreshKey
        )
        #expect(stale.projection == projection)
        #expect(stale.alerts == [cachedAlert])
        #expect(stale.mesos == [cachedMeso])
        #expect(stale.airQuality == cachedAirQuality)

        let committed = makePresentationSnapshot(
            projections: [projection],
            newestStartupProjection: projection,
            currentContext: currentContext,
            pipelineAirQuality: airQuality,
            pipelineMesos: [],
            pipelineAlerts: [],
            resolvedLocationScopedRefreshKey: currentContext.refreshKey,
            alertSnapshotRefreshKey: currentContext.refreshKey
        )
        #expect(committed.isCurrentContextResolvedInPipeline)
        #expect(committed.isCurrentContextCommittedAlertSnapshot)
        #expect(committed.alerts == [cachedAlert])
        #expect(committed.mesos == [cachedMeso])
        #expect(committed.airQuality == cachedAirQuality)

        let preserved = makePresentationSnapshot(
            projections: [projection],
            newestStartupProjection: projection,
            currentContext: currentContext,
            resolvedLocationScopedRefreshKey: currentContext.refreshKey,
            alertSnapshotRefreshKey: currentContext.refreshKey
        )
        #expect(preserved.airQuality == cachedAirQuality)

        let newLocationAirQuality = try DecoderFactory.iso8601.decode(
            AirQualityCurrentResponse.self,
            from: Data(#"{"aqi":42,"category":{"identifier":1,"name":"Good"},"primaryPollutant":"O3","observedAt":"2026-07-12T20:30:00Z","sourceIdentifier":"airnow"}"#.utf8)
        )
        let newLocationProjection = makeProjectionRecord(
            context: previousContext,
            updatedAt: Date(timeIntervalSince1970: 200),
            airQuality: newLocationAirQuality
        )
        let locationChanged = makePresentationSnapshot(
            projections: [projection, newLocationProjection],
            newestStartupProjection: newLocationProjection,
            currentContext: previousContext,
            pipelineAirQuality: airQuality,
            resolvedLocationScopedRefreshKey: previousContext.refreshKey,
            alertSnapshotRefreshKey: previousContext.refreshKey
        )
        #expect(locationChanged.projection == newLocationProjection)
        #expect(locationChanged.airQuality == newLocationAirQuality)

        let locationChangedWithoutCache = makePresentationSnapshot(
            projections: [projection, makeProjectionRecord(context: previousContext, updatedAt: Date(timeIntervalSince1970: 200))],
            newestStartupProjection: newLocationProjection,
            currentContext: previousContext,
            pipelineAirQuality: airQuality,
            resolvedLocationScopedRefreshKey: previousContext.refreshKey,
            alertSnapshotRefreshKey: previousContext.refreshKey
        )
        #expect(locationChangedWithoutCache.airQuality == nil)

        let staticOverride = makePresentationSnapshot(
            projections: [projection],
            newestStartupProjection: projection,
            currentContext: currentContext,
            pipelineMesos: [pipelineMeso],
            pipelineAlerts: [pipelineAlert],
            alertSnapshotRefreshKey: previousContext.refreshKey,
            isUITestStaticMode: true
        )
        #expect(staticOverride.alerts == [pipelineAlert])
        #expect(staticOverride.mesos == [pipelineMeso])
    }

    private func makePresentationSnapshot(
        projections: [HomeProjectionRecord],
        newestStartupProjection: HomeProjectionRecord?,
        currentContext: LocationContext?,
        pipelineAirQuality: AirQualityCurrentResponse? = nil,
        pipelineMesos: [MdDTO] = [],
        pipelineAlerts: [AlertDTO] = [],
        resolvedLocationScopedRefreshKey: LocationContext.RefreshKey? = nil,
        alertSnapshotRefreshKey: LocationContext.RefreshKey? = nil,
        isUITestStaticMode: Bool = false
    ) -> HomeView.HomePresentationSnapshot {
        HomeView.HomePresentationSnapshot(
            visibleRevision: HomeView.selectProjection(from: projections, currentContext: currentContext)
                .map { HomeVisibleRevision(core: $0, alerts: nil, enrichment: nil) },
            newestStartupProjection: newestStartupProjection,
            currentContext: currentContext,
            pipelineSnap: nil,
            pipelineStormRisk: nil,
            pipelineSevereRisk: nil,
            pipelineFireRisk: nil,
            pipelineWeather: nil,
            pipelineAirQuality: pipelineAirQuality,
            pipelineMesos: pipelineMesos,
            pipelineAlerts: pipelineAlerts,
            resolvedLocationScopedRefreshKey: resolvedLocationScopedRefreshKey,
            alertSnapshotRefreshKey: alertSnapshotRefreshKey,
            pipelineStormSetup: nil,
            pipelineStormSetupCurrentResponse: nil,
            stormSetupRefreshKey: nil,
            isUITestStaticMode: isUITestStaticMode,
            now: Date(timeIntervalSince1970: 200)
        )
    }

}
