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

    @Test("storm setup settings use raw values and session tick refresh path")
    func stormSetupSettings_useRawValuesAndSessionTickRefreshPath() {
        let preferences = StormSetupPreferences(stormSetupEnabled: false, detailedIngredientsEnabled: true)
        #expect(preferences.effectiveDetailedIngredientsEnabled == false)

        let current = StormSetupPreferences(stormSetupEnabled: true, detailedIngredientsEnabled: true)
        #expect(HomeView.shouldRefreshStormSetupSettings(previousPreferences: current, currentPreferences: current) == false)
        #expect(HomeView.shouldRefreshStormSetupSettings(previousPreferences: nil, currentPreferences: current))
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
        timeZoneId: String? = nil
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
            activeAlerts: [],
            activeMesos: [],
            lastHotAlertsLoadAt: nil,
            lastSlowProductsLoadAt: nil,
            lastWeatherLoadAt: nil,
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
    @Test("cached alerts and mesos stay visible until the committed key matches the current context")
    func preferredCurrentContextValues_keepsCachedValuesUntilMatchingCommit() {
        let currentContext = makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214")
        let otherContext = makeContext(h3Cell: 222, countyCode: "COC001", fireZone: "COZ200")
        let cachedMesos = [MD.sampleDiscussionDTOs[0]]
        let liveMesos = [MD.sampleDiscussionDTOs[1]]
        let cachedAlerts = [Watch.sampleWatchRows[0]]
        let liveAlerts = [Watch.sampleWatchRows[1]]

        #expect(
            HomeView.preferredCurrentContextValues(
                cachedValues: cachedMesos,
                pipelineValues: liveMesos,
                currentContext: currentContext,
                pipelineRefreshKey: nil
            ) == cachedMesos
        )
        #expect(
            HomeView.preferredCurrentContextValues(
                cachedValues: cachedAlerts,
                pipelineValues: liveAlerts,
                currentContext: currentContext,
                pipelineRefreshKey: otherContext.refreshKey
            ) == cachedAlerts
        )
        #expect(
            HomeView.preferredCurrentContextValues(
                cachedValues: cachedMesos,
                pipelineValues: liveMesos,
                currentContext: currentContext,
                pipelineRefreshKey: currentContext.refreshKey
            ) == liveMesos
        )
        #expect(
            HomeView.preferredCurrentContextValues(
                cachedValues: cachedAlerts,
                pipelineValues: liveAlerts,
                currentContext: currentContext,
                pipelineRefreshKey: currentContext.refreshKey
            ) == liveAlerts
        )
    }

    @Test("a committed empty snapshot becomes authoritative for the current context")
    func preferredCurrentContextValues_allowsCommittedEmptyValues() {
        let currentContext = makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214")
        let cachedAlerts = [Watch.sampleWatchRows[0]]

        #expect(
            HomeView.preferredCurrentContextValues(
                cachedValues: cachedAlerts,
                pipelineValues: [],
                currentContext: currentContext,
                pipelineRefreshKey: currentContext.refreshKey
            ).isEmpty
        )
    }

    @Test("a commit for the previous context does not replace the current context's cached alerts")
    func preferredCurrentContextValues_ignoresPriorContextCommitAfterLocationChange() {
        let previousContext = makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214")
        let currentContext = makeContext(h3Cell: 222, countyCode: "COC001", fireZone: "COZ200")
        let cachedAlerts = [Watch.sampleWatchRows[0]]
        let priorContextAlerts = [Watch.sampleWatchRows[1]]

        #expect(
            HomeView.preferredCurrentContextValues(
                cachedValues: cachedAlerts,
                pipelineValues: priorContextAlerts,
                currentContext: currentContext,
                pipelineRefreshKey: previousContext.refreshKey
            ) == cachedAlerts
        )
    }
}
