import CoreLocation
import Foundation
import OSLog
import Testing
import ArcusCore
@testable import SkyAware

@Suite("Home Refresh Pipeline", .serialized)
@MainActor
struct HomeRefreshPipelineTests {
    @Test("scene active submits foreground activate to the unified queue")
    func sceneActive_submitsForegroundActivate() async throws {
        let context = makeContext()
        let coordinator = RecordingHomeIngestionCoordinator()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline()

        await pipeline.handleScenePhaseChange(
            .active,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: locationSession
            )
        )
        await pipeline.waitForIdle()

        let requests = await coordinator.requests()
        #expect(requests.count == 2)
        #expect(requests[0].trigger == .foregroundPrime)
        #expect(requests[0].locationContext == nil)
        #expect(requests[1].trigger == .foregroundActivate)
        #expect(requests[1].locationContext == nil)
    }

    @Test("context change forwards the current resolved context to the unified queue")
    func contextChanged_submitsExplicitLocationContext() async throws {
        let context = makeContext()
        let coordinator = RecordingHomeIngestionCoordinator()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline()

        await pipeline.enqueueRefresh(
            .contextChanged,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: locationSession
            )
        )
        await pipeline.waitForIdle()

        let requests = await coordinator.requests()
        #expect(requests.count == 2)
        #expect(requests[0].trigger == .foregroundPrime)
        #expect(requests[0].locationContext == context)
        #expect(requests[1].trigger == .foregroundLocationChange)
        #expect(requests[1].locationContext == context)
    }

    @Test("settings refresh entry point uses one non-forced session tick request")
    func settingsRefreshEntryPoint_usesNonForcedSessionTickRequest() async throws {
        let context = makeContext()
        let coordinator = RecordingHomeIngestionCoordinator()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline()

        await pipeline.enqueueRefresh(
            .timer,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: locationSession
            )
        )
        await pipeline.waitForIdle()

        let requests = await coordinator.requests()
        #expect(requests.count == 1)
        #expect(requests[0].trigger == .sessionTick)
        #expect(HomeIngestionPlan(request: requests[0]).forcedLanes.isEmpty)
    }

    @Test("initial context publication during startup does not queue a second refresh")
    func startupContextPublication_doesNotQueueFollowUpRefresh() async throws {
        let context = makeContext()
        let gate = AsyncGate()
        let snapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .hail(probability: 0.30),
            fireRisk: .elevated,
            outlooks: sampleOutlooks(),
            latestOutlook: sampleOutlooks().first
        )
        let coordinator = RecordingHomeIngestionCoordinator(snapshot: snapshot, runGate: gate)
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline()
        let environment = makeEnvironment(
            coordinator: coordinator,
            locationSession: locationSession
        )

        Task {
            await pipeline.handleScenePhaseChange(.active, environment: environment)
        }

        let requestStarted = await waitUntil {
            await coordinator.requestCount() == 1
        }
        #expect(requestStarted)

        await pipeline.handleContextRefreshKeyChange(
            context.refreshKey,
            scenePhase: .active,
            environment: environment
        )

        await Task.yield()
        #expect(await coordinator.requestCount() == 1)

        await gate.open()
        await pipeline.waitForIdle()

        #expect(await coordinator.requestCount() == 2)
    }

    @Test("force refresh waits for unified queue completion when loading is shown")
    func forceRefresh_waitsUntilCoordinatorCompletes() async {
        let gate = AsyncGate()
        let coordinator = RecordingHomeIngestionCoordinator(runGate: gate)
        let locationSession = FakeLocationSession(currentContext: makeContext(), preparedContext: makeContext())
        let pipeline = HomeRefreshPipeline()
        let completion = CompletionFlag()

        let refreshTask = Task { @MainActor in
            await pipeline.forceRefreshCurrentContext(
                showsLoading: true,
                environment: makeEnvironment(
                    coordinator: coordinator,
                    locationSession: locationSession
                )
            )
            await completion.markFinished()
        }

        let requestStarted = await waitUntil {
            await coordinator.requestCount() == 1
        }
        #expect(requestStarted)
        #expect(pipeline.resolutionState.isRefreshing)
        #expect(await completion.isFinished() == false)

        await gate.open()
        await refreshTask.value

        #expect(await completion.isFinished())
        #expect(pipeline.resolutionState.isRefreshing == false)
    }

    @Test("hot alert progress only resolves the alerts section")
    func hotAlertProgress_resolvesOnlyAlertsSection() async {
        let gate = AsyncGate()
        let coordinator = RecordingHomeIngestionCoordinator(
            runGate: gate,
            progressEvents: [.started(.lane(.hotAlerts))]
        )
        let locationSession = FakeLocationSession(currentContext: makeContext(), preparedContext: makeContext())
        let pipeline = HomeRefreshPipeline()

        let refreshTask = Task { @MainActor in
            await pipeline.forceRefreshCurrentContext(
                showsLoading: true,
                environment: makeEnvironment(
                    coordinator: coordinator,
                    locationSession: locationSession
                )
            )
        }

        let alertsResolving = await waitUntil(timeout: .seconds(5)) {
            pipeline.resolutionState.isResolving(.alerts)
        }
        #expect(alertsResolving)
        #expect(pipeline.resolutionState.isResolving(.conditions) == false)
        #expect(pipeline.resolutionState.isResolving(.stormRisk) == false)
        #expect(pipeline.resolutionState.isResolving(.outlook) == false)

        await gate.open()
        await refreshTask.value

        #expect(pipeline.resolutionState.isRefreshing == false)
        #expect(pipeline.resolutionState.isResolving(.alerts) == false)
    }

    @Test("real session tick location progress does not broaden resolving sections")
    func realSessionTickLocationProgress_resolvesOnlyAlertsSection() async {
        let context = makeContext()
        let prepareGate = AsyncGate()
        let locationSession = FakeLocationSession(
            currentContext: nil,
            preparedContext: context,
            prepareGate: prepareGate
        )
        let syncGate = AsyncGate()
        let spc = FakeSpcProvider(syncMesoscaleGate: syncGate)
        let pipeline = HomeRefreshPipeline()
        let environment = makeEnvironment(
            spc: spc,
            locationSession: locationSession
        )

        await pipeline.enqueueRefresh(.timer, environment: environment)

        let locationResolutionStarted = await waitUntil(timeout: .seconds(5)) {
            locationSession.prepareCalls.isEmpty == false
        }
        #expect(locationResolutionStarted)
        #expect(pipeline.resolutionState.isResolving(.alerts))
        #expect(pipeline.resolutionState.isResolving(.conditions) == false)
        #expect(pipeline.resolutionState.isResolving(.stormRisk) == false)
        #expect(pipeline.resolutionState.isResolving(.severeRisk) == false)
        #expect(pipeline.resolutionState.isResolving(.fireRisk) == false)
        #expect(pipeline.resolutionState.isResolving(.atmosphere) == false)

        await prepareGate.open()

        let hotAlertSyncStarted = await waitUntil(timeout: .seconds(5)) {
            await spc.syncMesoscaleDiscussionsCount() == 1
        }
        #expect(hotAlertSyncStarted)
        #expect(pipeline.resolutionState.isResolving(.alerts))
        #expect(pipeline.resolutionState.isResolving(.conditions) == false)
        #expect(pipeline.resolutionState.isResolving(.stormRisk) == false)
        #expect(pipeline.resolutionState.isResolving(.severeRisk) == false)
        #expect(pipeline.resolutionState.isResolving(.fireRisk) == false)
        #expect(pipeline.resolutionState.isResolving(.atmosphere) == false)

        await syncGate.open()
        await pipeline.waitForIdle()

        #expect(pipeline.resolutionState.isRefreshing == false)
        for section in SummarySection.resolveForwardSections {
            #expect(pipeline.resolutionState.isResolving(section) == false)
        }
    }

    @Test("real full refresh location progress keeps broad resolving sections")
    func realFullRefreshLocationProgress_resolvesBroadSections() async {
        let context = makeContext()
        let prepareGate = AsyncGate()
        let locationSession = FakeLocationSession(
            currentContext: nil,
            preparedContext: context,
            prepareGate: prepareGate
        )
        let pipeline = HomeRefreshPipeline()
        let environment = makeEnvironment(locationSession: locationSession)

        let refreshTask = Task { @MainActor in
            await pipeline.forceRefreshCurrentContext(
                showsLoading: true,
                environment: environment
            )
        }

        let locationResolutionStarted = await waitUntil(timeout: .seconds(5)) {
            locationSession.prepareCalls.isEmpty == false
        }
        #expect(locationResolutionStarted)
        #expect(pipeline.resolutionState.isResolving(.conditions))
        #expect(pipeline.resolutionState.isResolving(.stormRisk))
        #expect(pipeline.resolutionState.isResolving(.severeRisk))
        #expect(pipeline.resolutionState.isResolving(.fireRisk))
        #expect(pipeline.resolutionState.isResolving(.atmosphere))
        #expect(pipeline.resolutionState.isResolving(.alerts))

        await prepareGate.open()
        await refreshTask.value

        #expect(pipeline.resolutionState.isRefreshing == false)
        for section in SummarySection.resolveForwardSections {
            #expect(pipeline.resolutionState.isResolving(section) == false)
        }
    }

    @Test("weather and slow product progress resolve their mapped sections")
    func weatherAndSlowProductProgress_resolveMappedSections() async {
        let gate = AsyncGate()
        let coordinator = RecordingHomeIngestionCoordinator(
            runGate: gate,
            progressEvents: [
                .started(.lane(.weather)),
                .started(.lane(.slowProducts)),
            ]
        )
        let locationSession = FakeLocationSession(currentContext: makeContext(), preparedContext: makeContext())
        let pipeline = HomeRefreshPipeline()

        let refreshTask = Task { @MainActor in
            await pipeline.forceRefreshCurrentContext(
                showsLoading: true,
                environment: makeEnvironment(
                    coordinator: coordinator,
                    locationSession: locationSession
                )
            )
        }

        let mappedSectionsResolving = await waitUntil(timeout: .seconds(5)) {
            pipeline.resolutionState.isResolving(.conditions) &&
            pipeline.resolutionState.isResolving(.atmosphere) &&
            pipeline.resolutionState.isResolving(.stormRisk) &&
            pipeline.resolutionState.isResolving(.severeRisk) &&
            pipeline.resolutionState.isResolving(.fireRisk) &&
            pipeline.resolutionState.isResolving(.outlook)
        }
        #expect(mappedSectionsResolving)
        #expect(pipeline.resolutionState.isResolving(.alerts) == false)

        await gate.open()
        await refreshTask.value

        #expect(pipeline.resolutionState.isRefreshing == false)
        for section in SummarySection.resolveForwardSections {
            #expect(pipeline.resolutionState.isResolving(section) == false)
        }
    }

    @Test("visible commit propagates storm setup and keeps existing home slices intact")
    func visibleCommit_propagatesStormSetupAndKeepsOtherSlicesIntact() async {
        let context = makeContext()
        let sampleMd = MD.sampleDiscussionDTOs[0]
        let sampleAlerts = [Watch.sampleWatchRows[0]]
        let sampleOutlooksValue = sampleOutlooks()
        let sampleWeatherValue = sampleWeather()
        let stormSetup = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 500)
        )
        let snapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            weather: sampleWeatherValue,
            weatherRefreshResult: .success(sampleWeatherValue),
            stormSetup: stormSetup,
            stormSetupRefreshResult: .success,
            stormRisk: .moderate,
            severeRisk: .hail(probability: 0.25),
            fireRisk: .elevated,
            mesos: [sampleMd],
            alerts: sampleAlerts,
            outlooks: sampleOutlooksValue,
            latestOutlook: sampleOutlooksValue.first
        )
        let coordinator = RecordingHomeIngestionCoordinator(snapshot: snapshot)
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline()

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: locationSession
            )
        )

        #expect(pipeline.stormSetup == stormSetup)
        #expect(pipeline.stormSetupRefreshKey == context.refreshKey)
        #expect(pipeline.stormRisk == .moderate)
        #expect(pipeline.severeRisk == .hail(probability: 0.25))
        #expect(pipeline.fireRisk == .elevated)
        #expect(pipeline.mesos == [sampleMd])
        #expect(pipeline.alerts == sampleAlerts)
        #expect(pipeline.outlooks == sampleOutlooksValue)
        #expect(pipeline.outlook?.title == sampleOutlooksValue.first?.title)
        #expect(pipeline.summaryWeather != nil)
    }

    @Test("staged enrichment rejects a mismatched ingestion run")
    func stagedEnrichment_rejectsMismatchedRunIdentity() async {
        let context = makeContext()
        let acceptedRunID = UUID(uuidString: "32500000-0000-0000-0000-000000000101")!
        let mismatchedRunID = UUID(uuidString: "32500000-0000-0000-0000-000000000102")!
        let cached = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 500),
            summary: "cached guidance"
        )
        let rejected = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 600),
            summary: "wrong run"
        )
        let coreSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .moderate
        )
        let finalSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormSetup: rejected,
            stormRisk: .moderate
        )
        let coordinator = ScriptedStagedHomeIngestionCoordinator(
            runs: [
                .init(
                    core: .init(runID: acceptedRunID, stage: .core(.init(snapshot: coreSnapshot))),
                    enrichment: .init(
                        runID: mismatchedRunID,
                        stage: .enrichment(.init(snapshot: finalSnapshot))
                    ),
                    finalSnapshot: finalSnapshot
                )
            ]
        )
        let pipeline = HomeRefreshPipeline(
            initialStormRisk: .slight,
            initialStormSetup: cached,
            initialStormSetupRefreshKey: context.refreshKey
        )

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: FakeLocationSession(currentContext: context, preparedContext: context)
            )
        )

        #expect(pipeline.stormRisk == .moderate)
        #expect(pipeline.stormSetup == cached)
        #expect(pipeline.stormSetupRefreshKey == context.refreshKey)
    }

    @Test("staged enrichment rejects a mismatched location refresh key")
    func stagedEnrichment_rejectsMismatchedRefreshKey() async {
        let currentContext = makeContext(h3Cell: 111_111)
        let mismatchedContext = makeContext(h3Cell: 222_222, timestamp: 200)
        let runID = UUID(uuidString: "32500000-0000-0000-0000-000000000103")!
        let cached = makeStormSetupDTO(
            h3Cell: currentContext.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 500),
            summary: "cached guidance"
        )
        let rejected = makeStormSetupDTO(
            h3Cell: mismatchedContext.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 600),
            summary: "wrong location"
        )
        let coreSnapshot = HomeSnapshot(
            locationSnapshot: currentContext.snapshot,
            refreshKey: currentContext.refreshKey,
            stormRisk: .moderate
        )
        let mismatchedEnrichment = HomeSnapshot(
            refreshKey: mismatchedContext.refreshKey,
            stormSetup: rejected
        )
        let coordinator = ScriptedStagedHomeIngestionCoordinator(
            runs: [
                .init(
                    core: .init(runID: runID, stage: .core(.init(snapshot: coreSnapshot))),
                    enrichment: .init(
                        runID: runID,
                        stage: .enrichment(.init(snapshot: mismatchedEnrichment))
                    ),
                    finalSnapshot: coreSnapshot
                )
            ]
        )
        let pipeline = HomeRefreshPipeline(
            initialStormSetup: cached,
            initialStormSetupRefreshKey: currentContext.refreshKey
        )

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: FakeLocationSession(
                    currentContext: currentContext,
                    preparedContext: currentContext
                )
            )
        )

        #expect(pipeline.stormRisk == .moderate)
        #expect(pipeline.stormSetup == cached)
        #expect(pipeline.stormSetupRefreshKey == currentContext.refreshKey)
    }

    @Test("staged optional failure and timeout retain visible core and same-location cache")
    func stagedOptionalFailureAndTimeout_retainCoreAndSameLocationCache() async {
        let context = makeContext()
        let cached = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 500),
            summary: "cached guidance"
        )
        let outcomes: [HomeStormSetupRefreshResult] = [.failure, .timeout]

        for (index, outcome) in outcomes.enumerated() {
            let gate = AsyncGate()
            let runID = UUID()
            let coreSnapshot = HomeSnapshot(
                locationSnapshot: context.snapshot,
                refreshKey: context.refreshKey,
                stormRisk: index == 0 ? .moderate : .enhanced
            )
            let finalSnapshot = HomeSnapshot(
                locationSnapshot: context.snapshot,
                refreshKey: context.refreshKey,
                stormSetupRefreshResult: outcome,
                stormRisk: coreSnapshot.stormRisk
            )
            let coordinator = ScriptedStagedHomeIngestionCoordinator(
                runs: [
                    .init(
                        core: .init(runID: runID, stage: .core(.init(snapshot: coreSnapshot))),
                        enrichment: .init(
                            runID: runID,
                            stage: .enrichment(.init(snapshot: finalSnapshot))
                        ),
                        afterCoreGate: gate,
                        finalSnapshot: finalSnapshot
                    )
                ]
            )
            let pipeline = HomeRefreshPipeline(
                initialStormRisk: .slight,
                initialStormSetup: cached,
                initialStormSetupRefreshKey: context.refreshKey
            )
            let task = Task { @MainActor in
                await pipeline.forceRefreshCurrentContext(
                    showsLoading: true,
                    environment: makeEnvironment(
                        coordinator: coordinator,
                        locationSession: FakeLocationSession(currentContext: context, preparedContext: context)
                    )
                )
            }

            let coreVisible = await waitUntil(timeout: .seconds(5)) {
                pipeline.stormRisk == coreSnapshot.stormRisk
            }
            #expect(coreVisible, "\(outcome)")
            #expect(pipeline.stormSetup == cached, "\(outcome)")

            await gate.open()
            await task.value

            #expect(pipeline.stormRisk == coreSnapshot.stormRisk, "\(outcome)")
            #expect(pipeline.stormSetup == cached, "\(outcome)")
            #expect(pipeline.stormSetupRefreshKey == context.refreshKey, "\(outcome)")
        }
    }

    @Test("cancellation after staged core keeps core visible without enrichment")
    func cancellationAfterStagedCore_keepsCoreVisibleWithoutEnrichment() async {
        let context = makeContext()
        let cached = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 500),
            summary: "cached guidance"
        )
        let coreSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .moderate
        )
        let coordinator = ScriptedStagedHomeIngestionCoordinator(
            runs: [
                .init(
                    core: .init(runID: UUID(), stage: .core(.init(snapshot: coreSnapshot))),
                    finalSnapshot: coreSnapshot,
                    waitsForCancellation: true
                )
            ]
        )
        let pipeline = HomeRefreshPipeline(
            initialStormRisk: .slight,
            initialStormSetup: cached,
            initialStormSetupRefreshKey: context.refreshKey
        )
        let task = Task { @MainActor in
            await pipeline.forceRefreshCurrentContext(
                showsLoading: true,
                environment: makeEnvironment(
                    coordinator: coordinator,
                    locationSession: FakeLocationSession(currentContext: context, preparedContext: context)
                )
            )
        }

        let coreVisible = await waitUntil(timeout: .seconds(5)) {
            pipeline.stormRisk == .moderate
        }
        #expect(coreVisible)
        task.cancel()
        await task.value

        #expect(pipeline.stormRisk == .moderate)
        #expect(pipeline.stormSetup == cached)
        #expect(pipeline.lastResolvedLocationScopedRefreshKey == context.refreshKey)
    }

    @Test("location-changing core clears optional content before enrichment")
    func locationChangingCore_clearsOptionalContentBeforeEnrichment() async throws {
        let oldContext = makeContext(h3Cell: 111_111)
        let newContext = makeContext(h3Cell: 222_222, timestamp: 200)
        let oldStormSetup = makeStormSetupDTO(
            h3Cell: oldContext.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 500)
        )
        let oldAirQuality = try DecoderFactory.iso8601.decode(
            AirQualityCurrentResponse.self,
            from: Data(
                """
                {
                  "aqi": 121,
                  "category": {"identifier": 3, "name": "Unhealthy for Sensitive Groups"},
                  "primaryPollutant": "PM2.5",
                  "observedAt": "2026-07-12T21:00:00Z",
                  "sourceIdentifier": "airnow"
                }
                """.utf8
            )
        )
        let gate = AsyncGate()
        let oldRunID = UUID()
        let runID = UUID()
        let oldSnapshot = HomeSnapshot(
            locationSnapshot: oldContext.snapshot,
            refreshKey: oldContext.refreshKey,
            stormSetup: oldStormSetup,
            airQuality: oldAirQuality,
            stormRisk: .slight
        )
        let coreSnapshot = HomeSnapshot(
            locationSnapshot: newContext.snapshot,
            refreshKey: newContext.refreshKey,
            stormRisk: .moderate
        )
        let coordinator = ScriptedStagedHomeIngestionCoordinator(
            runs: [
                .init(
                    core: .init(runID: oldRunID, stage: .core(.init(snapshot: oldSnapshot))),
                    enrichment: .init(
                        runID: oldRunID,
                        stage: .enrichment(.init(snapshot: oldSnapshot))
                    ),
                    finalSnapshot: oldSnapshot
                ),
                .init(
                    core: .init(runID: runID, stage: .core(.init(snapshot: coreSnapshot))),
                    enrichment: .init(
                        runID: runID,
                        stage: .enrichment(.init(snapshot: coreSnapshot))
                    ),
                    afterCoreGate: gate,
                    finalSnapshot: coreSnapshot
                )
            ]
        )
        let pipeline = HomeRefreshPipeline(initialStormRisk: .slight)
        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: FakeLocationSession(currentContext: oldContext, preparedContext: oldContext)
            )
        )
        #expect(pipeline.stormSetup == oldStormSetup)
        #expect(pipeline.airQuality == oldAirQuality)

        let task = Task { @MainActor in
            await pipeline.forceRefreshCurrentContext(
                showsLoading: true,
                environment: makeEnvironment(
                    coordinator: coordinator,
                    locationSession: FakeLocationSession(currentContext: newContext, preparedContext: newContext)
                )
            )
        }

        let coreVisible = await waitUntil(timeout: .seconds(5)) {
            pipeline.stormRisk == .moderate
        }
        #expect(coreVisible)
        #expect(pipeline.stormSetup == nil)
        #expect(pipeline.stormSetupRefreshKey == newContext.refreshKey)
        #expect(pipeline.airQuality == nil)

        await gate.open()
        await task.value
    }

    @Test("superseded same-location enrichment cannot overwrite a newer publication")
    func supersededSameLocationEnrichment_cannotOverwriteNewerPublication() async {
        let context = makeContext()
        let olderGate = AsyncGate()
        let olderRunID = UUID()
        let newerRunID = UUID()
        let olderStormSetup = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 500),
            summary: "older guidance"
        )
        let newerStormSetup = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 600),
            summary: "newer guidance"
        )
        let olderCore = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced
        )
        let olderFinal = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormSetup: olderStormSetup,
            stormRisk: .enhanced
        )
        let newerCore = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .moderate
        )
        let newerFinal = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormSetup: newerStormSetup,
            stormRisk: .moderate
        )
        let coordinator = ScriptedStagedHomeIngestionCoordinator(
            runs: [
                .init(
                    core: .init(runID: olderRunID, stage: .core(.init(snapshot: olderCore))),
                    enrichment: .init(
                        runID: olderRunID,
                        stage: .enrichment(.init(snapshot: olderFinal))
                    ),
                    afterCoreGate: olderGate,
                    finalSnapshot: olderFinal
                ),
                .init(
                    core: .init(runID: newerRunID, stage: .core(.init(snapshot: newerCore))),
                    enrichment: .init(
                        runID: newerRunID,
                        stage: .enrichment(.init(snapshot: newerFinal))
                    ),
                    finalSnapshot: newerFinal
                )
            ]
        )
        let pipeline = HomeRefreshPipeline(initialStormRisk: .slight)
        let environment = makeEnvironment(
            coordinator: coordinator,
            locationSession: FakeLocationSession(currentContext: context, preparedContext: context)
        )
        let olderTask = Task { @MainActor in
            await pipeline.forceRefreshCurrentContext(showsLoading: true, environment: environment)
        }

        let olderCoreVisible = await waitUntil(timeout: .seconds(5)) {
            pipeline.stormRisk == .enhanced
        }
        #expect(olderCoreVisible)

        await pipeline.forceRefreshCurrentContext(showsLoading: true, environment: environment)
        #expect(pipeline.stormRisk == .moderate)
        #expect(pipeline.stormSetup == newerStormSetup)

        await olderGate.open()
        await olderTask.value

        #expect(pipeline.stormRisk == .moderate)
        #expect(pipeline.stormSetup == newerStormSetup)
        #expect(pipeline.stormSetupRefreshKey == context.refreshKey)
    }

    @Test("same-location nil or failed storm setup preserves the existing value")
    func sameLocationNilOrFailurePreservesExistingStormSetup() async {
        let context = makeContext()
        let existingStormSetup = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 500),
            summary: "cached guidance"
        )
        let pipeline = HomeRefreshPipeline(
            initialStormSetup: existingStormSetup,
            initialStormSetupRefreshKey: context.refreshKey
        )
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let nilSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormSetup: nil,
            stormSetupRefreshResult: .timeout
        )
        let failureCoordinator = RecordingHomeIngestionCoordinator(snapshot: nilSnapshot)

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                coordinator: failureCoordinator,
                locationSession: locationSession
            )
        )

        #expect(pipeline.stormSetup == existingStormSetup)
        #expect(pipeline.stormSetupRefreshKey == context.refreshKey)

        let failureCoordinator2 = RecordingHomeIngestionCoordinator(
            snapshot: HomeSnapshot(
                locationSnapshot: context.snapshot,
                refreshKey: context.refreshKey,
                stormSetup: nil,
                stormSetupRefreshResult: .failure
            )
        )

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                coordinator: failureCoordinator2,
                locationSession: locationSession
            )
        )

        #expect(pipeline.stormSetup == existingStormSetup)
        #expect(pipeline.stormSetupRefreshKey == context.refreshKey)
    }

    @Test("different-location nil storm setup clears the previous value")
    func differentLocationNilStormSetupClearsPreviousValue() async {
        let oldContext = makeContext(h3Cell: 111_111)
        let newContext = makeContext(h3Cell: 222_222, timestamp: 200)
        let existingStormSetup = makeStormSetupDTO(
            h3Cell: oldContext.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 500)
        )
        let pipeline = HomeRefreshPipeline(
            initialStormSetup: existingStormSetup,
            initialStormSetupRefreshKey: oldContext.refreshKey
        )
        let coordinator = RecordingHomeIngestionCoordinator(
            snapshot: HomeSnapshot(
                locationSnapshot: newContext.snapshot,
                refreshKey: newContext.refreshKey,
                stormSetup: nil,
                stormSetupRefreshResult: .failure
            )
        )
        let locationSession = FakeLocationSession(currentContext: newContext, preparedContext: newContext)

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: locationSession
            )
        )

        #expect(pipeline.stormSetup == nil)
        #expect(pipeline.stormSetupRefreshKey == newContext.refreshKey)
    }

    @Test("prime snapshot keeps old storm setup ownership until a visible commit lands")
    func primeSnapshot_keepsOldStormSetupOwnershipUntilVisibleCommit() async {
        let oldContext = makeContext(h3Cell: 111_111)
        let newContext = makeContext(h3Cell: 222_222, timestamp: 200)
        let oldStormSetup = makeStormSetupDTO(
            h3Cell: oldContext.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 500)
        )
        let primeStormSetup = makeStormSetupDTO(
            h3Cell: newContext.h3Cell,
            expiresAt: Date(timeIntervalSince1970: 600),
            summary: "prime guidance"
        )
        let primeSnapshot = HomeSnapshot(
            locationSnapshot: newContext.snapshot,
            refreshKey: newContext.refreshKey,
            stormSetup: primeStormSetup,
            stormSetupRefreshResult: .success
        )
        let followUpGate = AsyncGate()
        let followUpSnapshot = HomeSnapshot(
            locationSnapshot: newContext.snapshot,
            refreshKey: newContext.refreshKey,
            stormSetup: nil,
            stormSetupRefreshResult: .failure
        )
        let coordinator = SequencedHomeIngestionCoordinator(
            snapshots: [primeSnapshot, followUpSnapshot],
            gates: [nil, followUpGate]
        )
        let locationSession = FakeLocationSession(currentContext: oldContext, preparedContext: newContext)
        let pipeline = HomeRefreshPipeline(
            initialStormSetup: oldStormSetup,
            initialStormSetupRefreshKey: oldContext.refreshKey
        )

        let refreshTask = Task { @MainActor in
            await pipeline.handleScenePhaseChange(
                .active,
                environment: makeEnvironment(
                    coordinator: coordinator,
                    locationSession: locationSession
                )
            )
        }

        let requestCountReached = await waitUntil(timeout: .seconds(5)) {
            await coordinator.requestCount() == 2
        }
        #expect(requestCountReached)
        #expect(pipeline.lastResolvedLocationScopedRefreshKey == newContext.refreshKey)
        #expect(pipeline.stormSetup == oldStormSetup)
        #expect(pipeline.stormSetupRefreshKey == oldContext.refreshKey)

        await followUpGate.open()
        await refreshTask.value
        await pipeline.waitForIdle()
    }

    @Test("visible alert commits update ownership and failures retain the prior visible alerts")
    func visibleAlertCommit_updatesOwnershipAndFailureRetainsPriorVisibleAlerts() async {
        let oldContext = makeContext(h3Cell: 111_111)
        let currentContext = makeContext(h3Cell: 222_222, timestamp: 200)
        let oldMeso = MD.sampleDiscussionDTOs[0]
        let newMeso = MD.sampleDiscussionDTOs[1]
        let oldAlert = Watch.sampleWatchRows[0]
        let newAlert = Watch.sampleWatchRows[1]
        let pipeline = HomeRefreshPipeline(
            initialAlertSnapshotRefreshKey: oldContext.refreshKey,
            initialMesos: [oldMeso],
            initialAlerts: [oldAlert]
        )
        let locationSession = FakeLocationSession(
            currentContext: currentContext,
            preparedContext: currentContext
        )

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                coordinator: RecordingHomeIngestionCoordinator(
                    snapshot: HomeSnapshot(
                        locationSnapshot: currentContext.snapshot,
                        refreshKey: currentContext.refreshKey,
                        stormSetupRefreshResult: .success,
                        mesos: [newMeso],
                        alerts: [newAlert]
                    )
                ),
                locationSession: locationSession
            )
        )

        #expect(pipeline.alertSnapshotRefreshKey == currentContext.refreshKey)
        #expect(pipeline.mesos == [newMeso])
        #expect(pipeline.alerts == [newAlert])

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                coordinator: RecordingHomeIngestionCoordinator(
                    results: [.failure(TestError.failed)]
                ),
                locationSession: locationSession
            )
        )

        #expect(pipeline.alertSnapshotRefreshKey == currentContext.refreshKey)
        #expect(pipeline.mesos == [newMeso])
        #expect(pipeline.alerts == [newAlert])
    }

    @Test("equivalent visible alert snapshots do not republish")
    func equivalentVisibleAlertSnapshots_doNotRepublish() {
        let context = makeContext()
        let meso = MD.sampleDiscussionDTOs[0]
        let alert = Watch.sampleWatchRows[0]
        let pipeline = HomeRefreshPipeline(
            initialAlertSnapshotRefreshKey: context.refreshKey,
            initialMesos: [meso],
            initialAlerts: [alert]
        )

        let published = pipeline.commitAlertSnapshotIfChanged(
            HomeAlertSnapshot(
                refreshKey: context.refreshKey,
                mesos: [meso],
                alerts: [alert]
            )
        )

        #expect(published == false)
        #expect(pipeline.alertSnapshotRefreshKey == context.refreshKey)
        #expect(pipeline.mesos == [meso])
        #expect(pipeline.alerts == [alert])
    }

    @Test("equivalent empty alert snapshots do not republish")
    func equivalentEmptyAlertSnapshots_doNotRepublish() {
        let context = makeContext()
        let pipeline = HomeRefreshPipeline(initialAlertSnapshotRefreshKey: context.refreshKey)

        let published = pipeline.commitAlertSnapshotIfChanged(
            HomeAlertSnapshot(refreshKey: context.refreshKey)
        )

        #expect(published == false)
        #expect(pipeline.alertSnapshotRefreshKey == context.refreshKey)
        #expect(pipeline.mesos.isEmpty)
        #expect(pipeline.alerts.isEmpty)
    }

    @Test("meaningful DTO changes still republish visible alert snapshots")
    func meaningfulDtoChanges_stillRepublishVisibleAlertSnapshots() {
        let context = makeContext()
        let originalMeso = MD.sampleDiscussionDTOs[0]
        let updatedMeso = makeUpdatedMeso(from: originalMeso, summary: "Updated guidance")
        let originalAlert = Watch.sampleWatchRows[0]
        var updatedAlert = originalAlert
        updatedAlert.currentRevisionSent = Date(timeIntervalSince1970: 999)
        let pipeline = HomeRefreshPipeline(
            initialAlertSnapshotRefreshKey: context.refreshKey,
            initialMesos: [originalMeso],
            initialAlerts: [originalAlert]
        )

        let published = pipeline.commitAlertSnapshotIfChanged(
            HomeAlertSnapshot(
                refreshKey: context.refreshKey,
                mesos: [updatedMeso],
                alerts: [updatedAlert]
            )
        )

        #expect(published)
        #expect(pipeline.mesos == [updatedMeso])
        #expect(pipeline.alerts == [updatedAlert])
    }

    @Test("active alerts can transition to an authoritative empty snapshot")
    func activeAlerts_canTransitionToAuthoritativeEmptySnapshot() {
        let context = makeContext()
        let pipeline = HomeRefreshPipeline(
            initialAlertSnapshotRefreshKey: context.refreshKey,
            initialMesos: [MD.sampleDiscussionDTOs[0]],
            initialAlerts: [Watch.sampleWatchRows[0]]
        )

        let published = pipeline.commitAlertSnapshotIfChanged(
            HomeAlertSnapshot(refreshKey: context.refreshKey)
        )

        #expect(published)
        #expect(pipeline.mesos.isEmpty)
        #expect(pipeline.alerts.isEmpty)
    }

    @Test("different contexts still commit even when alert collections match")
    func differentContexts_stillCommitEvenWhenAlertCollectionsMatch() {
        let oldContext = makeContext(h3Cell: 111_111)
        let newContext = makeContext(h3Cell: 222_222, timestamp: 200)
        let meso = MD.sampleDiscussionDTOs[0]
        let alert = Watch.sampleWatchRows[0]
        let pipeline = HomeRefreshPipeline(
            initialAlertSnapshotRefreshKey: oldContext.refreshKey,
            initialMesos: [meso],
            initialAlerts: [alert]
        )

        let published = pipeline.commitAlertSnapshotIfChanged(
            HomeAlertSnapshot(
                refreshKey: newContext.refreshKey,
                mesos: [meso],
                alerts: [alert]
            )
        )

        #expect(published)
        #expect(pipeline.alertSnapshotRefreshKey == newContext.refreshKey)
        #expect(pipeline.mesos == [meso])
        #expect(pipeline.alerts == [alert])
    }

    @Test("progress started keeps cached Today display state steady until snapshot commit")
    func progressStarted_keepsCachedTodayDisplayStateSteady() async {
        let context = makeContext()
        let weather = sampleWeather()
        let gate = AsyncGate()
        let coordinator = RecordingHomeIngestionCoordinator(
            runGate: gate,
            progressEvents: [
                .started(.lane(.weather))
            ]
        )
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline(
            initialSnap: context.snapshot,
            initialStormRisk: .slight,
            initialSevereRisk: .wind(probability: 0.15),
            initialFireRisk: .critical,
            initialMesos: [MD.sampleDiscussionDTOs[0]],
            initialAlerts: [Watch.sampleWatchRows[0]]
        )

        let refreshTask = Task { @MainActor in
            await pipeline.forceRefreshCurrentContext(
                showsLoading: true,
                environment: makeEnvironment(
                    coordinator: coordinator,
                    locationSession: locationSession
                )
            )
        }

        let started = await waitUntil(timeout: .seconds(5)) {
            pipeline.resolutionState.isResolving(.conditions)
        }
        #expect(started)
        #expect(pipeline.isRefreshInFlight)
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: pipeline.isRefreshInFlight,
                isOffline: false
            ) == .cachedRefreshing
        )

        let weatherState = TodayVisibleWeatherState.resolve(
            liveWeather: nil,
            displayedWeather: weather,
            isRefreshing: pipeline.isRefreshInFlight,
            displayedWeatherLocationIdentity: SummaryWeatherLocationIdentity(snapshot: context.snapshot),
            weatherLocationIdentity: SummaryWeatherLocationIdentity(snapshot: context.snapshot)
        )
        #expect(weatherState.weather == weather)

        await gate.open()
        await refreshTask.value
    }

    @Test("progress completion before snapshot commit does not clear cached Today display state")
    func progressCompleted_beforeSnapshotCommitKeepsCachedTodayDisplayState() async {
        let context = makeContext()
        let weather = sampleWeather()
        let gate = AsyncGate()
        let coordinator = RecordingHomeIngestionCoordinator(
            runGate: gate,
            progressEvents: [
                .started(.lane(.weather)),
                .completed(.lane(.weather))
            ]
        )
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline(
            initialSnap: context.snapshot,
            initialStormRisk: .slight,
            initialSevereRisk: .wind(probability: 0.15),
            initialFireRisk: .critical,
            initialMesos: [MD.sampleDiscussionDTOs[0]],
            initialAlerts: [Watch.sampleWatchRows[0]]
        )

        let refreshTask = Task { @MainActor in
            await pipeline.forceRefreshCurrentContext(
                showsLoading: true,
                environment: makeEnvironment(
                    coordinator: coordinator,
                    locationSession: locationSession
                )
            )
        }

        let progressCompleted = await waitUntil(timeout: .seconds(5)) {
            pipeline.resolutionState.isResolving(.conditions) == false && pipeline.isRefreshInFlight
        }
        #expect(progressCompleted)
        #expect(pipeline.resolutionState.isResolving(.conditions) == false)
        #expect(pipeline.isRefreshInFlight)
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: pipeline.isRefreshInFlight,
                isOffline: false
            ) == .cachedRefreshing
        )

        let weatherState = TodayVisibleWeatherState.resolve(
            liveWeather: nil,
            displayedWeather: weather,
            isRefreshing: pipeline.isRefreshInFlight,
            displayedWeatherLocationIdentity: SummaryWeatherLocationIdentity(snapshot: context.snapshot),
            weatherLocationIdentity: SummaryWeatherLocationIdentity(snapshot: context.snapshot)
        )
        #expect(weatherState.weather == weather)

        await gate.open()
        await refreshTask.value
    }

    @Test("completed progress clears mapped sections before refresh completion")
    func completedProgress_clearsMappedSectionsBeforeRefreshCompletion() async {
        let gate = AsyncGate()
        let coordinator = RecordingHomeIngestionCoordinator(
            runGate: gate,
            progressEvents: [
                .started(.lane(.hotAlerts)),
                .completed(.lane(.hotAlerts)),
            ]
        )
        let locationSession = FakeLocationSession(currentContext: makeContext(), preparedContext: makeContext())
        let pipeline = HomeRefreshPipeline()

        let refreshTask = Task { @MainActor in
            await pipeline.forceRefreshCurrentContext(
                showsLoading: true,
                environment: makeEnvironment(
                    coordinator: coordinator,
                    locationSession: locationSession
                )
            )
        }

        let completedProgressObserved = await waitUntil(timeout: .seconds(5)) {
            await coordinator.progressHistory().contains(.completed(.lane(.hotAlerts)))
        }
        #expect(completedProgressObserved)
        #expect(pipeline.resolutionState.isRefreshing)
        #expect(pipeline.resolutionState.isResolving(.alerts) == false)

        await gate.open()
        await refreshTask.value

        #expect(pipeline.resolutionState.isRefreshing == false)
    }

    @Test("failed force refresh clears resolving state")
    func forceRefreshFailure_clearsResolvingState() async {
        let coordinator = RecordingHomeIngestionCoordinator(
            results: [.failure(TestFailure.failedRead)]
        )
        let locationSession = FakeLocationSession(currentContext: makeContext(), preparedContext: makeContext())
        let pipeline = HomeRefreshPipeline()

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: locationSession
            )
        )

        #expect(pipeline.resolutionState.isRefreshing == false)
        for section in SummarySection.resolveForwardSections {
            #expect(pipeline.resolutionState.isResolving(section) == false)
        }
    }

    @Test("visible refresh clears stale weather when snapshot omits weather")
    func visibleRefresh_clearsStaleWeatherWhenSnapshotOmitsWeather() async {
        let context = makeContext()
        let staleWeather = sampleWeather()
        let coordinator = RecordingHomeIngestionCoordinator(
            snapshot: HomeSnapshot(
                locationSnapshot: context.snapshot,
                refreshKey: context.refreshKey,
                weather: nil,
                weatherRefreshResult: .success(nil)
            )
        )
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline()
        pipeline.summaryWeather = staleWeather

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: locationSession
            )
        )

        #expect(pipeline.summaryWeather == nil)
    }

    @Test("timer refresh preserves stale weather when weather lane is skipped")
    func timerRefresh_preservesStaleWeatherWhenWeatherLaneIsSkipped() async {
        let context = makeContext()
        let staleWeather = sampleWeather()
        let coordinator = RecordingHomeIngestionCoordinator(
            snapshot: HomeSnapshot(
                locationSnapshot: context.snapshot,
                refreshKey: context.refreshKey,
                weather: nil,
                weatherRefreshResult: .skipped
            )
        )
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline()
        pipeline.summaryWeather = staleWeather

        await pipeline.enqueueRefresh(
            .timer,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: locationSession
            )
        )
        await pipeline.waitForIdle()

        #expect(pipeline.summaryWeather == staleWeather)
    }

    @Test("visible refresh preserves stale weather when weather fetch fails")
    func visibleRefresh_preservesStaleWeatherWhenWeatherFetchFails() async {
        let context = makeContext()
        let staleWeather = sampleWeather()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let weather = FakeWeatherClient(result: .failure)
        let pipeline = HomeRefreshPipeline()
        pipeline.summaryWeather = staleWeather

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                weather: weather,
                locationSession: locationSession
            )
        )

        #expect(pipeline.summaryWeather == staleWeather)
        #expect(await weather.callCount() == 1)
    }

    @Test("visible refresh clears stale weather after a location change when weather fetch fails")
    func visibleRefresh_clearsStaleWeatherAfterLocationChangeWhenWeatherFetchFails() async {
        let oldContext = makeContext()
        let newContext = makeContext(
            latitude: 39.93,
            longitude: -104.61,
            h3Cell: 222_222,
            timestamp: 200
        )
        let staleWeather = sampleWeather()
        let coordinator = SequencedHomeIngestionCoordinator(
            snapshots: [
                HomeSnapshot(
                    locationSnapshot: oldContext.snapshot,
                    refreshKey: oldContext.refreshKey,
                    weather: staleWeather,
                    weatherRefreshResult: .success(staleWeather)
                ),
                HomeSnapshot(
                    locationSnapshot: newContext.snapshot,
                    refreshKey: newContext.refreshKey,
                    weather: nil,
                    weatherRefreshResult: .failure
                )
            ],
            gates: []
        )
        let locationSession = FakeLocationSession(currentContext: oldContext, preparedContext: oldContext)
        let pipeline = HomeRefreshPipeline()
        pipeline.summaryWeather = staleWeather

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: locationSession
            )
        )

        locationSession.currentContext = newContext
        locationSession.preparedContext = newContext

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: locationSession
            )
        )

        #expect(pipeline.summaryWeather == nil)
        #expect(await coordinator.requestCount() == 2)
    }

    @Test("timer refresh keeps sync work on the hot-alert lane")
    func timerRefresh_syncsHotFeedsOnly() async {
        let context = makeContext()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: nil)
        let spc = FakeSpcProvider(outlooks: sampleOutlooks())
        let alerts = FakeAlertProvider()
        let weather = FakeWeatherClient()
        let pipeline = HomeRefreshPipeline()

        await pipeline.enqueueRefresh(
            .timer,
            environment: makeEnvironment(
                spc: spc,
                alerts: alerts,
                weather: weather,
                locationSession: locationSession
            )
        )
        await pipeline.waitForIdle()

        #expect(locationSession.prepareCalls.isEmpty)
        #expect(await spc.syncMesoscaleDiscussionsCount() == 1)
        #expect(await alerts.syncCount() == 1)
        #expect(await spc.syncMapProductsCount() == 0)
        #expect(await spc.syncConvectiveOutlooksCount() == 0)
        #expect(await weather.callCount() == 0)
    }

    @Test("scene active refresh persists projection slices through the unified flow")
    func sceneActiveRefresh_persistsProjectionSlices() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let projectionStore = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let weatherValue = sampleWeather()
        let meso = MD.sampleDiscussionDTOs[1]
        let alert = Watch.sampleWatchRows[1]
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let spc = FakeSpcProvider(activeMesos: [meso], outlooks: sampleOutlooks())
        let alerts = FakeAlertProvider(activeAlerts: [alert])
        let weather = FakeWeatherClient(weather: weatherValue)
        let pipeline = HomeRefreshPipeline()

        await pipeline.handleScenePhaseChange(
            .active,
            environment: makeEnvironment(
                spc: spc,
                alerts: alerts,
                weather: weather,
                locationSession: locationSession,
                homeProjectionStore: projectionStore
            )
        )
        await pipeline.waitForIdle()

        let projection = try await projectionStore.projection(for: context)
        let stored = try #require(projection)

        #expect(stored.weather == weatherValue)
        #expect(stored.stormRisk == .enhanced)
        #expect(stored.severeRisk == .hail(probability: 0.30))
        #expect(stored.fireRisk == .elevated)
        #expect(stored.activeMesos == [meso])
        #expect(stored.activeAlerts == [alert])
    }

    @Test("scene active refresh persists empty alert slices for the resolved context")
    func sceneActiveRefresh_persistsEmptyAlertSlices() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let projectionStore = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let spc = FakeSpcProvider(outlooks: sampleOutlooks())
        let alerts = FakeAlertProvider(activeAlerts: [])
        let weather = FakeWeatherClient()
        let pipeline = HomeRefreshPipeline()

        await pipeline.handleScenePhaseChange(
            .active,
            environment: makeEnvironment(
                spc: spc,
                alerts: alerts,
                weather: weather,
                locationSession: locationSession,
                homeProjectionStore: projectionStore
            )
        )
        await pipeline.waitForIdle()

        let projection = try #require(await projectionStore.projection(for: context))
//        #expect(projection.activeMesos.isEmpty)
        #expect(projection.activeAlerts.isEmpty)
        #expect(projection.lastHotAlertsLoadAt != nil)
        #expect(pipeline.lastResolvedLocationScopedRefreshKey == context.refreshKey)
    }

    @Test("prime refresh keeps the visible summary stable until the follow-up commit lands")
    func sceneActiveRefresh_keepsVisibleSummaryStableDuringPrimeBatch() async throws {
        let context = makeContext()
        let primeSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .hail(probability: 0.30),
            fireRisk: .elevated,
            outlooks: sampleOutlooks(),
            latestOutlook: sampleOutlooks().first
        )
        let finalSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .moderate,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            outlooks: sampleOutlooks(),
            latestOutlook: sampleOutlooks().last
        )
        let followUpGate = AsyncGate()
        let coordinator = SequencedHomeIngestionCoordinator(
            snapshots: [primeSnapshot, finalSnapshot],
            gates: [nil, followUpGate]
        )
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline(
            initialSnap: context.snapshot,
            initialStormRisk: .slight,
            initialSevereRisk: .wind(probability: 0.15),
            initialFireRisk: .critical,
            initialMesos: [MD.sampleDiscussionDTOs[0]],
            initialAlerts: [Watch.sampleWatchRows[0]],
            initialOutlooks: sampleOutlooks(),
            initialOutlook: sampleOutlooks().first
        )
        let environment = makeEnvironment(
            coordinator: coordinator,
            locationSession: locationSession
        )

        await pipeline.handleScenePhaseChange(.active, environment: environment)

        let followUpStarted = await waitUntil(timeout: .seconds(5)) {
            await coordinator.requestCount() == 2
        }
        #expect(followUpStarted)
        #expect(pipeline.stormRisk == .slight)
        #expect(pipeline.severeRisk == .wind(probability: 0.15))
        #expect(pipeline.fireRisk == .critical)
        #expect(pipeline.resolutionState.isRefreshing)

        await followUpGate.open()
        await pipeline.waitForIdle()

        #expect(pipeline.stormRisk == .moderate)
        #expect(pipeline.severeRisk == .tornado(probability: 0.10))
        #expect(pipeline.fireRisk == .critical)
        #expect(pipeline.lastResolvedLocationScopedRefreshKey == context.refreshKey)
        #expect(pipeline.resolutionState.isRefreshing == false)
    }

    @Test("failed location-scoped reads keep the existing cached projection without marking the context resolved")
    func locationScopedReadFailure_preservesExistingProjection() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let projectionStore = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let weatherValue = sampleWeather()
        let originalAlert = Watch.sampleWatchRows[0]
        let originalMeso = MD.sampleDiscussionDTOs[0]

        _ = try await projectionStore.updateWeather(
            weatherValue,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 200)
        )
        _ = try await projectionStore.updateSlowProducts(
            stormRisk: .slight,
            severeRisk: .wind(probability: 0.15),
            fireRisk: .critical,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 210)
        )
        _ = try await projectionStore.updateHotAlerts(
            alerts: [originalAlert],
            mesos: [originalMeso],
            for: context,
            loadedAt: Date(timeIntervalSince1970: 220)
        )

        let pipeline = HomeRefreshPipeline(
            initialStormRisk: .slight,
            initialSevereRisk: .wind(probability: 0.15),
            initialFireRisk: .critical,
            initialMesos: [originalMeso],
            initialAlerts: [originalAlert]
        )
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let spc = FakeSpcProvider(outlooks: sampleOutlooks(), locationReadError: TestFailure.failedRead)
        let alerts = FakeAlertProvider(activeAlerts: [Watch.sampleWatchRows[1]])
        let weather = FakeWeatherClient()

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                spc: spc,
                alerts: alerts,
                weather: weather,
                locationSession: locationSession,
                homeProjectionStore: projectionStore
            )
        )

        let projection = try await projectionStore.projection(for: context)
        let stored = try #require(projection)

        #expect(stored.weather == weatherValue)
        #expect(stored.stormRisk == .slight)
        #expect(stored.severeRisk == .wind(probability: 0.15))
        #expect(stored.fireRisk == .critical)
        #expect(stored.activeAlerts == [originalAlert])
        #expect(stored.activeMesos == [originalMeso])
        #expect(pipeline.stormRisk == .slight)
        #expect(pipeline.severeRisk == .wind(probability: 0.15))
        #expect(pipeline.fireRisk == .critical)
        #expect(pipeline.mesos == [originalMeso])
        #expect(pipeline.alerts == [originalAlert])
        #expect(pipeline.lastResolvedLocationScopedRefreshKey == nil)
    }

    @Test("rejected slow-product sync preserves projection, widgets, and retry cadence")
    func slowProductRefresh_rejectedSyncPreservesProjectionWidgetsAndRetryCadence() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let projectionStore = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let previousTimestamp = Date(timeIntervalSince1970: 200)
        let widgetRecorder = RecordingWidgetSnapshotRefresher()

        _ = try await projectionStore.updateSlowProducts(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.15),
            fireRisk: .critical,
            for: context,
            loadedAt: previousTimestamp
        )

        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let spc = FakeSpcProvider(
            activeMesos: [],
            outlooks: sampleOutlooks(),
            mapSyncOutcome: .rejected,
            stormRiskValue: .allClear,
            severeRiskValue: .allClear,
            fireRiskValue: .clear
        )
        let alerts = FakeAlertProvider(activeAlerts: [])
        let weather = FakeWeatherClient()
        let snapshotStore = HomeSnapshotStore(spcRisk: spc, spcOutlook: spc, arcusAlerts: alerts)
        let executor = HomeIngestionExecutor(
            environment: .init(
                logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
                spcSync: spc,
                arcusAlertSync: alerts,
                weatherClient: weather,
                locationSession: locationSession,
                snapshotStore: snapshotStore,
                projectionStore: projectionStore,
                widgetSnapshotRefresher: widgetRecorder
            )
        )
        _ = try await executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .backgroundRefresh)),
            progress: .none
        )
        _ = try await executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .backgroundRefresh)),
            progress: .none
        )

        let projection = try #require(await projectionStore.projection(for: context))
        #expect(projection.stormRisk == .slight)
        #expect(projection.severeRisk == .tornado(probability: 0.15))
        #expect(projection.fireRisk == .critical)
        #expect(projection.lastSlowProductsLoadAt == previousTimestamp)
        #expect(widgetRecorder.refreshCallCount() == 0)
        #expect(await spc.syncMapProductsCount() == 2)
    }

    @Test("hot-alert providers overlap and join before completion")
    func hotAlertSync_overlapsProvidersAndJoinsBeforeCompletion() async throws {
        let context = makeContext()
        let mesoGate = AsyncGate()
        let alertGate = AsyncGate()
        let spc = FakeSpcProvider(syncMesoscaleGate: mesoGate)
        let alerts = FakeAlertProvider(syncGate: alertGate)
        let recorder = IngestionProgressRecorder()
        let executor = HomeIngestionExecutor(
            environment: .init(
                logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
                spcSync: spc,
                arcusAlertSync: alerts,
                weatherClient: FakeWeatherClient(),
                locationSession: FakeLocationSession(currentContext: context, preparedContext: context),
                snapshotStore: HomeSnapshotStore(spcRisk: spc, spcOutlook: spc, arcusAlerts: alerts),
                projectionStore: nil,
                widgetSnapshotRefresher: nil
            )
        )
        let task = Task {
            try await executor.run(
                plan: HomeIngestionPlan(request: .init(trigger: .sessionTick)),
                progress: .init(
                    markHotAlertsCompleted: { await recorder.markHotAlertsCompleted() },
                    report: { event in
                        if case .completed(.lane(.hotAlerts)) = event {
                            await recorder.recordHotLaneCompletion()
                        }
                    }
                )
            )
        }

        let hotProvidersStarted = await waitUntil {
            let mesoStarted = await spc.syncMesoscaleDiscussionsCount() == 1
            let alertStarted = await alerts.syncCount() == 1
            return mesoStarted && alertStarted
        }
        #expect(hotProvidersStarted)
        let hotAlertsMarkedBeforeRelease = await recorder.isHotAlertsMarked()
        #expect(hotAlertsMarkedBeforeRelease == false)
        await mesoGate.open()
        let mesoFinishedWithoutAlert = await waitUntil { await spc.syncMesoscaleDiscussionsCount() == 1 }
        #expect(mesoFinishedWithoutAlert)
        let hotAlertsMarkedAfterOneRelease = await recorder.isHotAlertsMarked()
        #expect(hotAlertsMarkedAfterOneRelease == false)
        await alertGate.open()
        _ = try await task.value

        let hotLaneCompletedBeforeMark = await recorder.hotLaneCompletedBeforeMark()
        let hotAlertsMarked = await recorder.isHotAlertsMarked()
        #expect(hotLaneCompletedBeforeMark)
        #expect(hotAlertsMarked)
        let hotSpcModes = await spc.observedHTTPModes()
        let hotAlertModes = await alerts.observedHTTPModes()
        #expect(hotSpcModes == [.foreground])
        #expect(hotAlertModes == [.foreground])
    }

    @Test("slow-product providers overlap, join, and preserve map outcome")
    func slowProductSync_overlapsProvidersAndPreservesMapOutcome() async throws {
        let context = makeContext()
        let mapGate = AsyncGate()
        let outlookGate = AsyncGate()
        let spc = FakeSpcProvider(
            mapSyncGate: mapGate,
            convectiveOutlookGate: outlookGate,
            mapSyncOutcome: .accepted
        )
        let alerts = FakeAlertProvider(activeAlerts: [])
        let recorder = IngestionProgressRecorder()
        let executor = HomeIngestionExecutor(
            environment: .init(
                logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
                spcSync: spc,
                arcusAlertSync: alerts,
                weatherClient: FakeWeatherClient(),
                locationSession: FakeLocationSession(currentContext: context, preparedContext: context),
                snapshotStore: HomeSnapshotStore(spcRisk: spc, spcOutlook: spc, arcusAlerts: alerts),
                projectionStore: nil,
                widgetSnapshotRefresher: nil
            )
        )
        var plan = HomeIngestionPlan(request: .init(trigger: .sessionTick))
        plan.lanes = [.slowProducts]
        plan.forcedLanes = [.slowProducts]
        plan.provenance = .manualRefresh
        let task = Task {
            try await executor.run(
                plan: plan,
                progress: .init(
                    markHotAlertsCompleted: {},
                    report: { event in
                        if case .completed(.lane(.slowProducts)) = event {
                            await recorder.recordSlowLaneCompletion()
                        }
                    }
                )
            )
        }

        let slowProvidersStarted = await waitUntil {
            let mapStarted = await spc.syncMapProductsCount() == 1
            let outlookStarted = await spc.syncConvectiveOutlooksCount() == 1
            return mapStarted && outlookStarted
        }
        #expect(slowProvidersStarted)
        let slowLaneCompletedBeforeRelease = await recorder.isSlowLaneCompleted()
        #expect(slowLaneCompletedBeforeRelease == false)
        await mapGate.open()
        let slowLaneCompletedAfterMapRelease = await recorder.isSlowLaneCompleted()
        #expect(slowLaneCompletedAfterMapRelease == false)
        await outlookGate.open()
        let snapshot = try await task.value

        #expect(snapshot.refreshKey == context.refreshKey)
        let slowLaneCompleted = await recorder.isSlowLaneCompleted()
        #expect(slowLaneCompleted)
        let slowSpcModes = await spc.observedHTTPModes()
        #expect(slowSpcModes == [.foreground, .foreground])
    }

    @Test("cancelling a hot sync joins both cancelled provider children")
    func hotAlertSync_cancellationJoinsBothChildren() async throws {
        let context = makeContext()
        let mesoGate = AsyncGate()
        let alertGate = AsyncGate()
        let spc = FakeSpcProvider(syncMesoscaleGate: mesoGate)
        let alerts = FakeAlertProvider(syncGate: alertGate)
        let executor = HomeIngestionExecutor(
            environment: .init(
                logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
                spcSync: spc,
                arcusAlertSync: alerts,
                weatherClient: FakeWeatherClient(),
                locationSession: FakeLocationSession(currentContext: context, preparedContext: context),
                snapshotStore: HomeSnapshotStore(spcRisk: spc, spcOutlook: spc, arcusAlerts: alerts),
                projectionStore: nil,
                widgetSnapshotRefresher: nil
            )
        )
        let task = Task {
            try await executor.run(
                plan: HomeIngestionPlan(request: .init(trigger: .sessionTick)),
                progress: .none
            )
        }

        let providersStarted = await waitUntil {
            let mesoStarted = await spc.syncMesoscaleDiscussionsCount() == 1
            let alertStarted = await alerts.syncCount() == 1
            return mesoStarted && alertStarted
        }
        #expect(providersStarted)
        task.cancel()
        await mesoGate.open()
        await alertGate.open()
        _ = try await task.value

        let spcCancellationCount = await spc.cancelledSyncCount()
        let alertCancellationCount = await alerts.cancelledSyncCount()
        #expect(spcCancellationCount == 1)
        #expect(alertCancellationCount == 1)
    }

    @Test("failed slow-product sync preserves projection, widgets, and retry cadence")
    func slowProductRefresh_failedSyncPreservesProjectionWidgetsAndRetryCadence() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let projectionStore = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let previousTimestamp = Date(timeIntervalSince1970: 200)
        let widgetRecorder = RecordingWidgetSnapshotRefresher()

        _ = try await projectionStore.updateSlowProducts(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.15),
            fireRisk: .critical,
            for: context,
            loadedAt: previousTimestamp
        )

        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let spc = FakeSpcProvider(
            activeMesos: [],
            outlooks: sampleOutlooks(),
            mapSyncOutcome: .failed,
            stormRiskValue: .allClear,
            severeRiskValue: .allClear,
            fireRiskValue: .clear
        )
        let alerts = FakeAlertProvider(activeAlerts: [])
        let weather = FakeWeatherClient()
        let snapshotStore = HomeSnapshotStore(spcRisk: spc, spcOutlook: spc, arcusAlerts: alerts)
        let executor = HomeIngestionExecutor(
            environment: .init(
                logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
                spcSync: spc,
                arcusAlertSync: alerts,
                weatherClient: weather,
                locationSession: locationSession,
                snapshotStore: snapshotStore,
                projectionStore: projectionStore,
                widgetSnapshotRefresher: widgetRecorder
            )
        )
        _ = try await executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .backgroundRefresh)),
            progress: .none
        )
        _ = try await executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .backgroundRefresh)),
            progress: .none
        )

        let projection = try #require(await projectionStore.projection(for: context))
        #expect(projection.stormRisk == .slight)
        #expect(projection.severeRisk == .tornado(probability: 0.15))
        #expect(projection.fireRisk == .critical)
        #expect(projection.lastSlowProductsLoadAt == previousTimestamp)
        #expect(widgetRecorder.refreshCallCount() == 0)
        #expect(await spc.syncMapProductsCount() == 2)
    }

    @Test("accepted slow-product all-clear updates projection and refreshes widgets")
    func slowProductRefresh_acceptedAllClearUpdatesProjectionAndWidgets() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let projectionStore = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let previousTimestamp = Date(timeIntervalSince1970: 200)
        let widgetRecorder = RecordingWidgetSnapshotRefresher()

        _ = try await projectionStore.updateSlowProducts(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.15),
            fireRisk: .critical,
            for: context,
            loadedAt: previousTimestamp
        )

        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let spc = FakeSpcProvider(
            activeMesos: [],
            outlooks: sampleOutlooks(),
            mapSyncOutcome: .accepted,
            stormRiskValue: .allClear,
            severeRiskValue: .allClear,
            fireRiskValue: .clear
        )
        let alerts = FakeAlertProvider(activeAlerts: [])
        let weather = FakeWeatherClient()
        let snapshotStore = HomeSnapshotStore(spcRisk: spc, spcOutlook: spc, arcusAlerts: alerts)
        let executor = HomeIngestionExecutor(
            environment: .init(
                logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
                spcSync: spc,
                arcusAlertSync: alerts,
                weatherClient: weather,
                locationSession: locationSession,
                snapshotStore: snapshotStore,
                projectionStore: projectionStore,
                widgetSnapshotRefresher: widgetRecorder
            )
        )
        _ = try await executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .backgroundRefresh)),
            progress: .none
        )

        let projection = try #require(await projectionStore.projection(for: context))
        #expect(projection.stormRisk == .allClear)
        #expect(projection.severeRisk == .allClear)
        #expect(projection.fireRisk == .clear)
        #expect(projection.lastSlowProductsLoadAt != previousTimestamp)
        #expect(widgetRecorder.refreshCallCount() == 1)
    }

    @Test("refresh failures preserve the previously resolved location scope key")
    func refreshFailure_preservesPreviousResolvedLocationScopeKey() async {
        let originalContext = makeContext(timestamp: 100)
        let changedContext = makeContext(timestamp: 200)
        let successSnapshot = HomeSnapshot(
            locationSnapshot: originalContext.snapshot,
            refreshKey: originalContext.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .hail(probability: 0.30),
            fireRisk: .elevated,
            outlooks: sampleOutlooks(),
            latestOutlook: sampleOutlooks().first
        )
        let coordinator = RecordingHomeIngestionCoordinator(
            results: [
                .success(successSnapshot),
                .failure(TestFailure.failedRead)
            ]
        )
        let locationSession = FakeLocationSession(currentContext: originalContext, preparedContext: originalContext)
        let pipeline = HomeRefreshPipeline()
        let environment = makeEnvironment(coordinator: coordinator, locationSession: locationSession)

        await pipeline.handleScenePhaseChange(.active, environment: environment)
        await pipeline.waitForIdle()

        #expect(pipeline.lastResolvedLocationScopedRefreshKey == originalContext.refreshKey)

        locationSession.currentContext = changedContext
        await pipeline.enqueueRefresh(.contextChanged, environment: environment)
        await pipeline.waitForIdle()

        #expect(pipeline.lastResolvedLocationScopedRefreshKey == originalContext.refreshKey)
    }

    @Test("manual outlook refresh only touches outlook sync and query paths")
    func refreshOutlooksManually_onlyTouchesOutlookPaths() async {
        let coordinator = RecordingHomeIngestionCoordinator()
        let spc = FakeSpcProvider(outlooks: sampleOutlooks())
        let locationSession = FakeLocationSession(currentContext: makeContext(), preparedContext: makeContext())
        let pipeline = HomeRefreshPipeline()

        await pipeline.refreshOutlooksManually(
            environment: makeEnvironment(
                spc: spc,
                coordinator: coordinator,
                locationSession: locationSession
            )
        )

        #expect(await spc.syncConvectiveOutlooksCount() == 1)
        #expect(await spc.outlookQueryCount() == 1)
        #expect(await spc.syncMapProductsCount() == 0)
        #expect(await spc.syncMesoscaleDiscussionsCount() == 0)
        #expect(await coordinator.requestCount() == 0)
        #expect(pipeline.outlooks.map(\.title) == sampleOutlooks().map(\.title))
        #expect(pipeline.outlook?.title == "Day 2 Convective Outlook")
    }

    @Test("foreground outlook refresh marks empty results as completed")
    func foregroundOutlookRefresh_marksEmptyResultsAsCompleted() async {
        let context = makeContext()
        let spc = FakeSpcProvider(outlooks: [])
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline()

        await pipeline.handleScenePhaseChange(
            .active,
            environment: makeEnvironment(
                spc: spc,
                locationSession: locationSession
            )
        )
        await pipeline.waitForIdle()

        #expect(pipeline.outlooks.isEmpty)
        #expect(pipeline.outlook == nil)
        #expect(pipeline.outlookRefreshStatus == .success(hasContent: false))
    }

    @Test("background location change resolves from latest accepted snapshot instead of stale current context")
    func backgroundLocationChange_resolvesLatestAcceptedSnapshot() async throws {
        let oldSnapshot = LocationSnapshot(
            coordinates: .init(latitude: 39.75, longitude: -104.44),
            timestamp: Date(timeIntervalSince1970: 100),
            accuracy: 25,
            placemarkSummary: "Bennett, CO",
            h3Cell: 111_111
        )
        let oldGrid = GridPointSnapshot(
            nwsId: "BOU/10,20",
            latitude: oldSnapshot.coordinates.latitude,
            longitude: oldSnapshot.coordinates.longitude,
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
            countyCode: "COC005",
            fireZone: "COZ214",
            countyLabel: "Arapahoe",
            fireZoneLabel: "Front Range"
        )
        let oldContext = LocationContext(snapshot: oldSnapshot, h3Cell: 111_111, grid: oldGrid)

        let freshSnapshot = LocationSnapshot(
            coordinates: .init(latitude: 40.01, longitude: -104.10),
            timestamp: Date(timeIntervalSince1970: 200),
            accuracy: 20,
            placemarkSummary: "Weld County, CO",
            h3Cell: 222_222
        )
        let freshGrid = GridPointSnapshot(
            nwsId: "BOU/22,30",
            latitude: freshSnapshot.coordinates.latitude,
            longitude: freshSnapshot.coordinates.longitude,
            gridId: "BOU",
            gridX: 22,
            gridY: 30,
            forecastURL: nil,
            forecastHourlyURL: nil,
            forecastGridDataURL: nil,
            observationStationsURL: nil,
            city: "Brighton",
            state: "CO",
            timeZoneId: "America/Denver",
            radarStationId: nil,
            forecastZone: "COZ040",
            countyCode: "COC123",
            fireZone: "COZ250",
            countyLabel: "Weld",
            fireZoneLabel: "Northeast Plains"
        )
        let freshContext = LocationContext(snapshot: freshSnapshot, h3Cell: 222_222, grid: freshGrid)

        let locationSession = FakeLocationSession(currentContext: oldContext, preparedContext: freshContext)
        let spc = FakeSpcProvider()
        let alerts = FakeAlertProvider()
        let weather = FakeWeatherClient()
        let snapshotStore = HomeSnapshotStore(spcRisk: spc, spcOutlook: spc, arcusAlerts: alerts)
        let executor = HomeIngestionExecutor(
            environment: .init(
                logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
                spcSync: spc,
                arcusAlertSync: alerts,
                weatherClient: weather,
                locationSession: locationSession,
                snapshotStore: snapshotStore,
                projectionStore: nil,
                widgetSnapshotRefresher: nil
            )
        )

        let snapshot = try await executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .backgroundLocationChange))
        )

        #expect(locationSession.prepareCalls.count == 1)
        #expect(
            locationSession.prepareCalls[0] == .init(
                requiresFreshLocation: false,
                showsAuthorizationPrompt: false,
                uploadSource: .backgroundLocationChange,
                uploadReason: .locationChanged
            )
        )
        #expect(snapshot.locationSnapshot == freshContext.snapshot)
        #expect(snapshot.refreshKey == freshContext.refreshKey)
    }

    @Test("ingestion trigger location preparation carries deterministic upload source and reason")
    func ingestionTrigger_locationPreparationCarriesExpectedUploadSourceAndReason() async throws {
        let cases: [(HomeRefreshTrigger, LocationUploadSource, LocationUploadReason)] = [
            (.foregroundActivate, .foregroundActivate, .locationResolved),
            (.manualRefresh, .manualRefresh, .locationResolved),
            (.foregroundLocationChange, .foregroundLocationChange, .locationChanged),
            (.backgroundRefresh, .backgroundRefresh, .locationResolved),
            (.backgroundLocationChange, .backgroundLocationChange, .locationChanged)
        ]

        for testCase in cases {
            let locationSession = FakeLocationSession(currentContext: nil, preparedContext: makeContext())
            let spc = FakeSpcProvider()
            let alerts = FakeAlertProvider()
            let weather = FakeWeatherClient()
            let snapshotStore = HomeSnapshotStore(spcRisk: spc, spcOutlook: spc, arcusAlerts: alerts)
            let executor = HomeIngestionExecutor(
                environment: .init(
                    logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
                    spcSync: spc,
                    arcusAlertSync: alerts,
                    weatherClient: weather,
                    locationSession: locationSession,
                    snapshotStore: snapshotStore,
                    projectionStore: nil,
                    widgetSnapshotRefresher: nil
                )
            )

            _ = try await executor.run(
                plan: HomeIngestionPlan(request: .init(trigger: testCase.0))
            )

            let prepareCall = try #require(locationSession.prepareCalls.first)
            #expect(prepareCall.uploadSource == testCase.1)
            #expect(prepareCall.uploadReason == testCase.2)
        }
    }

    @Test("session tick continues reusing current prepared context")
    func sessionTick_reusesCurrentPreparedContext() async throws {
        let currentContext = makeContext(timestamp: 100)
        let newerPreparedContext = makeContext(timestamp: 200)
        let locationSession = FakeLocationSession(currentContext: currentContext, preparedContext: newerPreparedContext)
        let spc = FakeSpcProvider()
        let alerts = FakeAlertProvider()
        let weather = FakeWeatherClient()
        let snapshotStore = HomeSnapshotStore(spcRisk: spc, spcOutlook: spc, arcusAlerts: alerts)
        let executor = HomeIngestionExecutor(
            environment: .init(
                logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
                spcSync: spc,
                arcusAlertSync: alerts,
                weatherClient: weather,
                locationSession: locationSession,
                snapshotStore: snapshotStore,
                projectionStore: nil,
                widgetSnapshotRefresher: nil
            )
        )

        let snapshot = try await executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .sessionTick))
        )

        #expect(locationSession.prepareCalls.isEmpty)
        #expect(snapshot.locationSnapshot == currentContext.snapshot)
        #expect(snapshot.refreshKey == currentContext.refreshKey)
    }

    private func makeEnvironment(
        spc: FakeSpcProvider = FakeSpcProvider(),
        alerts: FakeAlertProvider = FakeAlertProvider(),
        weather: FakeWeatherClient = FakeWeatherClient(),
        coordinator: (any HomeIngestionCoordinating)? = nil,
        locationSession: FakeLocationSession,
        homeProjectionStore: HomeProjectionStore? = nil
    ) -> HomeRefreshPipeline.Environment {
        .init(
            logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
            sync: spc,
            outlooks: spc,
            coordinator: coordinator ?? makeCoordinator(
                spc: spc,
                alerts: alerts,
                weather: weather,
                locationSession: locationSession,
                homeProjectionStore: homeProjectionStore
            ),
            locationSession: locationSession
        )
    }

    private func makeCoordinator(
        spc: FakeSpcProvider,
        alerts: FakeAlertProvider,
        weather: FakeWeatherClient,
        locationSession: FakeLocationSession,
        homeProjectionStore: HomeProjectionStore?
    ) -> any HomeIngestionCoordinating {
        let snapshotStore = HomeSnapshotStore(
            spcRisk: spc,
            spcOutlook: spc,
            arcusAlerts: alerts
        )
        let executor = HomeIngestionExecutor(
            environment: .init(
                logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
                spcSync: spc,
                arcusAlertSync: alerts,
                weatherClient: weather,
                locationSession: locationSession,
                snapshotStore: snapshotStore,
                projectionStore: homeProjectionStore,
                widgetSnapshotRefresher: nil
            )
        )
        return HomeIngestionCoordinator(executor: executor)
    }

    private func makeContext(
        latitude: Double = 39.75,
        longitude: Double = -104.44,
        h3Cell: Int64 = 123_456,
        timestamp: TimeInterval = 100
    ) -> LocationContext {
        let snapshot = LocationSnapshot(
            coordinates: .init(latitude: latitude, longitude: longitude),
            timestamp: Date(timeIntervalSince1970: timestamp),
            accuracy: 25,
            placemarkSummary: "Bennett, CO",
            h3Cell: h3Cell
        )
        let grid = GridPointSnapshot(
            nwsId: "BOU/10,20",
            latitude: snapshot.coordinates.latitude,
            longitude: snapshot.coordinates.longitude,
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
            countyCode: "COC005",
            fireZone: "COZ214",
            countyLabel: "Arapahoe",
            fireZoneLabel: "Front Range"
        )
        return LocationContext(snapshot: snapshot, h3Cell: snapshot.h3Cell ?? 123_456, grid: grid)
    }

    private func sampleWeather() -> SummaryWeather {
        SummaryWeather(
            temperature: .init(value: 72, unit: .fahrenheit),
            symbolName: "sun.max.fill",
            conditionText: "Clear",
            asOf: Date(timeIntervalSince1970: 200),
            dewPoint: .init(value: 54, unit: .fahrenheit),
            humidity: 0.45,
            windSpeed: .init(value: 15, unit: .milesPerHour),
            windGust: .init(value: 24, unit: .milesPerHour),
            windDirection: "NW",
            pressure: .init(value: 29.92, unit: .inchesOfMercury),
            pressureTrend: "steady"
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

    private func makeUpdatedMeso(from original: MdDTO, summary: String) -> MdDTO {
        MdDTO(
            number: original.number,
            title: original.title,
            link: original.link,
            issued: original.issued,
            validStart: original.validStart,
            validEnd: original.validEnd,
            areasAffected: original.areasAffected,
            summary: summary,
            concerning: original.concerning,
            watchProbability: original.watchProbabilityText,
            threats: original.threats,
            coordinates: original.coordinates
        )
    }

    private func sampleOutlooks() -> [ConvectiveOutlookDTO] {
        [
            ConvectiveOutlookDTO(
                title: "Day 1 Convective Outlook",
                link: URL(string: "https://example.com/day1")!,
                published: Date(timeIntervalSince1970: 100),
                summary: "Earlier outlook",
                fullText: "Earlier full text",
                day: 1,
                riskLevel: "SLGT",
                issued: Date(timeIntervalSince1970: 100),
                validUntil: Date(timeIntervalSince1970: 500)
            ),
            ConvectiveOutlookDTO(
                title: "Day 2 Convective Outlook",
                link: URL(string: "https://example.com/day2")!,
                published: Date(timeIntervalSince1970: 200),
                summary: "Latest outlook",
                fullText: "Latest full text",
                day: 2,
                riskLevel: "ENH",
                issued: Date(timeIntervalSince1970: 200),
                validUntil: Date(timeIntervalSince1970: 600)
            )
        ]
    }
}

private actor RecordingHomeIngestionCoordinator: HomeIngestionCoordinating {
    private let snapshot: HomeSnapshot
    private var results: [Result<HomeSnapshot, Error>]
    private let runGate: AsyncGate?
    private let progressEvents: [HomeIngestionProgressEvent]
    private var submittedRequests: [HomeIngestionRequest] = []
    private var recordedProgressEvents: [HomeIngestionProgressEvent] = []

    init(
        snapshot: HomeSnapshot = .empty,
        results: [Result<HomeSnapshot, Error>] = [],
        runGate: AsyncGate? = nil,
        progressEvents: [HomeIngestionProgressEvent] = []
    ) {
        self.snapshot = snapshot
        self.results = results
        self.runGate = runGate
        self.progressEvents = progressEvents
    }

    func enqueue(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) {
        submittedRequests.append(
            HomeIngestionRequest(
                trigger: trigger,
                locationContext: locationContext,
                remoteAlertContext: remoteAlertContext
            )
        )
    }

    func enqueueAndWait(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) async throws -> HomeSnapshot {
        let request = HomeIngestionRequest(
            trigger: trigger,
            locationContext: locationContext,
            remoteAlertContext: remoteAlertContext
        )
        return try await enqueueAndWait(request)
    }

    func enqueue(_ request: HomeIngestionRequest) {
        submittedRequests.append(request)
    }

    func enqueueAndWait(_ request: HomeIngestionRequest) async throws -> HomeSnapshot {
        try await enqueueAndWait(request, progress: nil)
    }

    func enqueueAndWait(
        _ request: HomeIngestionRequest,
        progress: HomeIngestionProgressHandler?
    ) async throws -> HomeSnapshot {
        submittedRequests.append(request)
        for event in progressEvents {
            recordedProgressEvents.append(event)
            await progress?(event)
        }
        if let runGate {
            await runGate.wait()
        }
        if results.isEmpty == false {
            let result = results.removeFirst()
            return try result.get()
        }
        return snapshot
    }

    func requests() -> [HomeIngestionRequest] {
        submittedRequests
    }

    func requestCount() -> Int {
        submittedRequests.count
    }

    func progressHistory() -> [HomeIngestionProgressEvent] {
        recordedProgressEvents
    }
}

private enum TestError: Error {
    case failed
}

private actor SequencedHomeIngestionCoordinator: HomeIngestionCoordinating {
    private let snapshots: [HomeSnapshot]
    private let gates: [AsyncGate?]
    private var submittedRequests: [HomeIngestionRequest] = []

    init(
        snapshots: [HomeSnapshot],
        gates: [AsyncGate?]
    ) {
        self.snapshots = snapshots
        self.gates = gates
    }

    func enqueue(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) {
        submittedRequests.append(
            HomeIngestionRequest(
                trigger: trigger,
                locationContext: locationContext,
                remoteAlertContext: remoteAlertContext
            )
        )
    }

    func enqueueAndWait(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) async throws -> HomeSnapshot {
        let request = HomeIngestionRequest(
            trigger: trigger,
            locationContext: locationContext,
            remoteAlertContext: remoteAlertContext
        )
        return try await enqueueAndWait(request)
    }

    func enqueue(_ request: HomeIngestionRequest) {
        submittedRequests.append(request)
    }

    func enqueueAndWait(_ request: HomeIngestionRequest) async throws -> HomeSnapshot {
        try await enqueueAndWait(request, progress: nil)
    }

    func enqueueAndWait(
        _ request: HomeIngestionRequest,
        progress: HomeIngestionProgressHandler?
    ) async throws -> HomeSnapshot {
        submittedRequests.append(request)
        let index = submittedRequests.count - 1
        precondition(index < snapshots.count, "Test coordinator received more requests than snapshots")
        if index < gates.count, let gate = gates[index] {
            await gate.wait()
        }
        return snapshots[index]
    }

    func requestCount() -> Int {
        submittedRequests.count
    }
}

private actor ScriptedStagedHomeIngestionCoordinator: HomeIngestionCoordinating {
    struct Run: Sendable {
        let core: HomeIngestionPublication
        let enrichment: HomeIngestionPublication?
        let afterCoreGate: AsyncGate?
        let finalSnapshot: HomeSnapshot
        let waitsForCancellation: Bool

        init(
            core: HomeIngestionPublication,
            enrichment: HomeIngestionPublication? = nil,
            afterCoreGate: AsyncGate? = nil,
            finalSnapshot: HomeSnapshot,
            waitsForCancellation: Bool = false
        ) {
            self.core = core
            self.enrichment = enrichment
            self.afterCoreGate = afterCoreGate
            self.finalSnapshot = finalSnapshot
            self.waitsForCancellation = waitsForCancellation
        }
    }

    private let runs: [Run]
    private var submittedRequests: [HomeIngestionRequest] = []

    init(runs: [Run]) {
        self.runs = runs
    }

    func enqueue(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) {
        enqueue(
            HomeIngestionRequest(
                trigger: trigger,
                locationContext: locationContext,
                remoteAlertContext: remoteAlertContext
            )
        )
    }

    func enqueueAndWait(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) async throws -> HomeSnapshot {
        try await enqueueAndWait(
            HomeIngestionRequest(
                trigger: trigger,
                locationContext: locationContext,
                remoteAlertContext: remoteAlertContext
            )
        )
    }

    func enqueue(_ request: HomeIngestionRequest) {
        submittedRequests.append(request)
    }

    func enqueueAndWait(_ request: HomeIngestionRequest) async throws -> HomeSnapshot {
        try await enqueueAndWait(request, progress: nil, publication: nil)
    }

    func enqueueAndWait(
        _ request: HomeIngestionRequest,
        progress: HomeIngestionProgressHandler?
    ) async throws -> HomeSnapshot {
        try await enqueueAndWait(request, progress: progress, publication: nil)
    }

    func enqueueAndWait(
        _ request: HomeIngestionRequest,
        progress: HomeIngestionProgressHandler?,
        publication: HomeIngestionPublicationHandler?
    ) async throws -> HomeSnapshot {
        submittedRequests.append(request)
        let index = submittedRequests.count - 1
        precondition(index < runs.count, "Test coordinator received more requests than staged runs")
        let run = runs[index]

        await publication?(run.core)
        if run.waitsForCancellation {
            try await Task.sleep(for: .seconds(60))
        }
        await run.afterCoreGate?.wait()
        if let enrichment = run.enrichment {
            await publication?(enrichment)
        }
        return run.finalSnapshot
    }
}

private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen {
            return
        }

        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

private actor CompletionFlag {
    private var finished = false

    func markFinished() {
        finished = true
    }

    func isFinished() -> Bool {
        finished
    }
}

private actor IngestionProgressRecorder {
    private var events: [String] = []

    func recordHotLaneCompletion() {
        events.append("hotLaneCompleted")
    }

    func markHotAlertsCompleted() {
        events.append("hotAlertsMarked")
    }

    func recordSlowLaneCompletion() {
        events.append("slowLaneCompleted")
    }

    func isHotAlertsMarked() -> Bool {
        events.contains("hotAlertsMarked")
    }

    func isSlowLaneCompleted() -> Bool {
        events.contains("slowLaneCompleted")
    }

    func hotLaneCompletedBeforeMark() -> Bool {
        guard let completedIndex = events.firstIndex(of: "hotLaneCompleted"),
              let markedIndex = events.firstIndex(of: "hotAlertsMarked") else {
            return false
        }
        return completedIndex < markedIndex
    }
}

private enum TestFailure: Error {
    case failedRead
}

@MainActor
private final class FakeLocationSession: HomeLocationContextPreparing, HomeContextPreparing {
    struct PrepareCall: Equatable {
        let requiresFreshLocation: Bool
        let showsAuthorizationPrompt: Bool
        let uploadSource: LocationUploadSource?
        let uploadReason: LocationUploadReason?
    }

    var currentContext: LocationContext?
    var preparedContext: LocationContext?
    var prepareCalls: [PrepareCall] = []

    private let prepareGate: AsyncGate?

    init(
        currentContext: LocationContext?,
        preparedContext: LocationContext?,
        prepareGate: AsyncGate? = nil
    ) {
        self.currentContext = currentContext
        self.preparedContext = preparedContext
        self.prepareGate = prepareGate
    }

    func prepareCurrentLocationContext(
        requiresFreshLocation: Bool,
        showsAuthorizationPrompt: Bool,
        uploadSource: LocationUploadSource?,
        uploadReason: LocationUploadReason?,
        authorizationTimeout: Double,
        locationTimeout: Double,
        maximumAcceptedLocationAge: TimeInterval,
        placemarkTimeout: Double
    ) async -> LocationContext? {
        prepareCalls.append(
            .init(
                requiresFreshLocation: requiresFreshLocation,
                showsAuthorizationPrompt: showsAuthorizationPrompt,
                uploadSource: uploadSource,
                uploadReason: uploadReason
            )
        )
        if let prepareGate {
            await prepareGate.wait()
        }
        return preparedContext
    }

    func currentPreparedContext() async -> LocationContext? {
        currentContext
    }
}

private actor FakeWeatherClient: HomeWeatherQuerying {
    private let result: HomeWeatherRefreshResult
    private var calls: [CLLocation] = []

    init(weather: SummaryWeather? = nil) {
        self.result = .success(weather)
    }

    init(result: HomeWeatherRefreshResult) {
        self.result = result
    }

    func currentWeather(for location: CLLocation) async -> HomeWeatherRefreshResult {
        calls.append(location)
        return result
    }

    func callCount() -> Int {
        calls.count
    }
}

private actor FakeSpcProvider: SpcSyncing, SpcRiskQuerying, SpcOutlookQuerying {
    private let activeMesos: [MdDTO]
    private let outlookValues: [ConvectiveOutlookDTO]
    private let locationReadError: Error?
    private let syncMesoscaleGate: AsyncGate?
    private let mapSyncGate: AsyncGate?
    private let convectiveOutlookGate: AsyncGate?
    private let mapSyncOutcome: SpcMapSyncOutcome
    private let stormRiskValue: StormRiskLevel
    private let severeRiskValue: SevereWeatherThreat
    private let fireRiskValue: FireRiskLevel

    private var syncMapProductsCalls = 0
    private var syncConvectiveOutlooksCalls = 0
    private var syncMesoscaleCalls = 0
    private var observedHTTPModeValues: [HTTPExecutionMode] = []
    private var cancelledSyncCalls = 0
    private var stormRiskQueries = 0
    private var severeRiskQueries = 0
    private var fireRiskQueries = 0
    private var activeMesosQueries = 0
    private var outlookQueries = 0

    init(
        activeMesos: [MdDTO] = [MD.sampleDiscussionDTOs[0]],
        outlooks: [ConvectiveOutlookDTO] = [],
        locationReadError: Error? = nil,
        syncMesoscaleGate: AsyncGate? = nil,
        mapSyncGate: AsyncGate? = nil,
        convectiveOutlookGate: AsyncGate? = nil,
        mapSyncOutcome: SpcMapSyncOutcome = .accepted,
        stormRiskValue: StormRiskLevel = .enhanced,
        severeRiskValue: SevereWeatherThreat = .hail(probability: 0.30),
        fireRiskValue: FireRiskLevel = .elevated
    ) {
        self.activeMesos = activeMesos
        self.outlookValues = outlooks
        self.locationReadError = locationReadError
        self.syncMesoscaleGate = syncMesoscaleGate
        self.mapSyncGate = mapSyncGate
        self.convectiveOutlookGate = convectiveOutlookGate
        self.mapSyncOutcome = mapSyncOutcome
        self.stormRiskValue = stormRiskValue
        self.severeRiskValue = severeRiskValue
        self.fireRiskValue = fireRiskValue
    }

    func sync() async {}

    func syncMapProducts() async {
        syncMapProductsCalls += 1
    }

    func syncMapProductsOutcome() async -> SpcMapSyncOutcome {
        syncMapProductsCalls += 1
        observedHTTPModeValues.append(HTTPExecutionMode.current)
        if let mapSyncGate {
            await mapSyncGate.wait()
        }
        if Task.isCancelled {
            cancelledSyncCalls += 1
        }
        return mapSyncOutcome
    }

    func syncTextProducts() async {}

    func syncConvectiveOutlooks() async {
        syncConvectiveOutlooksCalls += 1
        observedHTTPModeValues.append(HTTPExecutionMode.current)
        if let convectiveOutlookGate {
            await convectiveOutlookGate.wait()
        }
    }

    func syncMesoscaleDiscussions() async {
        syncMesoscaleCalls += 1
        observedHTTPModeValues.append(HTTPExecutionMode.current)
        if let syncMesoscaleGate {
            await syncMesoscaleGate.wait()
        }
        if Task.isCancelled {
            cancelledSyncCalls += 1
        }
    }

    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel {
        stormRiskQueries += 1
        if let locationReadError {
            throw locationReadError
        }
        return stormRiskValue
    }

    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat {
        severeRiskQueries += 1
        if let locationReadError {
            throw locationReadError
        }
        return severeRiskValue
    }

    func getActiveMesos(at time: Date, for point: CLLocationCoordinate2D) async throws -> [MdDTO] {
        activeMesosQueries += 1
        if let locationReadError {
            throw locationReadError
        }
        return activeMesos
    }

    func getFireRisk(for point: CLLocationCoordinate2D) async throws -> FireRiskLevel {
        fireRiskQueries += 1
        if let locationReadError {
            throw locationReadError
        }
        return fireRiskValue
    }

    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO? {
        outlookQueries += 1
        return outlookValues.max(by: { $0.published < $1.published })
    }

    func getConvectiveOutlooks() async throws -> [ConvectiveOutlookDTO] {
        outlookQueries += 1
        return outlookValues
    }

    func syncMapProductsCount() -> Int { syncMapProductsCalls }
    func syncConvectiveOutlooksCount() -> Int { syncConvectiveOutlooksCalls }
    func syncMesoscaleDiscussionsCount() -> Int { syncMesoscaleCalls }
    func stormRiskQueryCount() -> Int { stormRiskQueries }
    func severeRiskQueryCount() -> Int { severeRiskQueries }
    func fireRiskQueryCount() -> Int { fireRiskQueries }
    func activeMesosQueryCount() -> Int { activeMesosQueries }
    func outlookQueryCount() -> Int { outlookQueries }
    func observedHTTPModes() -> [HTTPExecutionMode] { observedHTTPModeValues }
    func cancelledSyncCount() -> Int { cancelledSyncCalls }
}

private final class RecordingWidgetSnapshotRefresher: @unchecked Sendable, WidgetSnapshotRefreshing {
    private let lock = NSLock()
    private var calls = 0

    func refresh(scope: WidgetSnapshotChangeScope, input: WidgetSnapshotRefreshInput) throws {
        lock.lock()
        defer { lock.unlock() }
        calls += 1
    }

    func refreshCallCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}

private actor FakeAlertProvider: ArcusAlertSyncing, ArcusAlertQuerying {
    private let activeAlerts: [AlertDTO]
    private let syncGate: AsyncGate?
    private var syncCalls = 0
    private var queryCalls = 0
    private var observedHTTPModeValues: [HTTPExecutionMode] = []
    private var cancelledSyncCalls = 0

    init(
        activeAlerts: [AlertDTO] = [Watch.sampleWatchRows[0]],
        syncGate: AsyncGate? = nil
    ) {
        self.activeAlerts = activeAlerts
        self.syncGate = syncGate
    }

    func sync(context: LocationContext) async {
        syncCalls += 1
        observedHTTPModeValues.append(HTTPExecutionMode.current)
        if let syncGate {
            await syncGate.wait()
        }
        if Task.isCancelled {
            cancelledSyncCalls += 1
        }
    }

    func syncRemoteAlert(id: String, revisionSent: Date?) async {
        syncCalls += 1
        observedHTTPModeValues.append(HTTPExecutionMode.current)
    }

    func getActiveAlerts(context: LocationContext) async throws -> [AlertDTO] {
        queryCalls += 1
        return activeAlerts
    }

    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry] {
        []
    }

    func getAlert(id: String) async throws -> AlertDTO? {
        activeAlerts.first(where: { $0.id == id })
    }

    func syncCount() -> Int { syncCalls }
    func queryCount() -> Int { queryCalls }
    func observedHTTPModes() -> [HTTPExecutionMode] { observedHTTPModeValues }
    func cancelledSyncCount() -> Int { cancelledSyncCalls }
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @escaping @MainActor () async -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}
