import CryptoKit
import Synchronization
import Foundation
import Testing
import SwiftData
import CoreLocation
import OSLog
import ArcusCore
@testable import SkyAware

@Suite("Background refresh budget")
struct BackgroundRefreshBudgetTests {
    private let clock = ContinuousClock()

    @Test("Default policy reserves five seconds after twenty-five seconds of work")
    func defaultPolicy_derivesExpectedDeadlines() {
        let start = clock.now
        let budget = BackgroundRefreshBudget.standard(start: start)

        #expect(budget.completionDeadline == start + .seconds(30))
        #expect(budget.workDeadline == start + .seconds(25))
        #expect(budget.finalizationReserve == .seconds(5))
    }

    @Test("Work before its deadline is admitted when it fits")
    func admission_beforeWorkDeadline_admitsFittingWork() {
        let start = clock.now
        let budget = BackgroundRefreshBudget.standard(start: start)
        let instant = start + .seconds(20)

        #expect(budget.remainingWork(at: instant) == .seconds(5))
        #expect(budget.admission(for: .seconds(5), at: instant, isCancelled: false) == .admitted)
    }

    @Test("Work admission closes exactly at the work deadline")
    func admission_atWorkDeadline_rejectsWork() {
        let start = clock.now
        let budget = BackgroundRefreshBudget.standard(start: start)

        #expect(budget.remainingWork(at: budget.workDeadline) == .zero)
        #expect(
            budget.admission(for: .zero, at: budget.workDeadline, isCancelled: false) == .workDeadlineReached
        )
    }

    @Test("Remaining durations never become negative after either deadline")
    func remainingDurations_afterDeadlines_areZero() {
        let start = clock.now
        let budget = BackgroundRefreshBudget.standard(start: start)

        #expect(budget.remainingWork(at: start + .seconds(26)) == .zero)
        #expect(budget.remainingTotal(at: start + .seconds(31)) == .zero)
    }

    @Test("Finalization reserve closes work while total time remains")
    func finalizationReserve_preservesTotalTimeAfterWorkCloses() {
        let start = clock.now
        let budget = BackgroundRefreshBudget.standard(start: start)
        let instant = start + .seconds(27)

        #expect(budget.remainingWork(at: instant) == .zero)
        #expect(budget.remainingTotal(at: instant) == .seconds(3))
        #expect(budget.admission(for: .seconds(1), at: instant, isCancelled: false) == .workDeadlineReached)
    }

    @Test("Work that exceeds the remaining window is rejected distinctly")
    func admission_withInsufficientTime_rejectsWork() {
        let start = clock.now
        let budget = BackgroundRefreshBudget.standard(start: start)

        #expect(
            budget.admission(for: .seconds(6), at: start + .seconds(20), isCancelled: false) == .insufficientTime
        )
    }

    @Test("Cancellation rejects work before evaluating available time")
    func admission_whenCancelled_rejectsWork() {
        let start = clock.now
        let budget = BackgroundRefreshBudget.standard(start: start)

        #expect(budget.admission(for: .seconds(1), at: start, isCancelled: true) == .cancelled)
    }

    @Test("Injected deadlines derive deterministic work boundaries")
    func injectedDeadline_derivesWorkDeadline() {
        let start = clock.now
        let completionDeadline = start + .seconds(12)
        let budget = BackgroundRefreshBudget(
            start: start,
            completionDeadline: completionDeadline,
            finalizationReserve: .seconds(4)
        )

        #expect(budget.completionDeadline == completionDeadline)
        #expect(budget.workDeadline == start + .seconds(8))
        #expect(budget.remainingWork(at: start) == .seconds(8))
        #expect(budget.remainingTotal(at: start) == .seconds(12))
    }

    @Test("An oversized reserve produces no work time")
    func oversizedReserve_clampsWorkDeadlineToStart() {
        let start = clock.now
        let budget = BackgroundRefreshBudget(
            start: start,
            completionDeadline: start + .seconds(3),
            finalizationReserve: .seconds(5)
        )

        #expect(budget.workDeadline == start)
        #expect(budget.remainingWork(at: start) == .zero)
        #expect(budget.admission(for: .seconds(1), at: start, isCancelled: false) == .workDeadlineReached)
    }
}

@Suite("BackgroundScheduler replacement policy", .serialized)
struct BackgroundSchedulerReplacementPolicyTests {
    @Test("Replaces pending request when requested run is materially earlier")
    func replaceWhenRequestedIsEarlier() {
        let base = Date(timeIntervalSince1970: 0)
        let existing = base.addingTimeInterval(60 * 60)
        let requested = base.addingTimeInterval(20 * 60)
        
        #expect(
            BackgroundScheduler.decision(
                for: .at(existing),
                requested: requested,
                intent: .authoritative,
                minimumDifference: 120
            ) == .replace(existing: existing)
        )
    }
    
    @Test("Replaces pending request when requested run is materially later")
    func replaceWhenRequestedIsLater() {
        let base = Date(timeIntervalSince1970: 0)
        let existing = base.addingTimeInterval(20 * 60)
        let requested = base.addingTimeInterval(60 * 60)
        
        #expect(
            BackgroundScheduler.decision(
                for: .at(existing),
                requested: requested,
                intent: .authoritative,
                minimumDifference: 120
            ) == .replace(existing: existing)
        )
    }
    
    @Test("Ensure-only scheduling preserves an existing request")
    func ensureOnlyPreservesExistingRequest() {
        let base = Date(timeIntervalSince1970: 0)
        let existing = base.addingTimeInterval(20 * 60)
        let requested = base.addingTimeInterval(60 * 60)
        
        #expect(
            BackgroundScheduler.decision(
                for: .at(existing),
                requested: requested,
                intent: .ensure,
                minimumDifference: 120
            ) == .keepExisting
        )
    }

    @Test("Keeps requests within the two-minute replacement tolerance")
    func keepsRequestsWithinTwoMinuteTolerance() {
        let base = Date(timeIntervalSince1970: 0)
        let existing = base.addingTimeInterval(60 * 60)
        let requested = existing.addingTimeInterval(-120)

        #expect(
            BackgroundScheduler.decision(
                for: .at(existing),
                requested: requested,
                intent: .authoritative,
                minimumDifference: 120
            ) == .keepExisting
        )
    }

    @Test("Preserves immediate pending requests")
    func preservesImmediatePendingRequests() {
        let requested = Date(timeIntervalSince1970: 0).addingTimeInterval(20 * 60)

        #expect(
            BackgroundScheduler.decision(
                for: .immediate,
                requested: requested,
                intent: .authoritative,
                minimumDifference: 120
            ) == .keepImmediate
        )
    }
}

@Suite("BackgroundOrchestrator Cadence", .serialized)
struct BackgroundOrchestratorCadenceTests {
    @Test("WSSI deferral and permitted source failure preserve prior morning delivery", arguments: [false, true])
    func wssiFailureDoesNotInterfereWithNotifications(backgroundAcquisitionEnabled: Bool) async throws {
        let sender = RecordingRiskSender()
        let wssiOutcomes = Mutex<[WSSIForegroundIngestion.Outcome]>([])
        let container = try await MainActor.run { try TestStore.container(for: SkyAwarePersistenceSchema.models) }
        let store = WSSISnapshotStore(modelContainer: container)
        let wssi = try WSSIForegroundIngestion(store: store, client: WSSIClient(transport: { _, _ in
            #expect(await sender.sent().count == 1)
            throw WSSIAcquisitionError.invalidResponse
        }), enabled: { true }, backgroundAcquisitionEnabled: backgroundAcquisitionEnabled, observe: { value in wssiOutcomes.withLock { $0.append(value) } })
        let snapshot = Self.makeRiskSnapshot(change: nil)
        let system = try await makeRiskSystem(
            coordinator: RecordingHomeIngestionCoordinator(snapshot: snapshot),
            morningEngine: makeMorningEngine(sender: sender),
            riskChangeEngine: makeRiskChangeEngine(sender: NoopSender()),
            settingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: true, mesoNotificationsEnabled: false)
            ), wssiIngestion: wssi
        )
        let outcome = await system.orchestrator.run()
        #expect(outcome.result == .success)
        #expect(wssiOutcomes.withLock { $0 } == [backgroundAcquisitionEnabled ? .failed : .deferredFeasibility])
        #expect(outcome.didNotify)
        #expect(await sender.sent().count == 1)
        #expect(try await system.latestHealthRecord()?.didNotify == true)
    }

    @Test("Every storm risk level maps to the evaluated cadence band")
    func everyStormRiskLevel_mapsToExpectedCadenceBand() {
        let policy = CadencePolicy()
        let cases: [(StormRiskLevel, Cadence)] = [
            (.allClear, .long),
            (.thunderstorm, .normal),
            (.marginal, .short),
            (.slight, .short),
            (.enhanced, .short),
            (.moderate, .short),
            (.high, .short)
        ]

        for (risk, expected) in cases {
            let result = policy.decide(
                for: .init(
                    categorical: risk,
                    inMeso: false,
                    inAlert: false
                )
            )

            #expect(result.cadence == expected)
            #expect(result.reason.contains(risk.abbreviation))
        }
    }

    @Test("Alert and meso precedence wins over categorical cadence")
    func alertAndMesoPrecedenceWinsOverCategoricalCadence() {
        let policy = CadencePolicy()
        let result = policy.decide(
            for: .init(
                categorical: .allClear,
                inMeso: true,
                inAlert: true
            )
        )

        #expect(result.cadence == .short)
        #expect(result.reason == "gate=watch,meso")
    }

    @Test("Fresh location request updates provider before risk queries")
    func freshLocationRequest_updatesProviderBeforeRiskQueries() async throws {
        let refreshed = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            refreshedLocation: refreshed,
            refreshSucceeds: true,
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )

        _ = await setup.orchestrator.run()

        let points = await setup.spc.queriedPoints()
        #expect(points.isEmpty == false)
        #expect(points.allSatisfy { $0.latitude == refreshed.latitude && $0.longitude == refreshed.longitude })
    }

    @Test("Failed fresh location request uses recent cached snapshot")
    func failedFreshLocationRequest_usesRecentCachedSnapshot() async throws {
        let cached = CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395)
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            refreshedLocation: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            refreshSucceeds: false,
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )

        _ = await setup.orchestrator.run()

        let points = await setup.spc.queriedPoints()
        #expect(points.isEmpty == false)
        #expect(points.allSatisfy { $0.latitude == cached.latitude && $0.longitude == cached.longitude })
    }

    @Test("Stale cached snapshot skips location-dependent work when refresh fails")
    func staleCachedSnapshot_skipsLocationDependentWorkWhenRefreshFails() async throws {
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            refreshedLocation: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            refreshSucceeds: false,
            cachedSnapshotTimestamp: Date().addingTimeInterval(-(6 * 60)),
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )

        let outcome = await setup.orchestrator.run()

        let points = await setup.spc.queriedPoints()
        #expect(points.isEmpty)
        #expect(outcome.result == .skipped)
    }

    @Test("Global SPC sync still runs when location context is unavailable")
    func globalSpcSync_runsBeforeLocationContext() async throws {
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            refreshedLocation: nil,
            refreshSucceeds: false,
            cachedSnapshotTimestamp: Date().addingTimeInterval(-(6 * 60)),
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )

        _ = await setup.orchestrator.run()

        #expect(await setup.spc.syncMapProductsCount() == 1)
        #expect(await setup.spc.syncConvectiveOutlooksCount() == 1)
        #expect(await setup.spc.syncExecutionModes().allSatisfy { $0 == .background })
        #expect((await setup.spc.queriedPoints()).isEmpty)
    }

    @Test("Background refresh drains pending uploads before unified ingestion starts")
    func backgroundRefresh_drainsPendingUploadsBeforeUnifiedIngestionStarts() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        try await MainActor.run { try TestStore.reset(BgRunSnapshot.self, in: container) }

        let gate = AsyncGate()
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let coordinator = RecordingHomeIngestionCoordinator(
            snapshot: HomeSnapshot(
                locationSnapshot: context.snapshot,
                refreshKey: context.refreshKey,
                stormRisk: .allClear,
                severeRisk: .allClear,
                fireRisk: .clear
            ),
            runGate: gate
        )
        let uploadDrainer = RecordingPendingUploadDrainer()
        let orchestrator = BackgroundOrchestrator(
            coordinator: coordinator,
            policy: RefreshPolicy(),
            engine: MorningEngine(
                rule: NoopMorningRule(),
                gate: AllowAllGate(),
                composer: NoopComposer(),
                sender: NoopSender()
            ),
            mesoEngine: MesoEngine(
                rule: NoopMesoRule(),
                gate: AllowAllGate(),
                composer: NoopComposer(),
                sender: NoopSender(),
                spc: FakeSpcProvider(activeMesos: [])
            ),
            riskChangeEngine: makeRiskChangeEngine(sender: NoopSender()),
            health: BgHealthStore(modelContainer: container),
            cadence: CadencePolicy(),
            notificationSettingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
            ),
            pendingUploadDrainer: uploadDrainer
        )
        let completion = CompletionFlag()

        let runTask = Task {
            _ = await orchestrator.run()
            await completion.markFinished()
        }

        let requestStarted = await waitUntil {
            await coordinator.requestCount() == 1
        }
        #expect(requestStarted)
        #expect(await completion.isFinished() == false)
        #expect(await uploadDrainer.drainCount() == 1)
        #expect(await uploadDrainer.legacyDrainCount() == 0)
        #expect(await uploadDrainer.boundedDrainCount() == 1)
        let startedRecord = try #require(await latestBgRun(in: container))
        #expect(startedRecord.isComplete == false)
        #expect(startedRecord.endedAt == nil)
        #expect(startedRecord.uploadDrainOutcome == .drained)
        #expect(startedRecord.uploadDrainDurationSeconds != nil)
        #expect(startedRecord.ingestionOutcome == nil)

        let recordedBudget = try #require(await uploadDrainer.recordedBudget())
        #expect(recordedBudget.budget.uploadQuota == 1)
        #expect(recordedBudget.budget.deadline - recordedBudget.receivedAt >= .seconds(4))
        #expect(recordedBudget.budget.deadline - recordedBudget.receivedAt <= .seconds(6))

        let request = try #require(await coordinator.requests().first)
        #expect(request.trigger == .backgroundRefresh)

        await gate.open()
        await runTask.value

        #expect(await completion.isFinished())
        #expect(await uploadDrainer.drainCount() == 1)
    }

    @Test("Background refresh still drains pending uploads when it exits early")
    func backgroundRefresh_drainsPendingUploadsOnEarlyExit() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        try await MainActor.run { try TestStore.reset(BgRunSnapshot.self, in: container) }

        let coordinator = RecordingHomeIngestionCoordinator(snapshot: HomeSnapshot())
        let uploadDrainer = RecordingPendingUploadDrainer()
        let orchestrator = BackgroundOrchestrator(
            coordinator: coordinator,
            policy: RefreshPolicy(),
            engine: MorningEngine(
                rule: NoopMorningRule(),
                gate: AllowAllGate(),
                composer: NoopComposer(),
                sender: NoopSender()
            ),
            mesoEngine: MesoEngine(
                rule: NoopMesoRule(),
                gate: AllowAllGate(),
                composer: NoopComposer(),
                sender: NoopSender(),
                spc: FakeSpcProvider(activeMesos: [])
            ),
            riskChangeEngine: makeRiskChangeEngine(sender: NoopSender()),
            health: BgHealthStore(modelContainer: container),
            cadence: CadencePolicy(),
            notificationSettingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
            ),
            pendingUploadDrainer: uploadDrainer
        )

        let outcome = await orchestrator.run()

        #expect(outcome.result == .skipped)
        #expect(await uploadDrainer.drainCount() == 1)
        #expect(await uploadDrainer.legacyDrainCount() == 0)
        #expect(await uploadDrainer.boundedDrainCount() == 1)
    }

    @Test("A bounded drain with remaining uploads still starts unified ingestion")
    func boundedDrainWithRemainingUploads_startsUnifiedIngestion() async throws {
        let gate = AsyncGate()
        let coordinator = RecordingHomeIngestionCoordinator(
            snapshot: Self.makeRiskSnapshot(change: nil),
            runGate: gate
        )
        let uploadDrainer = RecordingPendingUploadDrainer(outcome: .remaining)
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false),
            pendingUploadDrainer: uploadDrainer,
            coordinator: coordinator
        )

        let runTask = Task { await setup.orchestrator.run() }
        #expect(await waitUntil { await coordinator.requestCount() == 1 })
        #expect(await uploadDrainer.boundedDrainCount() == 1)
        #expect(await uploadDrainer.legacyDrainCount() == 0)

        await gate.open()
        #expect((await runTask.value).result == .success)
    }

    @Test("Cancellation during the bounded drain records recovery without starting ingestion")
    func cancellationDuringBoundedDrain_recordsRecoveryWithoutStartingIngestion() async throws {
        let coordinator = RecordingHomeIngestionCoordinator(snapshot: Self.makeRiskSnapshot(change: nil))
        let uploadDrainer = RecordingPendingUploadDrainer(suspendsUntilCancelled: true)
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false),
            pendingUploadDrainer: uploadDrainer,
            coordinator: coordinator
        )

        let runTask = Task { await setup.orchestrator.run() }
        #expect(await waitUntil { await uploadDrainer.hasStartedBoundedDrain() })

        runTask.cancel()
        let outcome = await runTask.value
        let health = try #require(await setup.latestHealthRecord())

        #expect(outcome.result == .cancelled)
        #expect(await uploadDrainer.observedCancellation())
        #expect(await coordinator.requestCount() == 0)
        #expect(health.outcome == .cancelled)
        #expect(health.cadence == Cadence.short.minutes)
    }

    @Test("Cancellation during unified ingestion records recovery promptly")
    func cancellationDuringUnifiedIngestion_recordsRecoveryPromptly() async throws {
        let deadlineWaiter = ManualDeadlineWaiter()
        let deadlineState = BackgroundRefreshDeadlineState()
        let coordinator = RecordingHomeIngestionCoordinator(
            snapshot: Self.makeRiskSnapshot(change: nil),
            suspendsUntilCancelled: true
        )
        let setup = try await makeDeadlineSystem(
            coordinator: coordinator,
            deadlineWaiter: deadlineWaiter,
            deadlineState: deadlineState
        )

        let runTask = Task { await setup.orchestrator.run() }
        #expect(await waitUntil { await coordinator.requestCount() == 1 })
        #expect(await waitUntil { await deadlineWaiter.hasStarted() })

        runTask.cancel()
        let outcome = await runTask.value
        let health = try #require(await setup.latestHealthRecord())

        #expect(outcome.result == .cancelled)
        #expect(health.outcome == .cancelled)
        #expect(health.ingestionOutcome == .cancelled)
        #expect(health.cadence == Cadence.short.minutes)
        #expect(await coordinator.observedCancellation())
        #expect(await deadlineWaiter.observedCancellation())
        #expect(await deadlineState.exceeded() == false)
    }

    @Test("Blocked non-HTTP ingestion expires at the work deadline")
    func blockedNonHTTPIngestion_workDeadlineExpiresRun() async throws {
        let deadlineWaiter = ManualDeadlineWaiter()
        let deadlineState = BackgroundRefreshDeadlineState()
        let coordinator = RecordingHomeIngestionCoordinator(
            snapshot: Self.makeRiskSnapshot(change: nil),
            suspendsUntilCancelled: true
        )
        let setup = try await makeDeadlineSystem(
            coordinator: coordinator,
            deadlineWaiter: deadlineWaiter,
            deadlineState: deadlineState
        )

        let runTask = Task { await setup.orchestrator.run() }
        #expect(await waitUntil { await coordinator.requestCount() == 1 })
        #expect(await waitUntil { await deadlineWaiter.hasStarted() })

        await deadlineWaiter.reachDeadline()
        let outcome = await runTask.value
        let health = try #require(await setup.latestHealthRecord())

        #expect(outcome.result == .expired)
        #expect(health.outcome == .expired)
        #expect(health.ingestionOutcome == .expired)
        #expect(health.cadence == Cadence.short.minutes)
        #expect(await coordinator.observedCancellation())
        #expect(await deadlineState.exceeded())
    }

    @Test("Notification work finishing before its work deadline remains successful")
    func notificationBeforeWorkDeadline_remainsSuccessful() async throws {
        let ingestionGate = AsyncGate()
        let deadlineWaiter = ManualDeadlineWaiter()
        let deadlineState = BackgroundRefreshDeadlineState()
        let sender = RecordingRiskSender()
        let coordinator = RecordingHomeIngestionCoordinator(
            snapshot: Self.makeRiskSnapshot(change: nil),
            runGate: ingestionGate
        )
        let setup = try await makeDeadlineSystem(
            coordinator: coordinator,
            deadlineWaiter: deadlineWaiter,
            deadlineState: deadlineState,
            morningEngine: makeMorningEngine(sender: sender),
            settings: .init(morningSummariesEnabled: true, mesoNotificationsEnabled: false)
        )

        let runTask = Task { await setup.orchestrator.run() }
        #expect(await waitUntil { await coordinator.requestCount() == 1 })
        #expect(await waitUntil { await deadlineWaiter.hasStarted() })

        await ingestionGate.open()
        let outcome = await runTask.value
        let health = try #require(await setup.latestHealthRecord())

        #expect(outcome.result == .success)
        #expect(health.outcome == .success)
        #expect(health.ingestionOutcome == .completed)
        #expect((await sender.sent()).count == 1)
        #expect(await deadlineWaiter.observedCancellation())
        #expect(await deadlineState.exceeded() == false)
    }

    @Test("Blocked notification sender expires at the work deadline")
    func blockedNotificationSender_workDeadlineExpiresRun() async throws {
        let deadlineWaiter = ManualDeadlineWaiter()
        let deadlineState = BackgroundRefreshDeadlineState()
        let sender = CancellationAwareBlockingNotificationSender()
        let downstreamRiskSender = RecordingRiskSender()
        let change = makeRiskChange(
            previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
            current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
        )
        let coordinator = RecordingHomeIngestionCoordinator(snapshot: Self.makeRiskSnapshot(change: change))
        let setup = try await makeDeadlineSystem(
            coordinator: coordinator,
            deadlineWaiter: deadlineWaiter,
            deadlineState: deadlineState,
            morningEngine: makeMorningEngine(sender: sender),
            riskChangeEngine: makeRiskChangeEngine(sender: downstreamRiskSender),
            settings: .init(morningSummariesEnabled: true, mesoNotificationsEnabled: false)
        )

        let runTask = Task { await setup.orchestrator.run() }
        #expect(await waitUntil { await sender.hasStarted() })

        await deadlineWaiter.reachDeadline()
        let outcome = await runTask.value
        let health = try #require(await setup.latestHealthRecord())

        #expect(outcome.result == .expired)
        #expect(health.outcome == .expired)
        #expect(health.ingestionOutcome == .completed)
        #expect(health.cadence == Cadence.short.minutes)
        #expect(await sender.observedCancellation())
        #expect(await downstreamRiskSender.sent().isEmpty)
        #expect(await deadlineState.exceeded())
    }

    @Test("Delivered morning risk coalesces before work deadline expiration")
    func deliveredMorningRisk_coalescesBeforeWorkDeadlineExpiration() async throws {
        let deadlineWaiter = ManualDeadlineWaiter()
        let deadlineState = BackgroundRefreshDeadlineState()
        let morningSender = SuccessfulOnCancellationNotificationSender()
        let riskSender = RecordingRiskSender()
        let riskEngine = makeRiskChangeEngine(sender: riskSender)
        let projectionKey = "projection:deadline"
        let olderChange = makeRiskChange(
            projectionKey: projectionKey,
            previous: makeRiskProfile(storm: .allClear, severe: .allClear, fire: .clear),
            current: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear)
        )
        let deliveredChange = makeRiskChange(
            projectionKey: projectionKey,
            previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
            current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
        )
        #expect(await riskEngine.run(change: olderChange, isEnabled: false) == false)

        let coordinator = RecordingHomeIngestionCoordinator(
            snapshot: Self.makeRiskSnapshot(change: deliveredChange)
        )
        let setup = try await makeDeadlineSystem(
            coordinator: coordinator,
            deadlineWaiter: deadlineWaiter,
            deadlineState: deadlineState,
            morningEngine: makeMorningEngine(sender: morningSender),
            riskChangeEngine: riskEngine,
            settings: .init(morningSummariesEnabled: true, mesoNotificationsEnabled: false)
        )

        let runTask = Task { await setup.orchestrator.run() }
        #expect(await waitUntil { await morningSender.hasStarted() })

        await deadlineWaiter.reachDeadline()
        let outcome = await runTask.value

        #expect(outcome.result == .expired)
        #expect(await morningSender.observedCancellation())
        #expect(await riskEngine.run(change: nil, isEnabled: true) == false)
        #expect(await riskSender.sent().isEmpty)
        #expect(await deadlineState.exceeded())
    }

    @Test("Deadline reached before ingestion admission does not submit work")
    func deadlineBeforeIngestionAdmission_doesNotSubmitWork() async throws {
        let deadlineState = BackgroundRefreshDeadlineState()
        let deadlineWaiter = ManualDeadlineWaiter()
        let coordinator = RecordingHomeIngestionCoordinator(snapshot: Self.makeRiskSnapshot(change: nil))
        let setup = try await makeDeadlineSystem(
            coordinator: coordinator,
            deadlineWaiter: deadlineWaiter,
            deadlineState: deadlineState,
            workDeadlineAlreadyReached: true
        )

        let outcome = await setup.orchestrator.run()
        let health = try #require(await setup.latestHealthRecord())

        #expect(outcome.result == .expired)
        #expect(health.outcome == .expired)
        #expect(health.ingestionOutcome == .expired)
        #expect(await coordinator.requestCount() == 0)
        #expect(await deadlineWaiter.hasStarted() == false)
        #expect(await deadlineState.exceeded())
    }

    @Test("Ingestion completing after the deadline is conservatively expired")
    func ingestionCompletingAfterDeadline_isExpired() async throws {
        let ingestionGate = AsyncGate()
        let deadlineWaiter = ManualDeadlineWaiter()
        let deadlineState = BackgroundRefreshDeadlineState()
        let coordinator = RecordingHomeIngestionCoordinator(
            snapshot: Self.makeRiskSnapshot(change: nil),
            runGate: ingestionGate
        )
        let setup = try await makeDeadlineSystem(
            coordinator: coordinator,
            deadlineWaiter: deadlineWaiter,
            deadlineState: deadlineState
        )

        let runTask = Task { await setup.orchestrator.run() }
        #expect(await waitUntil { await coordinator.requestCount() == 1 })
        #expect(await waitUntil { await deadlineWaiter.hasStarted() })

        await deadlineWaiter.reachDeadline()
        #expect(await waitUntil { await deadlineState.exceeded() })
        await ingestionGate.open()

        let outcome = await runTask.value
        let health = try #require(await setup.latestHealthRecord())
        #expect(outcome.result == .expired)
        #expect(health.outcome == .expired)
        #expect(health.ingestionOutcome == .expired)
    }

    @Test("Only acknowledged server ownership suppresses local meso delivery",
          arguments: [false, true], [false, true])
    func mesoOwnership_selectsOneDeliveryPath(serverOwns: Bool, preferenceEnabled: Bool) async throws {
        let sender = RecordingRiskSender()
        let settings = MutableSettingsProvider(settings: .init(
            morningSummariesEnabled: false,
            mesoNotificationsEnabled: preferenceEnabled,
            serverOwnsMesoNotificationDelivery: serverOwns
        ))
        let setup = try await makeSystem(
            activeMesos: [Self.makeMeso()], activeAlerts: [],
            settings: await settings.current(),
            mesoEngine: MesoEngine(
                rule: MesoRule(), gate: AllowAllGate(), composer: NoopComposer(),
                sender: sender, spc: FakeSpcProvider(activeMesos: [])
            ),
            settingsProvider: settings
        )
        let outcome = await setup.orchestrator.run()
        let localOwns = preferenceEnabled && !serverOwns
        #expect(outcome.didNotify == localOwns)
        #expect(await sender.sent().count == (localOwns ? 1 : 0))
        #expect(outcome.feedsChanged.contains(.meso))
        #expect(try await setup.latestCadence() == Cadence.short.minutes)

        // A later acknowledgment changes the path without rebuilding the orchestrator.
        await settings.update(.init(
            morningSummariesEnabled: false,
            mesoNotificationsEnabled: preferenceEnabled,
            serverOwnsMesoNotificationDelivery: !serverOwns
        ))
        let next = await setup.orchestrator.run()
        #expect(next.didNotify == (preferenceEnabled && serverOwns))
        #expect(await sender.sent().count == (preferenceEnabled ? 1 : 0))
    }

    @Test("Ownership acknowledged during ingestion suppresses the same run's local delivery")
    func mesoOwnership_duringIngestionIsObserved() async throws {
        let sender = RecordingRiskSender()
        let settings = MutableSettingsProvider(settings: .init(
            morningSummariesEnabled: false, mesoNotificationsEnabled: true
        ))
        let gate = AsyncGate()
        var snapshot = Self.makeRiskSnapshot(change: nil)
        snapshot.mesos = [Self.makeMeso()]
        let coordinator = RecordingHomeIngestionCoordinator(snapshot: snapshot, runGate: gate)
        let setup = try await makeSystem(
            activeMesos: [], activeAlerts: [], settings: await settings.current(),
            coordinator: coordinator,
            mesoEngine: MesoEngine(
                rule: MesoRule(), gate: AllowAllGate(), composer: NoopComposer(),
                sender: sender, spc: FakeSpcProvider(activeMesos: [])
            ),
            settingsProvider: settings
        )
        let task = Task { await setup.orchestrator.run() }
        #expect(await waitUntil { await coordinator.requestCount() == 1 })
        await settings.update(.init(
            morningSummariesEnabled: false, mesoNotificationsEnabled: true,
            serverOwnsMesoNotificationDelivery: true
        ))
        await gate.open()
        let outcome = await task.value
        #expect(outcome.result == .success)
        #expect(!outcome.didNotify)
        #expect(await sender.sent().isEmpty)
        #expect(outcome.feedsChanged.contains(.meso))
        #expect(try await setup.latestCadence() == Cadence.short.minutes)
    }

    @Test("Ownership acquired during gate admission releases the local claim without sending")
    func mesoOwnership_duringGateAdmissionIsObserved() async throws {
        let sender = RecordingRiskSender()
        let settings = MutableSettingsProvider(settings: .init(
            morningSummariesEnabled: false, mesoNotificationsEnabled: true
        ))
        let gate = SuspendedMesoGate()
        let setup = try await makeSystem(
            activeMesos: [Self.makeMeso()], activeAlerts: [], settings: await settings.current(),
            mesoEngine: MesoEngine(
                rule: MesoRule(), gate: gate, composer: NoopComposer(),
                sender: sender, spc: FakeSpcProvider(activeMesos: [])
            ),
            settingsProvider: settings
        )
        let task = Task { await setup.orchestrator.run() }
        #expect(await waitUntil { await gate.hasStarted() })
        await settings.update(.init(
            morningSummariesEnabled: false, mesoNotificationsEnabled: true,
            serverOwnsMesoNotificationDelivery: true
        ))
        await gate.resume()
        #expect(!(await task.value).didNotify)
        #expect(await sender.sent().isEmpty)
        #expect(await gate.finishedWithoutScheduling())

        await settings.update(.init(morningSummariesEnabled: false, mesoNotificationsEnabled: true))
        #expect((await setup.orchestrator.run()).didNotify)
        #expect(await sender.sent().count == 1)
    }

    @Test("Active meso tightens cadence to short")
    func activeMeso_tightensCadenceToShort() async throws {
        let setup = try await makeSystem(
            activeMesos: [Self.makeMeso()],
            activeAlerts: [],
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )
        _ = await setup.orchestrator.run()

        let cadence = try await setup.latestCadence()
        #expect(cadence == Cadence.short.minutes)
    }

    @Test("Active alert tightens cadence to short")
    func activeAlert_tightensCadenceToShort() async throws {
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [Self.makeAlert()],
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )
        _ = await setup.orchestrator.run()

        let cadence = try await setup.latestCadence()
        #expect(cadence == Cadence.short.minutes)
    }

    @Test("No active meso/alert keeps all-clear cadence long")
    func noActiveHazards_keepsLongCadenceForAllClear() async throws {
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )
        _ = await setup.orchestrator.run()

        let cadence = try await setup.latestCadence()
        #expect(cadence == Cadence.long.minutes)
    }

    @Test("Background refresh sends one risk notification and marks didNotify")
    func backgroundRefresh_sendsRiskNotificationAndMarksDidNotify() async throws {
        let sender = RecordingRiskSender()
        let settingsProvider = MutableSettingsProvider(
            settings: .init(
                morningSummariesEnabled: false,
                mesoNotificationsEnabled: false,
                riskChangeNotificationsEnabled: true
            )
        )
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let snapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            riskProfileChange: makeRiskChange(
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let system = try await makeRiskSystem(
            snapshot: snapshot,
            riskChangeEngine: makeRiskChangeEngine(sender: sender),
            settingsProvider: settingsProvider
        )

        let outcome = await system.orchestrator.run()
        let health = try #require(await system.latestHealthRecord())

        #expect(outcome.didNotify)
        #expect(health.didNotify)
        #expect(await sender.sent().count == 1)
    }

    @Test("Background refresh records disabled risk change no-notify reason")
    func backgroundRefresh_recordsDisabledRiskChangeNoNotifyReason() async throws {
        let sender = RecordingRiskSender()
        let settingsProvider = MutableSettingsProvider(
            settings: .init(
                morningSummariesEnabled: false,
                mesoNotificationsEnabled: false,
                riskChangeNotificationsEnabled: false
            )
        )
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let snapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            riskProfileChange: makeRiskChange(
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let unchangedSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            riskProfileChange: nil
        )
        let system = try await makeRiskSystem(
            snapshots: [snapshot, unchangedSnapshot],
            riskChangeEngine: makeRiskChangeEngine(sender: sender),
            settingsProvider: settingsProvider
        )

        let outcome = await system.orchestrator.run()
        let health = try #require(await system.latestHealthRecord())

        #expect(outcome.didNotify == false)
        #expect(await sender.sent().isEmpty)
        #expect(health.didNotify == false)
        #expect(health.reasonNoNotify?.contains("Risk change notifications disabled") == true)
    }

    @Test("Background refresh records missing risk change no-notify reason")
    func backgroundRefresh_recordsMissingRiskChangeNoNotifyReason() async throws {
        let sender = RecordingRiskSender()
        let settingsProvider = MutableSettingsProvider(
            settings: .init(
                morningSummariesEnabled: false,
                mesoNotificationsEnabled: false,
                riskChangeNotificationsEnabled: true
            )
        )
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let snapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            riskProfileChange: nil
        )
        let system = try await makeRiskSystem(
            snapshot: snapshot,
            riskChangeEngine: makeRiskChangeEngine(sender: sender),
            settingsProvider: settingsProvider
        )

        let outcome = await system.orchestrator.run()
        let health = try #require(await system.latestHealthRecord())

        #expect(outcome.didNotify == false)
        #expect(await sender.sent().isEmpty)
        #expect(health.didNotify == false)
        #expect(health.reasonNoNotify?.contains("Risk change notification skipped (no change)") == true)
    }

    @Test("Disabled risk changes remain pending after a normal morning summary")
    func disabledRiskChangeRemainsPendingAfterNormalMorningSummary() async throws {
        let morningSender = RecordingRiskSender()
        let riskSender = RecordingRiskSender()
        let settingsProvider = MutableSettingsProvider(
            settings: .init(
                morningSummariesEnabled: true,
                mesoNotificationsEnabled: false,
                riskChangeNotificationsEnabled: false
            )
        )
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let snapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            riskProfileChange: makeRiskChange(
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let unchangedSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            riskProfileChange: nil
        )
        let system = try await makeRiskSystem(
            snapshots: [snapshot, unchangedSnapshot],
            morningEngine: makeMorningEngine(sender: morningSender),
            riskChangeEngine: makeRiskChangeEngine(sender: riskSender),
            settingsProvider: settingsProvider
        )

        let firstOutcome = await system.orchestrator.run()
        #expect(firstOutcome.didNotify)
        let firstMorning = try #require(await morningSender.sent().first)
        #expect(firstMorning.body.contains("Risk Update") == false)
        #expect(await riskSender.sent().isEmpty)

        await settingsProvider.update(
            .init(
                morningSummariesEnabled: false,
                mesoNotificationsEnabled: false,
                riskChangeNotificationsEnabled: true
            )
        )

        let secondOutcome = await system.orchestrator.run()
        let health = try #require(await system.latestHealthRecord())

        #expect(secondOutcome.didNotify)
        #expect(await riskSender.sent().count == 1)
        #expect(health.didNotify)
    }

    @Test("Morning success coalesces the current snapshot risk change")
    func morningSuccessCoalescesCurrentSnapshotRiskChange() async throws {
        let morningSender = RecordingRiskSender()
        let riskSender = RecordingRiskSender()
        let settings = StaticSettingsProvider(
            settings: .init(morningSummariesEnabled: true, mesoNotificationsEnabled: false)
        )
        let snapshot = Self.makeRiskSnapshot(
            change: makeRiskChange(
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let system = try await makeRiskSystem(
            snapshot: snapshot,
            morningEngine: makeMorningEngine(sender: morningSender),
            riskChangeEngine: makeRiskChangeEngine(sender: riskSender),
            settingsProvider: settings
        )

        #expect((await system.orchestrator.run()).didNotify)
        #expect((await morningSender.sent()).count == 1)
        #expect((await riskSender.sent()).isEmpty)
    }

    @Test("Coalesced risk change retires an older pending change for the same projection")
    func coalescedRiskChangeRetiresOlderPendingChangeForSameProjection() async throws {
        let morningSender = RecordingRiskSender()
        let riskSender = RecordingRiskSender()
        let settings = MutableSettingsProvider(
            settings: .init(
                morningSummariesEnabled: false,
                mesoNotificationsEnabled: false,
                riskChangeNotificationsEnabled: false
            )
        )
        let projectionKey = "projection:alpha"
        let first = Self.makeRiskSnapshot(
            change: makeRiskChange(
                projectionKey: projectionKey,
                previous: makeRiskProfile(storm: .allClear, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear)
            )
        )
        let second = Self.makeRiskSnapshot(
            change: makeRiskChange(
                projectionKey: projectionKey,
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let third = Self.makeRiskSnapshot(change: nil)
        let system = try await makeRiskSystem(
            snapshots: [first, second, third],
            morningEngine: makeMorningEngine(sender: morningSender),
            riskChangeEngine: makeRiskChangeEngine(sender: riskSender),
            settingsProvider: settings
        )

        _ = await system.orchestrator.run()
        await settings.update(.init(morningSummariesEnabled: true, mesoNotificationsEnabled: false))
        _ = await system.orchestrator.run()
        await settings.update(.init(morningSummariesEnabled: false, mesoNotificationsEnabled: false))
        _ = await system.orchestrator.run()

        #expect((await morningSender.sent()).count == 1)
        #expect((await riskSender.sent()).isEmpty)
    }

    @Test("Morning scheduling failure falls back to the current snapshot risk change")
    func morningSchedulingFailureFallsBackToRiskChange() async throws {
        let riskSender = RecordingRiskSender()
        let snapshot = Self.makeRiskSnapshot(
            change: makeRiskChange(
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let system = try await makeRiskSystem(
            snapshot: snapshot,
            morningEngine: makeMorningEngine(sender: FailingNotificationSender()),
            riskChangeEngine: makeRiskChangeEngine(sender: riskSender),
            settingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: true, mesoNotificationsEnabled: false)
            )
        )

        #expect((await system.orchestrator.run()).didNotify)
        #expect((await riskSender.sent()).count == 1)
    }

    @Test("Later risk transition remains independent after a coalesced morning")
    func laterRiskTransitionRemainsIndependentAfterCoalescedMorning() async throws {
        let morningSender = RecordingRiskSender()
        let riskSender = RecordingRiskSender()
        let first = Self.makeRiskSnapshot(
            change: makeRiskChange(
                projectionKey: "projection:one",
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let second = Self.makeRiskSnapshot(
            change: makeRiskChange(
                projectionKey: "projection:two",
                previous: makeRiskProfile(storm: .allClear, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .slight, severe: .allClear, fire: .clear)
            )
        )
        let system = try await makeRiskSystem(
            snapshots: [first, second],
            morningEngine: makeMorningEngine(sender: morningSender, gate: FirstMorningOnlyGate()),
            riskChangeEngine: makeRiskChangeEngine(sender: riskSender),
            settingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: true, mesoNotificationsEnabled: false)
            )
        )

        _ = await system.orchestrator.run()
        _ = await system.orchestrator.run()

        #expect((await morningSender.sent()).count == 1)
        #expect((await riskSender.sent()).count == 1)
    }

    @Test("Morning without a current change still delivers an older pending risk change")
    func morningWithoutCurrentChangeDeliversOlderPendingRiskChange() async throws {
        let morningSender = RecordingRiskSender()
        let riskSender = RecordingRiskSender()
        let settings = MutableSettingsProvider(
            settings: .init(
                morningSummariesEnabled: false,
                mesoNotificationsEnabled: false,
                riskChangeNotificationsEnabled: false
            )
        )
        let first = Self.makeRiskSnapshot(
            change: makeRiskChange(
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let second = Self.makeRiskSnapshot(change: nil)
        let system = try await makeRiskSystem(
            snapshots: [first, second],
            morningEngine: makeMorningEngine(sender: morningSender),
            riskChangeEngine: makeRiskChangeEngine(sender: riskSender),
            settingsProvider: settings
        )

        _ = await system.orchestrator.run()
        await settings.update(.init(morningSummariesEnabled: true, mesoNotificationsEnabled: false))
        _ = await system.orchestrator.run()

        #expect((await morningSender.sent()).count == 1)
        #expect((await riskSender.sent()).count == 1)
    }

    @Test("Missing location context records recovery cadence 20")
    func missingLocationContext_recordsRecoveryCadenceTwenty() async throws {
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            refreshedLocation: nil,
            refreshSucceeds: false,
            cachedSnapshotTimestamp: Date().addingTimeInterval(-(6 * 60)),
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )

        let outcome = await setup.orchestrator.run()
        let cadence = try await setup.latestCadence()

        #expect(outcome.result == .skipped)
        #expect(cadence == 20)
    }

    @Test("Failure to all-clear recovery records 20 then 60")
    func failureToAllClearRecovery_recordsTwentyThenSixty() async throws {
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let successSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear
        )
        let coordinator = ScriptedHomeIngestionCoordinator(
            responses: [
                .failure(.failed),
                .snapshot(successSnapshot)
            ]
        )
        let system = try await makeRiskSystem(
            coordinator: coordinator,
            riskChangeEngine: makeRiskChangeEngine(sender: NoopSender()),
            settingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
            )
        )

        let firstOutcome = await system.orchestrator.run()
        let secondOutcome = await system.orchestrator.run()
        let cadences = try await system.recordedCadences()

        #expect(firstOutcome.result == .failed)
        #expect(secondOutcome.result == .success)
        #expect(cadences == [20, 60])
    }

    @Test("Failure to thunderstorm recovery records 20 then 40")
    func failureToThunderstormRecovery_recordsTwentyThenForty() async throws {
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let successSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .thunderstorm,
            severeRisk: .allClear,
            fireRisk: .clear
        )
        let coordinator = ScriptedHomeIngestionCoordinator(
            responses: [
                .failure(.failed),
                .snapshot(successSnapshot)
            ]
        )
        let system = try await makeRiskSystem(
            coordinator: coordinator,
            riskChangeEngine: makeRiskChangeEngine(sender: NoopSender()),
            settingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
            )
        )

        let firstOutcome = await system.orchestrator.run()
        let secondOutcome = await system.orchestrator.run()
        let cadences = try await system.recordedCadences()

        #expect(firstOutcome.result == .failed)
        #expect(secondOutcome.result == .success)
        #expect(cadences == [20, 40])
    }
}

private extension BackgroundOrchestratorCadenceTests {
    struct SystemUnderTest {
        let orchestrator: BackgroundOrchestrator
        let modelContainer: ModelContainer
        let spc: FakeSpcProvider

        struct HealthRecord: Sendable {
            let outcome: BgRunOutcome?
            let cadence: Int
            let ingestionOutcome: BgPhaseOutcome?
        }

        func latestCadence() async throws -> Int? {
            try await MainActor.run {
                let context = ModelContext(modelContainer)
                var descriptor = FetchDescriptor<BgRunSnapshot>(
                    sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
                )
                descriptor.fetchLimit = 1
                return try context.fetch(descriptor).first?.cadence
            }
        }

        func latestHealthRecord() async throws -> HealthRecord? {
            try await MainActor.run {
                let context = ModelContext(modelContainer)
                var descriptor = FetchDescriptor<BgRunSnapshot>(
                    sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
                )
                descriptor.fetchLimit = 1
                guard let health = try context.fetch(descriptor).first else {
                    return nil
                }
                return .init(
                    outcome: health.outcome,
                    cadence: health.cadence,
                    ingestionOutcome: health.ingestionOutcome
                )
            }
        }
    }

    func makeSystem(
        activeMesos: [MdDTO],
        activeAlerts: [AlertDTO],
        refreshedLocation: CLLocationCoordinate2D? = nil,
        refreshSucceeds: Bool = false,
        cachedSnapshotTimestamp: Date = Date(),
        settings: NotificationSettings,
        pendingUploadDrainer: any PendingLocationUploadDraining = NoOpLocationUploadCoordinator(),
        coordinator suppliedCoordinator: (any HomeIngestionCoordinating)? = nil,
        morningEngine suppliedMorningEngine: MorningEngine? = nil,
        mesoEngine suppliedMesoEngine: MesoEngine? = nil,
        settingsProvider: (any NotificationSettingsProviding)? = nil,
        riskChangeEngine suppliedRiskChangeEngine: RiskChangeEngine? = nil,
        executionContextFactory: @escaping @Sendable (
            ContinuousClock.Instant
        ) -> BackgroundRefreshExecutionContext = {
            BackgroundRefreshExecutionContext(budget: .standard(start: $0))
        },
        workDeadlineWaiter: @escaping @Sendable (ContinuousClock.Instant) async throws -> Void = {
            try await ContinuousClock().sleep(until: $0)
        }
    ) async throws -> SystemUnderTest {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        try await MainActor.run { try TestStore.reset(BgRunSnapshot.self, in: container) }

        let healthStore = BgHealthStore(modelContainer: container)
        let spc = FakeSpcProvider(activeMesos: activeMesos)
        let alertProvider = FakeAlertProvider(activeAlerts: activeAlerts)
        let cachedContext = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395),
            timestamp: cachedSnapshotTimestamp,
            placemarkSummary: "Norman, OK"
        )
        let resolvedContext: LocationContext? = if refreshSucceeds, let refreshedLocation {
            Self.makeContext(
                coordinates: refreshedLocation,
                timestamp: Date(),
                placemarkSummary: "Denver, CO"
            )
        } else if Date().timeIntervalSince(cachedSnapshotTimestamp) <= 5 * 60 {
            cachedContext
        } else {
            nil
        }
        let locationSession = await MainActor.run {
            FakeLocationSession(
                currentContext: nil,
                preparedContext: resolvedContext
            )
        }

        let morningEngine = suppliedMorningEngine ?? MorningEngine(
            rule: NoopMorningRule(),
            gate: AllowAllGate(),
            composer: NoopComposer(),
            sender: NoopSender()
        )
        let mesoEngine = suppliedMesoEngine ?? MesoEngine(
            rule: NoopMesoRule(),
            gate: AllowAllGate(),
            composer: NoopComposer(),
            sender: NoopSender(),
            spc: spc
        )
        let snapshotStore = HomeSnapshotStore(
            spcRisk: spc,
            spcOutlook: spc,
            arcusAlerts: alertProvider,
            arcusMesos: StubHomeMesoQuery(mesos: activeMesos)
        )
        let coordinator = suppliedCoordinator ?? HomeIngestionCoordinator(
            executor: HomeIngestionExecutor(
                environment: .init(
                    logger: Logger(subsystem: "SkyAwareTests", category: "BackgroundOrchestratorCadenceTests"),
                    spcSync: spc,
                    arcusAlertSync: alertProvider,
                    weatherClient: FakeWeatherClient(),
                    locationSession: locationSession,
                    snapshotStore: snapshotStore,
                    projectionStore: nil,
                    widgetSnapshotRefresher: nil
                )
            )
        )

        let orchestrator = BackgroundOrchestrator(
            coordinator: coordinator,
            policy: RefreshPolicy(),
            engine: morningEngine,
            mesoEngine: mesoEngine,
            riskChangeEngine: suppliedRiskChangeEngine ?? makeRiskChangeEngine(sender: NoopSender()),
            health: healthStore,
            cadence: CadencePolicy(),
            notificationSettingsProvider: settingsProvider ?? StaticSettingsProvider(settings: settings),
            pendingUploadDrainer: pendingUploadDrainer,
            executionContextFactory: executionContextFactory,
            workDeadlineWaiter: workDeadlineWaiter
        )

        return .init(orchestrator: orchestrator, modelContainer: container, spc: spc)
    }

    func makeDeadlineSystem(
        coordinator: any HomeIngestionCoordinating,
        deadlineWaiter: ManualDeadlineWaiter,
        deadlineState: BackgroundRefreshDeadlineState,
        workDeadlineAlreadyReached: Bool = false,
        morningEngine: MorningEngine? = nil,
        riskChangeEngine: RiskChangeEngine? = nil,
        settings: NotificationSettings = .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
    ) async throws -> SystemUnderTest {
        try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            settings: settings,
            coordinator: coordinator,
            morningEngine: morningEngine,
            riskChangeEngine: riskChangeEngine,
            executionContextFactory: { start in
                let budget = workDeadlineAlreadyReached
                    ? BackgroundRefreshBudget(
                        start: start,
                        completionDeadline: start + .seconds(5),
                        finalizationReserve: .seconds(5)
                    )
                    : .standard(start: start)
                return BackgroundRefreshExecutionContext(budget: budget, deadlineState: deadlineState)
            },
            workDeadlineWaiter: { try await deadlineWaiter.wait(until: $0) }
        )
    }

    static func makeMeso() -> MdDTO {
        let now = Date()
        return MdDTO(
            number: 1001,
            title: "Mesoscale Discussion",
            link: URL(string: "https://www.spc.noaa.gov/products/md/1001.html")!,
            issued: now.addingTimeInterval(-3_600),
            validStart: now.addingTimeInterval(-3_600),
            validEnd: now.addingTimeInterval(3_600),
            areasAffected: "Central Oklahoma",
            summary: "Strong to severe storms possible.",
            watchProbability: "40",
            threats: nil,
            coordinates: []
        )
    }

    static func makeAlert() -> AlertDTO {
        let now = Date()
        return AlertDTO(
            id: "watch-1001",
            messageId: "watch-1001",
            title: "Tornado Watch",
            headline: "Tornadoes possible in the watch area",
            issued: now.addingTimeInterval(-3_600),
            expires: now.addingTimeInterval(3_600),
            ends: now.addingTimeInterval(3_600),
            messageType: "Alert",
            sender: "NWS Norman",
            severity: "Severe",
            urgency: "Immediate",
            certainty: "Observed",
            description: "A tornado watch has been issued.",
            instruction: nil,
            response: nil,
            areaSummary: "Central Oklahoma",
            tornadoDetection: nil,
            tornadoDamageThreat: nil,
            maxWindGust: nil,
            maxHailSize: nil,
            windThreat: nil,
            hailThreat: nil,
            thunderstormDamageThreat: nil,
            flashFloodDetection: nil,
            flashFloodDamageThreat : nil
        )
    }

    static func makeContext(
        coordinates: CLLocationCoordinate2D,
        timestamp: Date,
        placemarkSummary: String
    ) -> LocationContext {
        let snapshot = LocationSnapshot(
            coordinates: coordinates,
            timestamp: timestamp,
            accuracy: 10,
            placemarkSummary: placemarkSummary,
            h3Cell: 0x882681b485fffff
        )
        return LocationContext(
            snapshot: snapshot,
            h3Cell: 0x882681b485fffff,
            grid: GridPointSnapshot(
                nwsId: "https://api.weather.gov/points/\(coordinates.latitude),\(coordinates.longitude)",
                latitude: coordinates.latitude,
                longitude: coordinates.longitude,
                gridId: "OUN",
                gridX: 34,
                gridY: 74,
                forecastURL: nil,
                forecastHourlyURL: nil,
                forecastGridDataURL: nil,
                observationStationsURL: nil,
                city: "Norman",
                state: "OK",
                timeZoneId: "America/Chicago",
                radarStationId: "KTLX",
                forecastZone: "OKZ025",
                countyCode: "OKC109",
                fireZone: "OKZ025",
                countyLabel: "Oklahoma County",
                fireZoneLabel: "Central Oklahoma"
            )
        )
    }
}

private actor FakeSpcProvider: SpcSyncing, SpcRiskQuerying, SpcOutlookQuerying {
    private var recordedPoints: [CLLocationCoordinate2D] = []
    private var syncCalls = 0
    private var syncMapProductsCalls = 0
    private var syncConvectiveOutlooksCalls = 0
    private var syncExecutionModeValues: [HTTPExecutionMode] = []

    func getFireRisk(for point: CLLocationCoordinate2D) async throws -> SkyAware.FireRiskLevel {
        recordedPoints.append(point)
        return .clear
    }
    
    private let activeMesos: [MdDTO]

    init(activeMesos: [MdDTO]) {
        self.activeMesos = activeMesos
    }

    func sync() async { syncCalls += 1 }
    func syncMapProducts() async {
        syncMapProductsCalls += 1
        syncExecutionModeValues.append(HTTPExecutionMode.current)
    }
    func syncMapProductsOutcome() async -> SpcMapSyncOutcome {
        syncMapProductsCalls += 1
        syncExecutionModeValues.append(HTTPExecutionMode.current)
        return .accepted
    }
    func syncTextProducts() async {}
    func syncConvectiveOutlooks() async -> SpcOutlookSyncOutcome {
        syncConvectiveOutlooksCalls += 1
        syncExecutionModeValues.append(HTTPExecutionMode.current)
        return .accepted
    }
    func syncMesoscaleDiscussions() async -> SpcMesoSyncOutcome {
        syncExecutionModeValues.append(HTTPExecutionMode.current)
        return .accepted
    }

    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel {
        recordedPoints.append(point)
        return .allClear
    }

    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat {
        recordedPoints.append(point)
        return .allClear
    }

    func getActiveMesos(at time: Date, for point: CLLocationCoordinate2D) async throws -> [MdDTO] {
        recordedPoints.append(point)
        return activeMesos
    }

    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO? {
        nil
    }

    func getConvectiveOutlooks() async throws -> [ConvectiveOutlookDTO] {
        []
    }

    func queriedPoints() -> [CLLocationCoordinate2D] {
        recordedPoints
    }

    func syncCount() -> Int {
        syncCalls
    }

    func syncMapProductsCount() -> Int {
        syncMapProductsCalls
    }

    func syncConvectiveOutlooksCount() -> Int {
        syncConvectiveOutlooksCalls
    }

    func syncExecutionModes() -> [HTTPExecutionMode] {
        syncExecutionModeValues
    }
}

private actor FakeAlertProvider: ArcusAlertSyncing, ArcusAlertQuerying {
    private let activeAlerts: [AlertDTO]

    init(activeAlerts: [AlertDTO]) {
        self.activeAlerts = activeAlerts
    }

    func sync(context: LocationContext) async -> ArcusLocationSyncOutcome { .accepted }

    func syncRemoteAlert(id: String, revisionSent: Date?) async -> ArcusRemoteAlertSyncOutcome { .accepted }

    func getActiveAlerts(context: LocationContext) async throws -> [AlertDTO] {
        activeAlerts
    }

    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry] {
        []
    }

    func getAlert(id: String) async throws -> AlertDTO? {
        activeAlerts.first(where: { $0.id == id })
    }
}

@MainActor
private final class FakeLocationSession: HomeContextPreparing {
    var currentContext: LocationContext?
    var preparedContext: LocationContext?

    init(
        currentContext: LocationContext?,
        preparedContext: LocationContext?
    ) {
        self.currentContext = currentContext
        self.preparedContext = preparedContext
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
        preparedContext
    }

    func currentPreparedContext() async -> LocationContext? {
        currentContext
    }
}

private actor FakeWeatherClient: HomeWeatherQuerying {
    func currentWeather(for location: CLLocation) async -> HomeWeatherRefreshResult {
        .success(nil)
    }
}

private actor RecordingHomeIngestionCoordinator: HomeIngestionCoordinating {
    private let snapshot: HomeSnapshot
    private let runGate: AsyncGate?
    private let suspendsUntilCancelled: Bool
    private var submittedRequests: [HomeIngestionRequest] = []
    private var didObserveCancellation = false

    init(
        snapshot: HomeSnapshot = .empty,
        runGate: AsyncGate? = nil,
        suspendsUntilCancelled: Bool = false
    ) {
        self.snapshot = snapshot
        self.runGate = runGate
        self.suspendsUntilCancelled = suspendsUntilCancelled
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

    func enqueueAndWait(
        _ request: HomeIngestionRequest,
        progress: HomeIngestionProgressHandler?,
        publication: HomeIngestionPublicationHandler?
    ) async throws -> HomeSnapshot {
        _ = progress
        _ = publication
        submittedRequests.append(request)
        if suspendsUntilCancelled {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                didObserveCancellation = error is CancellationError
                throw error
            }
        }
        if let runGate {
            await runGate.wait()
        }
        return snapshot
    }

    func requests() -> [HomeIngestionRequest] {
        submittedRequests
    }

    func requestCount() -> Int {
        submittedRequests.count
    }

    func observedCancellation() -> Bool {
        didObserveCancellation
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

private actor ManualDeadlineWaiter {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private var started = false
    private var cancellationObserved = false

    init() {
        let pair = AsyncStream<Void>.makeStream()
        stream = pair.stream
        continuation = pair.continuation
    }

    func wait(until _: ContinuousClock.Instant) async throws {
        started = true
        for await _ in stream {
            return
        }
        cancellationObserved = Task.isCancelled
        try Task.checkCancellation()
    }

    func reachDeadline() {
        continuation.yield()
    }

    func hasStarted() -> Bool {
        started
    }

    func observedCancellation() -> Bool {
        cancellationObserved
    }
}

@MainActor
private func latestBgRun(in container: ModelContainer) throws -> BgRunState? {
    var descriptor = FetchDescriptor<BgRunSnapshot>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
    descriptor.fetchLimit = 1
    return try ModelContext(container).fetch(descriptor).first.map(BgRunState.init)
}

private actor RecordingPendingUploadDrainer: PendingLocationUploadDraining {
    struct RecordedBudget: Sendable {
        let budget: PendingLocationUploadDrainBudget
        let receivedAt: ContinuousClock.Instant
    }

    private let outcome: PendingLocationUploadDrainOutcome
    private let suspendsUntilCancelled: Bool
    private var legacyCount = 0
    private var boundedCount = 0
    private var budget: RecordedBudget?
    private var didStartBoundedDrain = false
    private var didObserveCancellation = false

    init(
        outcome: PendingLocationUploadDrainOutcome = .drained,
        suspendsUntilCancelled: Bool = false
    ) {
        self.outcome = outcome
        self.suspendsUntilCancelled = suspendsUntilCancelled
    }

    func drainPendingUploads() async {
        legacyCount += 1
    }

    func drainPendingUploads(
        using budget: PendingLocationUploadDrainBudget
    ) async -> PendingLocationUploadDrainOutcome {
        boundedCount += 1
        self.budget = .init(budget: budget, receivedAt: .now)
        didStartBoundedDrain = true
        if suspendsUntilCancelled {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch is CancellationError {
                didObserveCancellation = true
            } catch {}
        }
        return outcome
    }

    func drainCount() -> Int {
        legacyCount + boundedCount
    }

    func legacyDrainCount() -> Int {
        legacyCount
    }

    func boundedDrainCount() -> Int {
        boundedCount
    }

    func recordedBudget() -> RecordedBudget? {
        budget
    }

    func hasStartedBoundedDrain() -> Bool {
        didStartBoundedDrain
    }

    func observedCancellation() -> Bool {
        didObserveCancellation
    }
}

private actor SuspendedMesoGate: NotificationGating {
    private let barrier = AsyncGate()
    private var started = false
    private var released = false

    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        started = true
        await barrier.wait()
        return true
    }

    func finish(_ event: NotificationEvent, didSchedule: Bool) async {
        released = !didSchedule
    }

    func hasStarted() -> Bool { started }
    func finishedWithoutScheduling() -> Bool { released }
    func resume() async { await barrier.open() }
}

private struct StaticSettingsProvider: NotificationSettingsProviding {
    let settings: NotificationSettings

    func current() async -> NotificationSettings {
        settings
    }
}

private actor MutableSettingsProvider: NotificationSettingsProviding {
    private var settings: NotificationSettings

    init(settings: NotificationSettings) {
        self.settings = settings
    }

    func current() async -> NotificationSettings {
        settings
    }

    func update(_ settings: NotificationSettings) {
        self.settings = settings
    }
}

private actor RecordingRiskSender: NotificationSending {
    struct SentNotification: Sendable {
        let title: String
        let body: String
        let subtitle: String
        let id: String
    }

    private var notifications: [SentNotification] = []

    func send(title: String, body: String, subtitle: String, id: String) async -> Bool {
        notifications.append(.init(title: title, body: body, subtitle: subtitle, id: id))
        return true
    }

    func sent() -> [SentNotification] {
        notifications
    }
}

private actor CancellationAwareBlockingNotificationSender: NotificationSending {
    private var didStart = false
    private var didObserveCancellation = false

    func send(title _: String, body _: String, subtitle _: String, id _: String) async -> Bool {
        didStart = true
        do {
            try await Task.sleep(for: .seconds(60))
            return true
        } catch is CancellationError {
            didObserveCancellation = true
            return false
        } catch {
            return false
        }
    }

    func hasStarted() -> Bool {
        didStart
    }

    func observedCancellation() -> Bool {
        didObserveCancellation
    }
}

private actor SuccessfulOnCancellationNotificationSender: NotificationSending {
    private var didStart = false
    private var didObserveCancellation = false

    func send(title _: String, body _: String, subtitle _: String, id _: String) async -> Bool {
        didStart = true
        do {
            try await Task.sleep(for: .seconds(60))
            return false
        } catch is CancellationError {
            didObserveCancellation = true
            return true
        } catch {
            return false
        }
    }

    func hasStarted() -> Bool {
        didStart
    }

    func observedCancellation() -> Bool {
        didObserveCancellation
    }
}

private actor InMemoryRiskChangeStore: NotificationStateStoring {
    private var stamp: String?

    init(stamp: String? = nil) {
        self.stamp = stamp
    }

    func lastStamp() async -> String? {
        stamp
    }

    func setLastStamp(_ stamp: String) async {
        self.stamp = stamp
    }
}

private actor SequentialHomeIngestionCoordinator: HomeIngestionCoordinating {
    private var snapshots: [HomeSnapshot]
    private var lastSnapshot: HomeSnapshot

    init(snapshots: [HomeSnapshot]) {
        self.snapshots = snapshots
        self.lastSnapshot = snapshots.last ?? .empty
    }

    func enqueue(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) {}

    func enqueue(_ request: HomeIngestionRequest) {}

    func enqueueAndWait(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) async throws -> HomeSnapshot {
        try await enqueueAndWait(.init(trigger: trigger, locationContext: locationContext, remoteAlertContext: remoteAlertContext))
    }

    func enqueueAndWait(
        _ request: HomeIngestionRequest,
        progress: HomeIngestionProgressHandler?,
        publication: HomeIngestionPublicationHandler?
    ) async throws -> HomeSnapshot {
        _ = progress
        _ = publication
        guard snapshots.isEmpty == false else { return lastSnapshot }
        let snapshot = snapshots.removeFirst()
        lastSnapshot = snapshot
        return snapshot
    }
}

private enum ScriptedCoordinatorError: Error {
    case failed
}

private actor ScriptedHomeIngestionCoordinator: HomeIngestionCoordinating {
    enum Response: Sendable {
        case snapshot(HomeSnapshot)
        case failure(ScriptedCoordinatorError)
    }

    private var responses: [Response]

    init(responses: [Response]) {
        self.responses = responses
    }

    func enqueue(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) {}

    func enqueue(_ request: HomeIngestionRequest) {}

    func enqueueAndWait(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) async throws -> HomeSnapshot {
        try await enqueueAndWait(.init(trigger: trigger, locationContext: locationContext, remoteAlertContext: remoteAlertContext))
    }

    func enqueueAndWait(
        _ request: HomeIngestionRequest,
        progress: HomeIngestionProgressHandler?,
        publication: HomeIngestionPublicationHandler?
    ) async throws -> HomeSnapshot {
        _ = progress
        _ = publication
        guard responses.isEmpty == false else { return .empty }
        switch responses.removeFirst() {
        case .snapshot(let snapshot):
            return snapshot
        case .failure(let error):
            throw error
        }
    }
}

private extension BackgroundOrchestratorCadenceTests {
    struct RiskSystem {
        let orchestrator: BackgroundOrchestrator
        let modelContainer: ModelContainer

        struct HealthRecord: Sendable {
            let didNotify: Bool
            let reasonNoNotify: String?
        }

        func latestHealthRecord() async throws -> HealthRecord? {
            try await MainActor.run {
                let context = ModelContext(modelContainer)
                var descriptor = FetchDescriptor<BgRunSnapshot>(
                    sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
                )
                descriptor.fetchLimit = 1
                guard let health = try context.fetch(descriptor).first else {
                    return nil
                }
                return HealthRecord(didNotify: health.didNotify, reasonNoNotify: health.reasonNoNotify)
            }
        }

        func recordedCadences() async throws -> [Int] {
            try await MainActor.run {
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<BgRunSnapshot>(
                    sortBy: [SortDescriptor(\.endedAt, order: .forward)]
                )
                return try context.fetch(descriptor).map(\.cadence)
            }
        }
    }

    func makeRiskSystem<Settings: NotificationSettingsProviding>(
        coordinator: any HomeIngestionCoordinating,
        morningEngine: MorningEngine? = nil,
        riskChangeEngine: RiskChangeEngine,
        settingsProvider: Settings,
        wssiIngestion: WSSIForegroundIngestion? = nil
    ) async throws -> RiskSystem {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        try await MainActor.run { try TestStore.reset(BgRunSnapshot.self, in: container) }

        let healthStore = BgHealthStore(modelContainer: container)
        let orchestrator = BackgroundOrchestrator(
            coordinator: coordinator,
            policy: RefreshPolicy(),
            engine: morningEngine ?? MorningEngine(
                rule: NoopMorningRule(),
                gate: AllowAllGate(),
                composer: NoopComposer(),
                sender: NoopSender()
            ),
            mesoEngine: MesoEngine(
                rule: NoopMesoRule(),
                gate: AllowAllGate(),
                composer: NoopComposer(),
                sender: NoopSender(),
                spc: FakeSpcProvider(activeMesos: [])
            ),
            riskChangeEngine: riskChangeEngine,
            health: healthStore,
            cadence: CadencePolicy(),
            notificationSettingsProvider: settingsProvider,
            pendingUploadDrainer: NoOpLocationUploadCoordinator(),
            wssiIngestion: wssiIngestion
        )

        return .init(orchestrator: orchestrator, modelContainer: container)
    }

    func makeRiskSystem<Settings: NotificationSettingsProviding>(
        snapshot: HomeSnapshot? = nil,
        snapshots: [HomeSnapshot]? = nil,
        morningEngine: MorningEngine? = nil,
        riskChangeEngine: RiskChangeEngine,
        settingsProvider: Settings
    ) async throws -> RiskSystem {
        let coordinator: any HomeIngestionCoordinating
        if let snapshots {
            coordinator = SequentialHomeIngestionCoordinator(snapshots: snapshots)
        } else {
            coordinator = RecordingHomeIngestionCoordinator(snapshot: snapshot ?? .empty)
        }
        return try await makeRiskSystem(
            coordinator: coordinator,
            morningEngine: morningEngine,
            riskChangeEngine: riskChangeEngine,
            settingsProvider: settingsProvider
        )
    }

    func makeRiskChangeEngine<Sender: NotificationSending>(
        sender: Sender,
        store: any NotificationStateStoring = InMemoryRiskChangeStore()
    ) -> RiskChangeEngine {
        RiskChangeEngine(
            rule: RiskChangeRule(),
            gate: RiskChangeGate(store: store),
            composer: RiskChangeComposer(),
            sender: sender
        )
    }

    func makeRiskChange(
        projectionKey: String = "projection:alpha",
        previous: RiskProfile,
        current: RiskProfile,
        locationSummary: String = "Denver, CO"
    ) -> RiskProfileChange {
        RiskProfileChange(
            previous: previous,
            current: current,
            projectionKey: projectionKey,
            locationSummary: locationSummary
        )!
    }

    func makeRiskProfile(
        storm: StormRiskLevel,
        severe: SevereWeatherThreat,
        fire: FireRiskLevel
    ) -> RiskProfile {
        RiskProfile(stormRisk: storm, severeRisk: severe, fireRisk: fire)
    }

    func makeMorningEngine<Sender: NotificationSending>(
        sender: Sender,
        gate: any NotificationGating = AllowAllGate()
    ) -> MorningEngine {
        MorningEngine(
            rule: AmRangeLocalRule(window: 0..<24),
            gate: gate,
            composer: MorningComposer(),
            sender: sender
        )
    }

    static func makeRiskSnapshot(change: RiskProfileChange?) -> HomeSnapshot {
        let context = makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        return HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: change?.current.stormRisk ?? .enhanced,
            severeRisk: change?.current.severeRisk ?? .allClear,
            fireRisk: change?.current.fireRisk ?? .clear,
            riskProfileChange: change
        )
    }
}

private struct NoopMorningRule: NotificationRuleEvaluating {
    func evaluate(_ ctx: MorningContext) -> NotificationEvent? {
        nil
    }
}

private struct NoopMesoRule: MesoNotificationRuleEvaluating {
    func evaluate(_ ctx: MesoContext) -> NotificationEvent? {
        nil
    }
}

private struct AllowAllGate: NotificationGating {
    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        true
    }
}

private struct NoopComposer: NotificationComposing {
    func compose(_ event: NotificationEvent) -> (title: String, body: String, subtitle: String) {
        ("", "", "")
    }
}

private struct NoopSender: NotificationSending {
    func send(title: String, body: String, subtitle: String, id: String) async -> Bool { true }
}

private struct FailingNotificationSender: NotificationSending {
    func send(title: String, body: String, subtitle: String, id: String) async -> Bool { false }
}

private actor FirstMorningOnlyGate: NotificationGating {
    private var hasAllowed = false

    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        defer { hasAllowed = true }
        return hasAllowed == false
    }
}

@Suite("Background health persistence", .serialized)
struct BgHealthStoreTests {
    @Test("Started runs survive a disk-backed reopen as incomplete")
    func startedRun_diskReopenRemainsIncomplete() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BgHealthStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let storeURL = root.appendingPathComponent("SkyAware_Data.sqlite")
        let startedAt = Date(timeIntervalSince1970: 1_000)

        do {
            let container = try makeDiskContainer(url: storeURL)
            try await BgHealthStore(modelContainer: container).start(runId: "started-run", startedAt: startedAt)
        }

        let reopened = try makeDiskContainer(url: storeURL)
        let run = try #require(await healthRun(id: "started-run", in: reopened))
        #expect(run.startedAt == startedAt)
        #expect(run.isComplete == false)
        #expect(run.endedAt == nil)
        #expect(run.outcome == nil)
    }

    @Test("A legacy background health store migrates without losing terminal fields")
    func legacyStore_migratesToCurrentBackgroundHealthSchema() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BgHealthStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let storeURL = root.appendingPathComponent("SkyAware_Data.sqlite")
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let endedAt = Date(timeIntervalSince1970: 1_010)
        let nextScheduledAt = Date(timeIntervalSince1970: 2_200)

        let compressed = try #require(Data(base64Encoded: legacyBgHealthStoreBase64, options: .ignoreUnknownCharacters))
        let data = try (compressed as NSData).decompressed(using: .zlib) as Data
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        try #require(digest == "467a944db3c867c81f18bc726f694f81acd365a11dd9c81cc3eec9a9b32b7967")
        try data.write(to: storeURL, options: .atomic)

        // Each iteration releases its container/context before reopening the migrated disk store.
        for _ in 0..<2 {
            let run = try await MainActor.run {
                try autoreleasepool {
                    let migrated = try makeDiskContainer(url: storeURL)
                    return try #require(try healthRun(id: "legacy-run", in: migrated))
                }
            }
            #expect(run.startedAt == startedAt)
            #expect(run.endedAt == endedAt)
            #expect(run.outcome == .success && run.outcomeRaw == nil)
            #expect(run.didNotify && run.reasonNoNotify == nil && run.budgetSecUsed == 10)
            #expect(run.nextScheduledAt == nextScheduledAt)
            #expect(run.cadence == 20 && run.cadenceReason == "legacy" && run.activeSeconds == 8)
            #expect(run.uploadDrainDurationSeconds == nil && run.uploadDrainOutcome == nil)
            #expect(run.ingestionDurationSeconds == nil && run.ingestionOutcome == nil)
            #expect(run.fallbackSchedulingOutcome == nil && run.authoritativeSchedulingOutcome == nil)
        }
    }

    @Test("Finalization updates the started diagnostic record without inserting another")
    func finalize_updatesOriginalRun() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        let store = BgHealthStore(modelContainer: container)
        try await store.start(runId: "single-run", startedAt: .distantPast)
        try await store.finalize(
            runId: "single-run",
            with: finalization(outcome: .success, desiredNextRunAt: Date(timeIntervalSince1970: 1_200))
        )

        let runs = try await healthRuns(in: container)
        #expect(runs.count == 1)
        #expect(runs[0].outcome == .success)
        #expect(runs[0].uploadDrainOutcome == .remaining)
        #expect(runs[0].ingestionOutcome == .completed)
        #expect(runs[0].uploadDrainDurationSeconds == 2)
        #expect(runs[0].ingestionDurationSeconds == 8)
    }

    @Test("Terminal outcomes preserve success skip failure cancellation and expiration distinctly")
    func terminalOutcomes_remainDistinct() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        let store = BgHealthStore(modelContainer: container)
        let outcomes: [BgRunOutcome] = [.success, .skipped, .failed, .cancelled, .expired]

        for (index, outcome) in outcomes.enumerated() {
            let runId = "run-\(index)"
            try await store.start(runId: runId, startedAt: Date(timeIntervalSince1970: Double(index)))
            try await store.finalize(runId: runId, with: finalization(outcome: outcome, desiredNextRunAt: .distantFuture))
        }

        let persisted = try await healthRuns(in: container).compactMap(\.outcome).sorted { $0.rawValue < $1.rawValue }
        #expect(persisted == outcomes.sorted { $0.rawValue < $1.rawValue })
    }

    @Test("Desired cadence remains independent from failed scheduler submissions")
    func schedulingFailure_doesNotReplaceDesiredCadence() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        let store = BgHealthStore(modelContainer: container)
        let desiredNextRunAt = Date(timeIntervalSince1970: 1_200)
        try await store.start(runId: "scheduling-run", startedAt: .distantPast)
        try await store.finalize(
            runId: "scheduling-run",
            with: finalization(outcome: .failed, desiredNextRunAt: desiredNextRunAt)
        )
        try await store.recordScheduling(
            runId: "scheduling-run",
            phase: .fallback,
            outcome: .submissionFailed
        )
        try await store.recordScheduling(
            runId: "scheduling-run",
            phase: .authoritative,
            outcome: .restorationFailed
        )

        let run = try #require(await healthRun(id: "scheduling-run", in: container))
        #expect(run.nextScheduledAt == desiredNextRunAt)
        #expect(run.fallbackSchedulingOutcome == .submissionFailed)
        #expect(run.authoritativeSchedulingOutcome == .restorationFailed)
        #expect(run.authoritativeSchedulingOutcome?.preservesSuccessor == false)
    }

    private func finalization(outcome: BgRunOutcome, desiredNextRunAt: Date) -> BgRunFinalization {
        .init(
            endedAt: Date(timeIntervalSince1970: 1_100),
            outcome: outcome,
            didNotify: false,
            reasonNoNotify: "deterministic test",
            budgetSecUsed: 10,
            desiredNextRunAt: desiredNextRunAt,
            cadence: 20,
            cadenceReason: "test",
            active: .seconds(10),
            uploadDrainDuration: .seconds(2),
            uploadDrainOutcome: .remaining,
            ingestionDuration: .seconds(8),
            ingestionOutcome: .completed
        )
    }

    private func makeDiskContainer(url: URL) throws -> ModelContainer {
        let schema = Schema([BgRunSnapshot.self])
        let configuration = ModelConfiguration("SkyAware_Data", schema: schema, url: url)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}

@MainActor
private func healthRun(id: String, in container: ModelContainer) throws -> BgRunState? {
    let descriptor = FetchDescriptor<BgRunSnapshot>(predicate: #Predicate { $0.runId == id })
    return try ModelContext(container).fetch(descriptor).first.map(BgRunState.init)
}

@MainActor
private func healthRuns(in container: ModelContainer) throws -> [BgRunState] {
    try ModelContext(container).fetch(FetchDescriptor<BgRunSnapshot>()).map(BgRunState.init)
}

private struct BgRunState: Sendable {
    let startedAt: Date
    let endedAt: Date?
    let isComplete: Bool
    let outcome: BgRunOutcome?
    let outcomeRaw: String?
    let didNotify: Bool
    let reasonNoNotify: String?
    let budgetSecUsed: Int
    let cadenceReason: String?
    let activeSeconds: Int64
    let uploadDrainDurationSeconds: Int64?
    let uploadDrainOutcome: BgPhaseOutcome?
    let ingestionDurationSeconds: Int64?
    let ingestionOutcome: BgPhaseOutcome?
    let nextScheduledAt: Date?
    let cadence: Int
    let fallbackSchedulingOutcome: BgSchedulingOutcome?
    let authoritativeSchedulingOutcome: BgSchedulingOutcome?

    init(_ snapshot: BgRunSnapshot) {
        startedAt = snapshot.startedAt
        endedAt = snapshot.endedAt
        isComplete = snapshot.isComplete
        outcome = snapshot.outcome
        outcomeRaw = snapshot.outcomeRaw
        didNotify = snapshot.didNotify
        reasonNoNotify = snapshot.reasonNoNotify
        budgetSecUsed = snapshot.budgetSecUsed
        cadenceReason = snapshot.cadenceReason
        activeSeconds = snapshot.activeSeconds
        uploadDrainDurationSeconds = snapshot.uploadDrainDurationSeconds
        uploadDrainOutcome = snapshot.uploadDrainOutcome
        ingestionDurationSeconds = snapshot.ingestionDurationSeconds
        ingestionOutcome = snapshot.ingestionOutcome
        nextScheduledAt = snapshot.nextScheduledAt
        cadence = snapshot.cadence
        fallbackSchedulingOutcome = snapshot.fallbackSchedulingOutcome
        authoritativeSchedulingOutcome = snapshot.authoritativeSchedulingOutcome
    }
}

// Authentic V1 SQLite generated in a legacy-only process with Xcode 27.2 / Swift 6.4.2 on macOS 27.2.
// Regenerate with tools/fixtures/generate_bg_health_v1.swift; keep the digest and payload together.
// Embedded data avoids dependence on source paths or test-bundle resource membership in Xcode Cloud.
private let legacyBgHealthStoreBase64 = """
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
/B8AAAAAAAAAABietHBm5CiZXJYkVcj+CQ==
"""

private func waitUntil(
    timeout: Duration = .seconds(1),
    interval: Duration = .milliseconds(20),
    _ condition: @escaping @Sendable () async -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() {
            return true
        }
        try? await Task.sleep(for: interval)
    }
    return await condition()
}

@MainActor
struct WSSIBackgroundIngestionTests {
    private let now = Date(timeIntervalSince1970: 1_794_440_000)
    private typealias Gate = WSSIAcceptanceTests.Gate
    private typealias Probe = WSSIAcceptanceTests.Probe
    private func scope(_ west: Double = -112) throws -> WSSIScope {
        try WSSIScope(south: 36, west: west, north: 43, east: west + 10)
    }
    private func store() throws -> WSSISnapshotStore {
        WSSISnapshotStore(modelContainer: try TestStore.container(for: SkyAwarePersistenceSchema.models))
    }
    private func client(_ fixture: WSSIClientTests.Fixture) throws -> WSSIClient {
        try WSSIClient(transport: { try await fixture.get($0, $1) })
    }

    @Test("App-default background feasibility gate defers due acquisition without requests or foreground backoff")
    func backgroundFeasibilityDeferral() async throws {
        let store = try store(), region = try scope(), date = now
        let original = try await store.refreshCoverage(scope: region,
            client: client(.init(mode: .empty)), date: { date })
        let fixture = WSSIClientTests.Fixture(mode: .empty)
        let outcomes = Mutex<[WSSIForegroundIngestion.Outcome]>([])
        // Foreground's internal gate is enabled; background's separate gate uses the app default.
        let ingestion = WSSIForegroundIngestion(store: store, client: try client(fixture),
            enabled: { true }, date: { date.addingTimeInterval(7200) },
            observe: { value in outcomes.withLock { $0.append(value) } })
        await ingestion.refreshBackground(scope: region, context: backgroundContext())
        await ingestion.refreshBackground(scope: region, context: backgroundContext())
        #expect(outcomes.withLock { $0 } == [.deferredFeasibility, .deferredFeasibility])
        #expect(await fixture.count == 0)
        #expect(try await store.acceptedCoverage(at: date).snapshots == [original])
        await ingestion.admit(scope: region, foreground: true)
        await ingestion.waitForIdle()
        #expect(outcomes.withLock { $0.last } == .accepted)
        #expect(await fixture.count > 0)
    }

    @Test("Default background deferral bypasses ownership while foreground selection is suspended")
    func backgroundDeferralDoesNotOwnForegroundWork() async throws {
        let store = try store(), region = try scope(), date = now
        let gate = Gate(), fixture = WSSIClientTests.Fixture(mode: .empty)
        let outcomes = Mutex<[WSSIForegroundIngestion.Outcome]>([])
        let ingestion = WSSIForegroundIngestion(store: store, client: try client(fixture),
            enabled: { true }, date: { date }, selectCoverage: { region, date in
                await gate.pause()
                try await store.selectCoverage(region, at: date)
            }, observe: { value in outcomes.withLock { $0.append(value) } })
        let foreground = Task { await ingestion.admit(scope: region, foreground: true) }
        await gate.waitForEntry()
        await ingestion.refreshBackground(scope: region, context: backgroundContext())
        #expect(outcomes.withLock { $0 } == [.deferredFeasibility])
        #expect(await fixture.count == 0)
        await gate.open()
        await foreground.value
        await ingestion.waitForIdle()
        #expect(outcomes.withLock { $0 } == [.deferredFeasibility, .attempted, .accepted])
        #expect(try await store.acceptedCoverage(at: date).snapshots.count == 1)
    }

    @Test("Third background scope replaces secondary cache without changing foreground selection")
    func backgroundRetention() async throws {
        let store = try store(), date = now
        for west in [-112.0, -111.0] {
            let region = try scope(west)
            try await store.selectCoverage(region, at: date)
            _ = try await store.refreshCoverage(scope: region,
                client: client(.init(mode: .empty, geometry: "\(west),36.0,\(west + 10),43.0")), date: { date })
        }
        let outcomes = Mutex<[WSSIForegroundIngestion.Outcome]>([])
        let c = try scope(-110)
        let ingestion = WSSIForegroundIngestion(store: store,
            client: try client(.init(mode: .empty, geometry: "-110.0,36.0,-100.0,43.0")),
            enabled: { true }, backgroundAcquisitionEnabled: true, date: { date }, observe: { value in outcomes.withLock { $0.append(value) } })
        await ingestion.refreshBackground(scope: c, context: backgroundContext())
        let coverage = try await store.acceptedCoverage(at: date)
        #expect(outcomes.withLock { $0 } == [.accepted])
        #expect(coverage.selectedScope == (try scope(-111)))
        #expect(coverage.snapshots.map(\.snapshot.scope) == [try scope(-111), c])
    }

    @Test("Expired validity requires acquisition despite recent accepted verification")
    func backgroundExpiredValidity() async throws {
        let store = try store(), region = try scope(), date = now
        let layers = WSSIProduct.allCases.flatMap { product in
            WSSIPeriod.allCases.map { period in
                WSSISnapshotLayer(product: product, period: period, state: .identifiedEmpty,
                    issuedAt: date.addingTimeInterval(-100), validFrom: date.addingTimeInterval(-90),
                    validTo: date.addingTimeInterval(-1), features: [])
            }
        }
        let snapshot = WSSISnapshot(scope: region, source: URL(string: "https://example.test/wssi")!,
            acquisitionStartedAt: date, verifiedAt: date, provenance: "fixture", layers: layers)
        let original = try await store.replace(with: snapshot, select: true, now: date)
        let outcomes = Mutex<[WSSIForegroundIngestion.Outcome]>([])
        let ingestion = WSSIForegroundIngestion(store: store,
            client: try WSSIClient(transport: { _, _ in throw WSSIAcquisitionError.invalidResponse }),
            enabled: { true }, backgroundAcquisitionEnabled: true, date: { date }, observe: { value in outcomes.withLock { $0.append(value) } })
        await ingestion.refreshBackground(scope: region, context: backgroundContext())
        #expect(outcomes.withLock { $0 } == [.failed])
        #expect(try await store.acceptedCoverage(at: date).snapshots == [original])
    }

    @Test("Parent cancellation drains active background acquisition and releases shared ownership")
    func backgroundParentCancellation() async throws {
        let store = try store(), region = try scope(), date = now
        let original = try await store.refreshCoverage(scope: region,
            client: client(.init(mode: .empty)), date: { date })
        let first = Mutex(true), gate = Gate()
        let outcomes = Mutex<[WSSIForegroundIngestion.Outcome]>([])
        let ingestion = WSSIForegroundIngestion(store: store,
            client: try WSSIClient(transport: { _, _ in
                if first.withLock({ value in defer { value = false }; return value }) {
                    await gate.pause()
                    try Task.checkCancellation()
                }
                throw WSSIAcquisitionError.invalidResponse
            }), enabled: { true }, backgroundAcquisitionEnabled: true, date: { date.addingTimeInterval(7200) },
            observe: { value in outcomes.withLock { $0.append(value) } })
        let context = backgroundContext()
        let task = Task { await ingestion.refreshBackground(scope: region, context: context) }
        await gate.waitForEntry()
        task.cancel()
        await gate.open()
        await task.value
        #expect(outcomes.withLock { $0 } == [.cancelled])
        #expect(try await store.acceptedCoverage(at: date).snapshots == [original])
        await ingestion.refreshBackground(scope: try scope(-111), context: backgroundContext())
        #expect(outcomes.withLock { $0 } == [.cancelled, .failed])
    }

    private func backgroundContext(seconds: Int = 30) -> BackgroundRefreshExecutionContext {
        let start = ContinuousClock.now
        return .init(budget: .init(start: start, completionDeadline: start + .seconds(seconds),
                                  finalizationReserve: .seconds(5)))
    }

    @Test("Background reuses durable provenance across owner restart, then accepts due coverage")
    func backgroundCadence() async throws {
        let store = try store(), region = try scope()
        let fixture = WSSIClientTests.Fixture(mode: .empty)
        let date = now
        let accepted = try await store.refreshCoverage(scope: region, client: client(fixture), date: { date })
        let clock = Mutex(now)
        let outcomes = Mutex<[WSSIForegroundIngestion.Outcome]>([])
        let failing = Mutex(false)
        let ingestion = WSSIForegroundIngestion(store: store,
            client: try WSSIClient(transport: { request, ceiling in
                if failing.withLock({ $0 }) { throw WSSIAcquisitionError.invalidResponse }
                return try await fixture.get(request, ceiling)
            }), enabled: { true }, backgroundAcquisitionEnabled: true, date: { clock.withLock { $0 } },
            observe: { value in outcomes.withLock { $0.append(value) } })
        let count = await fixture.count
        await ingestion.refreshBackground(scope: region, context: backgroundContext())
        #expect(await fixture.count == count)
        #expect(outcomes.withLock { $0.last } == .fresh)
        clock.withLock { $0 = now.addingTimeInterval(7200) }
        await ingestion.refreshBackground(scope: region, context: backgroundContext())
        #expect(outcomes.withLock { $0.last } == .accepted)
        let updated = try #require(try await store.acceptedCoverage(at: now).snapshots.first)
        #expect(updated.snapshot.verifiedAt == now.addingTimeInterval(7200))
        #expect(updated.revision == accepted.revision) // Identical source content retains its canonical revision.
        #expect(await fixture.count > count)
        clock.withLock { $0 = now.addingTimeInterval(14400) }
        failing.withLock { $0 = true }
        await ingestion.refreshBackground(scope: region, context: backgroundContext())
        #expect(outcomes.withLock { $0.last } == .failed)
        #expect(try await store.acceptedCoverage(at: now).snapshots == [updated])
        await ingestion.refreshBackground(scope: region, context: backgroundContext())
        #expect(outcomes.withLock { $0.last } == .backoff)
    }

    @Test("Background admission skips disabled, insufficient-budget and cancelled runs without requests")
    func backgroundAdmission() async throws {
        let fixture = WSSIClientTests.Fixture(mode: .empty)
        let enabled = Mutex(false)
        let outcomes = Mutex<[WSSIForegroundIngestion.Outcome]>([])
        let date = now, region = try scope()
        let ingestion = WSSIForegroundIngestion(store: try store(), client: try client(fixture),
            enabled: { enabled.withLock { $0 } }, backgroundAcquisitionEnabled: true, date: { date },
            observe: { value in outcomes.withLock { $0.append(value) } })
        await ingestion.refreshBackground(scope: region, context: backgroundContext())
        enabled.withLock { $0 = true }
        await ingestion.refreshBackground(scope: region, context: backgroundContext(seconds: 9))
        let context = backgroundContext()
        await context.deadlineState.markExceeded()
        await ingestion.refreshBackground(scope: region, context: context)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await ingestion.refreshBackground(scope: region, context: self.backgroundContext())
        }
        await task.value
        #expect(outcomes.withLock { $0 } == [.disabled, .deadline, .deadline, .cancelled])
        #expect(await fixture.count == 0)
    }

    @Test("Background deadline cancels acquisition; overlapping runs skip and prior coverage survives")
    func backgroundDeadlineAndOverlap() async throws {
        let store = try store(), region = try scope(), date = now
        let original = try await store.refreshCoverage(scope: region, client: client(.init(mode: .empty)), date: { date })
        let gate = Gate()
        let outcomes = Mutex<[WSSIForegroundIngestion.Outcome]>([])
        let ingestion = WSSIForegroundIngestion(store: store,
            client: try WSSIClient(transport: { _, _ in
                await gate.pause()
                try await Task.sleep(for: .seconds(3600))
                throw CancellationError()
            }), enabled: { true }, backgroundAcquisitionEnabled: true, date: { date.addingTimeInterval(7200) },
            observe: { value in outcomes.withLock { $0.append(value) } })
        let context = backgroundContext()
        let task = Task {
            await ingestion.refreshBackground(scope: region, context: context, waitUntil: { _ in
                await gate.waitForEntry()
                await ingestion.refreshBackground(scope: region, context: context)
                await gate.open()
            })
        }
        await task.value
        #expect(outcomes.withLock { $0 } == [.busy, .deadline])
        #expect(try await store.acceptedCoverage(at: now).snapshots == [original])
        #expect(await !context.deadlineState.exceeded()) // Optional timeout cannot fail the alert run.
    }

    @Test("Background location admission rejects stale, inaccurate and unsupported coverage", arguments: [0, 1, 2])
    func backgroundLocationAdmission(kind: Int) async throws {
        let fixture = WSSIClientTests.Fixture(mode: .empty), date = now
        let outcomes = Mutex<[WSSIForegroundIngestion.Outcome]>([])
        let ingestion = WSSIForegroundIngestion(store: try store(), client: try client(fixture),
            enabled: { true }, backgroundAcquisitionEnabled: true, date: { date }, observe: { value in outcomes.withLock { $0.append(value) } })
        let location = LocationSnapshot(coordinates: .init(latitude: kind == 2 ? 60 : 40, longitude: -105),
            timestamp: kind == 0 ? date.addingTimeInterval(-5401) : date, accuracy: kind == 1 ? 500 : 10)
        await ingestion.refreshBackground(location: location, context: backgroundContext())
        #expect(outcomes.withLock { $0 } == [.inapplicable])
        #expect(await fixture.count == 0)
    }

    @Test("Background fills missing coverage without overriding newer foreground selection")
    func backgroundMovement() async throws {
        let store = try store(), a = try scope(), b = try scope(-111), date = now
        let gate = Gate(), af = WSSIClientTests.Fixture(mode: .empty)
        let bf = WSSIClientTests.Fixture(mode: .empty, geometry: "-111.0,36.0,-101.0,43.0")
        let probe = Probe(fixture: af, gate: gate)
        let ingestion = WSSIForegroundIngestion(store: store,
            client: try WSSIClient(transport: { request, ceiling in
                let geometry = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                    .queryItems?.first { $0.name == "geometry" }?.value
                if geometry == "-111.0,36.0,-101.0,43.0" { return try await bf.get(request, ceiling) }
                return try await probe.get(request, ceiling)
            }), enabled: { true }, backgroundAcquisitionEnabled: true, date: { date })
        let context = backgroundContext()
        let task = Task { await ingestion.refreshBackground(scope: a, context: context) }
        await gate.waitForEntry()
        await ingestion.admit(scope: b, foreground: true)
        await gate.open()
        await task.value
        await ingestion.waitForIdle()
        let accepted = try await store.acceptedCoverage(at: date)
        #expect(accepted.selectedScope == b)
        #expect(accepted.snapshots.count == 2)
        #expect(accepted.snapshots.contains { $0.snapshot.scope == a })
    }

}
