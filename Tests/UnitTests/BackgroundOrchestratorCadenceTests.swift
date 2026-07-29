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

    @Test("Ingestion finishing before its work deadline remains successful")
    func ingestionBeforeWorkDeadline_remainsSuccessful() async throws {
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

        await ingestionGate.open()
        let outcome = await runTask.value
        let health = try #require(await setup.latestHealthRecord())

        #expect(outcome.result == .success)
        #expect(health.outcome == .success)
        #expect(health.ingestionOutcome == .completed)
        #expect(await deadlineWaiter.observedCancellation())
        #expect(await deadlineState.exceeded() == false)
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

        let morningEngine = MorningEngine(
            rule: NoopMorningRule(),
            gate: AllowAllGate(),
            composer: NoopComposer(),
            sender: NoopSender()
        )
        let mesoEngine = MesoEngine(
            rule: NoopMesoRule(),
            gate: AllowAllGate(),
            composer: NoopComposer(),
            sender: NoopSender(),
            spc: spc
        )
        let snapshotStore = HomeSnapshotStore(
            spcRisk: spc,
            spcOutlook: spc,
            arcusAlerts: alertProvider
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
            riskChangeEngine: makeRiskChangeEngine(sender: NoopSender()),
            health: healthStore,
            cadence: CadencePolicy(),
            notificationSettingsProvider: StaticSettingsProvider(settings: settings),
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
        workDeadlineAlreadyReached: Bool = false
    ) async throws -> SystemUnderTest {
        try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false),
            coordinator: coordinator,
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
    func syncConvectiveOutlooks() async {
        syncConvectiveOutlooksCalls += 1
        syncExecutionModeValues.append(HTTPExecutionMode.current)
    }
    func syncMesoscaleDiscussions() async {
        syncExecutionModeValues.append(HTTPExecutionMode.current)
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

    func sync(context: LocationContext) async {}

    func syncRemoteAlert(id: String, revisionSent: Date?) async {}

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
        settingsProvider: Settings
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
            pendingUploadDrainer: NoOpLocationUploadCoordinator()
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

        do {
            let legacySchema = Schema(versionedSchema: BgRunSnapshotSchemaV1.self)
            let legacyConfiguration = ModelConfiguration("SkyAware_Data", schema: legacySchema, url: storeURL)
            let legacyContainer = try ModelContainer(for: legacySchema, configurations: legacyConfiguration)
            let legacyContext = ModelContext(legacyContainer)
            legacyContext.insert(
                BgRunSnapshotSchemaV1.BgRunSnapshot(
                    runId: "legacy-run",
                    startedAt: startedAt,
                    endedAt: endedAt,
                    outcomeCode: 0,
                    didNotify: true,
                    reasonNoNotify: nil,
                    budgetSecUsed: 10,
                    nextScheduledAt: nextScheduledAt,
                    cadence: 20,
                    cadenceReason: "legacy",
                    activeSeconds: 8
                )
            )
            try legacyContext.save()
        }

        let migrated = try makeDiskContainer(url: storeURL)
        let run = try #require(await healthRun(id: "legacy-run", in: migrated))
        #expect(run.startedAt == startedAt)
        #expect(run.endedAt == endedAt)
        #expect(run.outcome == .success)
        #expect(run.nextScheduledAt == nextScheduledAt)
        #expect(run.cadence == 20)
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

enum BgRunSnapshotSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    static var models: [any PersistentModel.Type] { [BgRunSnapshot.self] }

    @Model
    final class BgRunSnapshot {
        @Attribute(.unique) var runId: String
        var startedAt: Date
        var endedAt: Date
        var outcomeCode: Int
        var didNotify: Bool
        var reasonNoNotify: String?
        var budgetSecUsed: Int
        var nextScheduledAt: Date
        var cadence: Int
        var cadenceReason: String?
        var activeSeconds: Int64

        init(
            runId: String,
            startedAt: Date,
            endedAt: Date,
            outcomeCode: Int,
            didNotify: Bool,
            reasonNoNotify: String?,
            budgetSecUsed: Int,
            nextScheduledAt: Date,
            cadence: Int,
            cadenceReason: String?,
            activeSeconds: Int64
        ) {
            self.runId = runId
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.outcomeCode = outcomeCode
            self.didNotify = didNotify
            self.reasonNoNotify = reasonNoNotify
            self.budgetSecUsed = budgetSecUsed
            self.nextScheduledAt = nextScheduledAt
            self.cadence = cadence
            self.cadenceReason = cadenceReason
            self.activeSeconds = activeSeconds
        }
    }
}

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
