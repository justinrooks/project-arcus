import Foundation
import Testing
@testable import SkyAware

@Suite("Home Ingestion Coordinator", .serialized)
struct HomeIngestionCoordinatorTests {
    @Test("trigger plans preserve the expected lane selection")
    func triggerPlans_matchExpectedCoverage() {
        let activatePlan = HomeIngestionPlan(
            request: .init(trigger: .foregroundActivate)
        )
        #expect(activatePlan.lanes == .all)
        #expect(activatePlan.forcedLanes.isEmpty)
        #expect(activatePlan.locationRequest == .prepare(requiresFreshLocation: true, showsAuthorizationPrompt: true))

        let manualPlan = HomeIngestionPlan(
            request: .init(trigger: .manualRefresh)
        )
        #expect(manualPlan.lanes == .all)
        #expect(manualPlan.forcedLanes == .all)
        #expect(manualPlan.locationRequest == .prepare(requiresFreshLocation: true, showsAuthorizationPrompt: false))

        let tickPlan = HomeIngestionPlan(
            request: .init(trigger: .sessionTick)
        )
        #expect(tickPlan.lanes == [.hotAlerts])
        #expect(tickPlan.forcedLanes.isEmpty)
        #expect(tickPlan.locationRequest == .currentPrepared)

        let locationPlan = HomeIngestionPlan(
            request: .init(trigger: .foregroundLocationChange)
        )
        #expect(locationPlan.lanes == .all)
        #expect(locationPlan.forcedLanes == [.hotAlerts, .weather])
        #expect(locationPlan.locationRequest == .currentPrepared)

        let backgroundRefreshPlan = HomeIngestionPlan(
            request: .init(trigger: .backgroundRefresh)
        )
        #expect(backgroundRefreshPlan.lanes == .all)
        #expect(backgroundRefreshPlan.forcedLanes == [.hotAlerts])
        #expect(backgroundRefreshPlan.locationRequest == .prepare(requiresFreshLocation: true, showsAuthorizationPrompt: false))

        let backgroundLocationPlan = HomeIngestionPlan(
            request: .init(trigger: .backgroundLocationChange)
        )
        #expect(backgroundLocationPlan.lanes == .all)
        #expect(backgroundLocationPlan.forcedLanes == [.hotAlerts, .weather])
        #expect(backgroundLocationPlan.locationRequest == .latestAcceptedSnapshotPrepared)
    }

    @Test("runs one ingestion plan at a time")
    func enqueue_serializesExecution() async {
        let gate = AsyncGate()
        let executor = FakeHomeIngestionExecutor(beforeHotAlertsGate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)

        await coordinator.enqueue(.sessionTick)
        let firstStarted = await waitUntil(timeout: .seconds(5)) {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        await coordinator.enqueue(.manualRefresh)

        let stillSerialized = await waitUntil(timeout: .seconds(2)) {
            await executor.startedPlanCount() == 1
        }
        #expect(stillSerialized)

        await gate.open()

        let secondStarted = await waitUntil(timeout: .seconds(5)) {
            await executor.startedPlanCount() == 2
        }
        #expect(secondStarted)
    }

    @Test("merges pending plans by unioning lanes and force requirements")
    func pendingPlan_mergeUnionsRequirements() async throws {
        let gate = AsyncGate()
        let executor = FakeHomeIngestionExecutor(beforeHotAlertsGate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let remoteContext = HomeRemoteAlertContext(
            alertID: "alert-123",
            revisionSent: Date(timeIntervalSince1970: 700)
        )

        await coordinator.enqueue(.sessionTick)
        let firstStarted = await waitUntil {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        await coordinator.enqueue(.foregroundActivate)
        await coordinator.enqueue(.remoteHotAlertReceived, remoteAlertContext: remoteContext)
        await gate.open()

        let secondStarted = await waitUntil {
            await executor.startedPlanCount() == 2
        }
        #expect(secondStarted)

        let plans = await executor.executedPlans()
        #expect(plans.count == 2)

        let merged = try #require(plans.last)
        #expect(merged.lanes == .all)
        #expect(merged.forcedLanes == [.hotAlerts])
        #expect(merged.remoteAlertContext == remoteContext)
        #expect(merged.provenance.contains(.foregroundActivate))
        #expect(merged.provenance.contains(.remoteHotAlertReceived))
    }

    @Test("manual refresh escalates a queued follow-up plan to a full forced refresh")
    func manualRefresh_escalatesPendingWork() async throws {
        let gate = AsyncGate()
        let executor = FakeHomeIngestionExecutor(beforeHotAlertsGate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)

        await coordinator.enqueue(.sessionTick)
        let firstStarted = await waitUntil {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        await coordinator.enqueue(.backgroundRefresh)
        await coordinator.enqueue(.manualRefresh)
        await gate.open()

        let secondStarted = await waitUntil {
            await executor.startedPlanCount() == 2
        }
        #expect(secondStarted)

        let merged = try #require(await executor.executedPlans().last)
        #expect(merged.lanes == .all)
        #expect(merged.forcedLanes == .all)
        #expect(merged.provenance.contains(.background))
        #expect(merged.provenance.contains(.manualRefresh))
    }

    @Test("newest location-bearing request wins when pending work is merged")
    func locationBearingRequest_replacesOlderPendingLocation() async throws {
        let gate = AsyncGate()
        let executor = FakeHomeIngestionExecutor(beforeHotAlertsGate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let firstContext = makeContext(latitude: 39.75, longitude: -104.44, timestamp: 100)
        let secondContext = makeContext(latitude: 39.90, longitude: -104.10, timestamp: 200)

        await coordinator.enqueue(.sessionTick)
        let firstStarted = await waitUntil {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        await coordinator.enqueue(.foregroundLocationChange, locationContext: firstContext)
        await coordinator.enqueue(.backgroundLocationChange, locationContext: secondContext)
        await gate.open()

        let secondStarted = await waitUntil {
            await executor.startedPlanCount() == 2
        }
        #expect(secondStarted)

        let merged = try #require(await executor.executedPlans().last)
        switch merged.locationRequest {
        case .explicit(let context):
            #expect(context == secondContext)
        default:
            Issue.record("Expected explicit location context for merged location-bearing plan")
        }
    }

    @Test("remote hot-alert requests queue follow-up when active run is not remote-aware")
    func remoteHotAlert_queuesFollowUpWhenActiveRunLacksRemoteContext() async throws {
        let gate = AsyncGate()
        let snapshot = HomeSnapshot(weather: makeWeather())
        let executor = FakeHomeIngestionExecutor(
            snapshot: snapshot,
            beforeHotAlertsGate: gate
        )
        let coordinator = HomeIngestionCoordinator(executor: executor)

        await coordinator.enqueue(.backgroundRefresh)
        let firstStarted = await waitUntil {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        let remoteWaitTask = Task {
            try await coordinator.enqueueAndWait(
                .remoteHotAlertReceived,
                remoteAlertContext: .init(
                    alertID: "alert-456",
                    revisionSent: Date(timeIntervalSince1970: 900)
                )
            )
        }

        await Task.yield()
        #expect(await executor.startedPlanCount() == 1)

        await gate.open()

        let secondStarted = await waitUntil {
            await executor.startedPlanCount() == 2
        }
        #expect(secondStarted)

        let resolvedSnapshot = try await remoteWaitTask.value
        #expect(resolvedSnapshot == snapshot)

        let plans = await executor.executedPlans()
        #expect(plans.count == 2)
        #expect(plans[1].remoteAlertContext?.alertID == "alert-456")
    }

    @Test("remote hot-alert requests queue a follow-up once the active run has passed hot-alert sync")
    func remoteHotAlert_queuesFollowUpAfterHotAlertsComplete() async throws {
        let gate = AsyncGate()
        let executor = FakeHomeIngestionExecutor(afterHotAlertsGate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)

        await coordinator.enqueue(.backgroundRefresh)
        let firstStarted = await waitUntil {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        let hotAlertsCompleted = await waitUntil {
            await executor.completedHotAlertsCount() == 1
        }
        #expect(hotAlertsCompleted)

        let remoteWaitTask = Task {
            try await coordinator.enqueueAndWait(
                .remoteHotAlertReceived,
                remoteAlertContext: .init(
                    alertID: "alert-follow-up",
                    revisionSent: Date(timeIntervalSince1970: 950)
                )
            )
        }

        await Task.yield()
        #expect(await executor.startedPlanCount() == 1)

        await gate.open()

        let secondStarted = await waitUntil {
            await executor.startedPlanCount() == 2
        }
        #expect(secondStarted)

        _ = try await remoteWaitTask.value
        let plans = await executor.executedPlans()
        #expect(plans.count == 2)
        #expect(plans[1].remoteAlertContext?.alertID == "alert-follow-up")
    }

    @Test("coordinator forwards one executor run identity across publication stages")
    func stagedPublication_forwardsOneExecutorRunIdentity() async throws {
        let context = makeContext(latitude: 39.75, longitude: -104.44, timestamp: 100)
        let snapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            weather: makeWeather(),
            weatherRefreshResult: .success(makeWeather()),
            stormRisk: .enhanced
        )
        let executor = FakeHomeIngestionExecutor(snapshot: snapshot, publishesStages: true)
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let recorder = CoordinatorPublicationRecorder()

        let resolved = try await coordinator.enqueueAndWait(
            HomeIngestionRequest(trigger: .manualRefresh, locationContext: context),
            progress: nil,
            publication: { publication in
                await recorder.append(publication)
            }
        )

        #expect(resolved == snapshot)
        let publications = await recorder.values()
        #expect(publications.count == 2)
        #expect(Set(publications.map(\.runID)).count == 1)
        #expect(publications.first?.runID == publications.last?.runID)
        #expect(publications.first?.stage == .core(.init(snapshot: snapshot)))
        #expect(publications.last?.stage == .enrichment(.init(snapshot: snapshot)))
    }

    @Test("pre-canceled callers are currently stored and completed")
    func preCanceledCaller_isStillAcceptedByCoordinator() async throws {
        let submissionGate = AsyncGate()
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)

        let waiter = Task {
            await submissionGate.wait()
            return try await coordinator.enqueueAndWait(.sessionTick)
        }

        waiter.cancel()
        await submissionGate.open()
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        await executor.waitForStartedRun(1)

        await executor.releaseRun(1)
        #expect(try await waiter.value == .empty)
    }

    @Test("canceling an active waiter leaves it callback-eligible until completion")
    func cancelBeforeFinish_activeWaiterReceivesCallbacksAndResult() async throws {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let progressCallbacks = AsyncCount()
        let publicationCallbacks = AsyncCount()

        let waiter = Task {
            try await coordinator.enqueueAndWait(
                HomeIngestionRequest(trigger: .sessionTick),
                progress: { _ in await progressCallbacks.record() },
                publication: { _ in await publicationCallbacks.record() }
            )
        }

        await coordinator.waitForTestWaiterCount(atLeast: 1)
        await executor.waitForStartedRun(1)
        await executor.emitProgress(.started(.lane(.hotAlerts)), forRun: 1)
        await progressCallbacks.waitForCount(1)

        waiter.cancel()
        await executor.emitProgress(.completed(.lane(.hotAlerts)), forRun: 1)
        await executor.emitCorePublication(forRun: 1)
        await progressCallbacks.waitForCount(2)
        await publicationCallbacks.waitForCount(1)

        await executor.releaseRun(1)
        #expect(try await waiter.value == .empty)
        // #333 must instead resume CancellationError and suppress the post-cancellation callbacks.
    }

    @Test("a canceled pending waiter remains stored through the queued follow-up")
    func canceledPendingWaiter_startsAndCompletesQueuedRun() async throws {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)

        let activeWaiter = Task {
            try await coordinator.enqueueAndWait(.sessionTick)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        await executor.waitForStartedRun(1)

        let pendingWaiter = Task {
            try await coordinator.enqueueAndWait(.manualRefresh)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 2)
        #expect(await coordinator.testPendingPlanForWaiterCharacterization() != nil)
        pendingWaiter.cancel()

        await executor.releaseRun(1)
        await executor.waitForStartedRun(2)
        #expect(try await activeWaiter.value == .empty)

        await executor.releaseRun(2)
        #expect(try await pendingWaiter.value == .empty)
        // #333 must remove this waiter before its queued plan can complete it.
    }

    @Test("one canceled compatible waiter does not affect an uncanceled waiter")
    func canceledCompatibleWaiter_doesNotPreventOtherWaiterCompletion() async throws {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)

        let canceledWaiter = Task {
            try await coordinator.enqueueAndWait(.sessionTick)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        await executor.waitForStartedRun(1)

        let retainedWaiter = Task {
            try await coordinator.enqueueAndWait(.sessionTick)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 2)
        canceledWaiter.cancel()

        await executor.releaseRun(1)
        #expect(try await canceledWaiter.value == .empty)
        #expect(try await retainedWaiter.value == .empty)
    }

    @Test("canceling the last waiter does not cancel fire-and-forget shared work")
    func canceledLastWaiter_doesNotCancelCoordinatorOwnedRun() async throws {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)

        await coordinator.enqueue(.sessionTick)
        await executor.waitForStartedRun(1)

        let waiter = Task {
            try await coordinator.enqueueAndWait(.sessionTick)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        waiter.cancel()

        await executor.releaseRun(1)
        await executor.waitForCompletedRun(1)
        #expect(await executor.wasCanceled(run: 1) == false)
        #expect(try await waiter.value == .empty)
    }

    @Test("completion observed before cancellation still resolves the waiter")
    func finishBeforeCancel_waiterCompletesSuccessfully() async throws {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)

        let waiter = Task {
            try await coordinator.enqueueAndWait(.sessionTick)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        await executor.waitForStartedRun(1)

        await executor.releaseRun(1)
        await executor.waitForCompletedRun(1)
        waiter.cancel()

        #expect(try await waiter.value == .empty)
    }

    private func makeContext(
        latitude: Double,
        longitude: Double,
        timestamp: TimeInterval
    ) -> LocationContext {
        let snapshot = LocationSnapshot(
            coordinates: .init(latitude: latitude, longitude: longitude),
            timestamp: Date(timeIntervalSince1970: timestamp),
            accuracy: 25,
            placemarkSummary: "Bennett, CO",
            h3Cell: 123_456
        )
        let grid = GridPointSnapshot(
            nwsId: "BOU/10,20",
            latitude: latitude,
            longitude: longitude,
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

    private func makeWeather() -> SummaryWeather {
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
}

private actor FakeHomeIngestionExecutor: HomeIngestionExecuting {
    private let snapshot: HomeSnapshot
    private let beforeHotAlertsGate: AsyncGate?
    private let afterHotAlertsGate: AsyncGate?
    private let publishesStages: Bool
    private var plans: [HomeIngestionPlan] = []
    private var completedHotAlerts = 0

    init(
        snapshot: HomeSnapshot = .empty,
        beforeHotAlertsGate: AsyncGate? = nil,
        afterHotAlertsGate: AsyncGate? = nil,
        publishesStages: Bool = false
    ) {
        self.snapshot = snapshot
        self.beforeHotAlertsGate = beforeHotAlertsGate
        self.afterHotAlertsGate = afterHotAlertsGate
        self.publishesStages = publishesStages
    }

    func run(plan: HomeIngestionPlan, progress: HomeIngestionRunProgress) async throws -> HomeSnapshot {
        plans.append(plan)

        if plans.count == 1, let beforeHotAlertsGate {
            await beforeHotAlertsGate.wait()
        }

        if publishesStages {
            await progress.publish(
                HomeIngestionPublication(
                    runID: progress.runID,
                    stage: .core(.init(snapshot: snapshot))
                )
            )
        }

        completedHotAlerts += 1
        await progress.markHotAlertsCompleted()

        if plans.count == 1, let afterHotAlertsGate {
            await afterHotAlertsGate.wait()
        }

        if publishesStages {
            await progress.publish(
                HomeIngestionPublication(
                    runID: progress.runID,
                    stage: .enrichment(.init(snapshot: snapshot))
                )
            )
        }

        return snapshot
    }

    func startedPlanCount() -> Int {
        plans.count
    }

    func executedPlans() -> [HomeIngestionPlan] {
        plans
    }

    func completedHotAlertsCount() -> Int {
        completedHotAlerts
    }
}

private actor CoordinatorPublicationRecorder {
    private var publications: [HomeIngestionPublication] = []

    func append(_ publication: HomeIngestionPublication) {
        publications.append(publication)
    }

    func values() -> [HomeIngestionPublication] {
        publications
    }
}

private actor AsyncCount {
    private var count = 0
    private var continuations: [Int: [CheckedContinuation<Void, Never>]] = [:]

    func record() {
        count += 1
        let satisfiedCounts = continuations.keys.filter { $0 <= count }
        for expectedCount in satisfiedCounts {
            let pending = continuations.removeValue(forKey: expectedCount) ?? []
            pending.forEach { $0.resume() }
        }
    }

    func waitForCount(_ expectedCount: Int) async {
        guard count < expectedCount else { return }
        await withCheckedContinuation { continuation in
            continuations[expectedCount, default: []].append(continuation)
        }
    }
}

private actor ControlledHomeIngestionExecutor: HomeIngestionExecuting {
    private let snapshot: HomeSnapshot
    private var progresses: [HomeIngestionRunProgress] = []
    private var releaseContinuations: [Int: CheckedContinuation<Void, Never>] = [:]
    private let startedRuns = AsyncCount()
    private let completedRuns = AsyncCount()
    private var canceledRunNumbers: Set<Int> = []

    init(snapshot: HomeSnapshot = .empty) {
        self.snapshot = snapshot
    }

    func run(plan: HomeIngestionPlan, progress: HomeIngestionRunProgress) async throws -> HomeSnapshot {
        _ = plan
        progresses.append(progress)
        let run = progresses.count
        await startedRuns.record()

        await withCheckedContinuation { continuation in
            releaseContinuations[run] = continuation
        }

        if Task.isCancelled {
            canceledRunNumbers.insert(run)
        }
        await completedRuns.record()
        return snapshot
    }

    func waitForStartedRun(_ run: Int) async {
        await startedRuns.waitForCount(run)
    }

    func waitForCompletedRun(_ run: Int) async {
        await completedRuns.waitForCount(run)
    }

    func releaseRun(_ run: Int) {
        guard let continuation = releaseContinuations.removeValue(forKey: run) else {
            fatalError("Run \(run) was not waiting for release")
        }
        continuation.resume()
    }

    func emitProgress(_ event: HomeIngestionProgressEvent, forRun run: Int) async {
        await progress(for: run).report(event)
    }

    func emitCorePublication(forRun run: Int) async {
        let progress = progress(for: run)
        await progress.publish(
            HomeIngestionPublication(
                runID: progress.runID,
                stage: .core(.init(snapshot: snapshot))
            )
        )
    }

    func wasCanceled(run: Int) -> Bool {
        canceledRunNumbers.contains(run)
    }

    private func progress(for run: Int) -> HomeIngestionRunProgress {
        guard progresses.indices.contains(run - 1) else {
            fatalError("Run \(run) has not started")
        }
        return progresses[run - 1]
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

private func waitUntil(
    // Full-target CI runs can heavily contend actor scheduling for these queueing tests.
    timeout: Duration = .seconds(2),
    condition: @escaping () async -> Bool
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
