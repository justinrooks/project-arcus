import Foundation
import Testing
@testable import SkyAware

@Suite("Home Ingestion Coordinator", .serialized)
struct HomeIngestionCoordinatorTests {
    @Test("child executor task inherits the scoped background budget")
    func childExecutorTaskInheritsScopedBackgroundBudget() async throws {
        let executor = BudgetCapturingHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let clock = ContinuousClock()
        let budget = BackgroundRefreshBudget.standard(start: clock.now)

        _ = try await BackgroundRefreshExecutionContext.$current.withValue(.init(budget: budget)) {
            try await coordinator.enqueueAndWait(.backgroundRefresh)
        }

        #expect(await executor.sawBudget())
    }

    @Test("queued background follow-up retains its submitted budget")
    func queuedBackgroundFollowUpRetainsSubmittedBudget() async {
        let gate = AsyncGate()
        let executor = QueuedBudgetCapturingHomeIngestionExecutor(gate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let clock = ContinuousClock()

        await coordinator.enqueue(.sessionTick)
        let firstStarted = await waitUntil { await executor.runCount() == 1 }
        #expect(firstStarted)

        let context = BackgroundRefreshExecutionContext(budget: .standard(start: clock.now))
        await BackgroundRefreshExecutionContext.$current.withValue(context) {
            await coordinator.enqueue(.backgroundRefresh)
        }
        await gate.open()

        let followUpStarted = await waitUntil { await executor.runCount() == 2 }
        #expect(followUpStarted)
        #expect(await executor.observedBudgetContexts() == [false, true])
    }

    @Test("queued scheduled budget survives merging unbudgeted background work in either order")
    func queuedScheduledBudgetSurvivesUnbudgetedBackgroundMerge() async {
        await assertQueuedScheduledBudgetSurvivesUnbudgetedBackgroundMerge(budgetedRequestFirst: true)
        await assertQueuedScheduledBudgetSurvivesUnbudgetedBackgroundMerge(budgetedRequestFirst: false)
    }

    @Test("foreground waiter restarts outside a deadline-exhausted background run")
    func foregroundWaiterRestartsOutsideDeadlineExhaustedBackgroundRun() async throws {
        let gate = AsyncGate()
        let executor = DeadlineExhaustingHomeIngestionExecutor(gate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let context = BackgroundRefreshExecutionContext(
            budget: .standard(start: ContinuousClock().now)
        )

        let backgroundWaiter = Task {
            try await BackgroundRefreshExecutionContext.$current.withValue(context) {
                try await coordinator.enqueueAndWait(.backgroundRefresh)
            }
        }
        #expect(await waitUntil { await executor.runCount() == 1 })

        let foregroundWaiter = Task {
            try await coordinator.enqueueAndWait(.sessionTick)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 2)

        await gate.open()

        await expectCancellation(backgroundWaiter)
        #expect(try await foregroundWaiter.value == .empty)
        #expect(await executor.observedBudgetContexts() == [true, false])
    }

    private func assertQueuedScheduledBudgetSurvivesUnbudgetedBackgroundMerge(
        budgetedRequestFirst: Bool
    ) async {
        let gate = AsyncGate()
        let executor = QueuedBudgetCapturingHomeIngestionExecutor(gate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let executionContext = BackgroundRefreshExecutionContext(
            budget: .standard(start: ContinuousClock().now)
        )
        let remoteContext = HomeRemoteAlertContext(
            alertID: "queued-budget-merge",
            revisionSent: Date(timeIntervalSince1970: 700)
        )

        await coordinator.enqueue(.sessionTick)
        #expect(await waitUntil { await executor.runCount() == 1 })

        if budgetedRequestFirst {
            await BackgroundRefreshExecutionContext.$current.withValue(executionContext) {
                await coordinator.enqueue(.backgroundRefresh)
            }
            await coordinator.enqueue(.remoteHotAlertReceived, remoteAlertContext: remoteContext)
        } else {
            await coordinator.enqueue(.remoteHotAlertReceived, remoteAlertContext: remoteContext)
            await BackgroundRefreshExecutionContext.$current.withValue(executionContext) {
                await coordinator.enqueue(.backgroundRefresh)
            }
        }

        await gate.open()
        #expect(await waitUntil { await executor.runCount() == 2 })
        #expect(await executor.observedBudgetContexts() == [false, true])
    }

    @Test("protocol conveniences forward complete requests and callbacks to the canonical operation")
    func protocolConveniences_forwardToCanonicalOperation() async throws {
        let recordingCoordinator = ForwardingHomeIngestionCoordinator()
        let coordinator: any HomeIngestionCoordinating = recordingCoordinator
        let locationContext = makeContext(latitude: 39.75, longitude: -104.44, timestamp: 100)
        let remoteAlertContext = HomeRemoteAlertContext(
            alertID: "alert-forwarding",
            revisionSent: Date(timeIntervalSince1970: 200)
        )

        _ = try await coordinator.enqueueAndWait(
            .remoteHotAlertReceived,
            locationContext: locationContext,
            remoteAlertContext: remoteAlertContext
        )

        let request = HomeIngestionRequest(trigger: .manualRefresh)
        _ = try await coordinator.enqueueAndWait(request)

        let callbackRecorder = ForwardingCallbackRecorder()
        _ = try await coordinator.enqueueAndWait(
            request,
            progress: { _ in await callbackRecorder.recordProgress() }
        )
        _ = try await coordinator.enqueueAndWait(
            request,
            progress: { _ in await callbackRecorder.recordProgress() },
            publication: { _ in await callbackRecorder.recordPublication() }
        )

        let submissions = await recordingCoordinator.submissions()
        #expect(submissions.count == 4)
        #expect(submissions[0].request == HomeIngestionRequest(
            trigger: .remoteHotAlertReceived,
            locationContext: locationContext,
            remoteAlertContext: remoteAlertContext
        ))
        #expect(submissions[0].hasProgress == false)
        #expect(submissions[0].hasPublication == false)
        #expect(submissions[1].request == request)
        #expect(submissions[1].hasProgress == false)
        #expect(submissions[1].hasPublication == false)
        #expect(submissions[2].request == request)
        #expect(submissions[2].hasProgress)
        #expect(submissions[2].hasPublication == false)
        #expect(submissions[3].request == request)
        #expect(submissions[3].hasProgress)
        #expect(submissions[3].hasPublication)
        #expect(await callbackRecorder.progressCount() == 2)
        #expect(await callbackRecorder.publicationCount() == 1)
    }

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

    @Test("pre-canceled callers are removed while coordinator work remains accepted")
    func preCanceledCaller_isRemovedWhileCoordinatorWorkRemainsAccepted() async {
        let submissionGate = AsyncGate()
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)

        let waiter = Task {
            await submissionGate.wait()
            return try await coordinator.enqueueAndWait(.sessionTick)
        }

        waiter.cancel()
        await submissionGate.open()
        await executor.waitForStartedRun(1)
        await expectCancellation(waiter)
        #expect(await coordinator.testWaiterCountForWaiterCharacterization() == 0)

        await executor.releaseRun(1)
        await executor.waitForCompletedRun(1)
    }

    @Test("a pre-canceled background waiter cancels its accepted run")
    func preCanceledBackgroundWaiter_cancelsAcceptedRun() async {
        let submissionGate = AsyncGate()
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)

        let waiter = Task {
            await submissionGate.wait()
            return try await coordinator.enqueueAndWait(.backgroundRefresh)
        }

        waiter.cancel()
        await submissionGate.open()
        await executor.waitForStartedRun(1)
        await expectCancellation(waiter)
        #expect(await coordinator.testWaiterCountForWaiterCharacterization() == 0)
        await executor.waitForCompletedRun(1)
        #expect(await executor.wasCanceled(run: 1))
    }

    @Test("canceling the only background waiter cancels its active executor")
    func canceledOnlyBackgroundWaiter_cancelsActiveExecutor() async {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)

        let backgroundWaiter = Task {
            try await coordinator.enqueueAndWait(.backgroundRefresh)
        }

        await coordinator.waitForTestWaiterCount(atLeast: 1)
        await executor.waitForStartedRun(1)

        backgroundWaiter.cancel()
        await expectCancellation(backgroundWaiter)
        #expect(await coordinator.testWaiterCountForWaiterCharacterization() == 0)
        await executor.waitForCompletedRun(1)
        #expect(await executor.wasCanceled(run: 1))
    }

    @Test("one active background waiter retains shared work after another cancels")
    func remainingBackgroundWaiter_retainsSharedRunAfterPeerCancellation() async throws {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)

        let firstWaiter = Task {
            try await coordinator.enqueueAndWait(.backgroundRefresh)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        await executor.waitForStartedRun(1)

        let secondWaiter = Task {
            try await coordinator.enqueueAndWait(.backgroundRefresh)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 2)

        firstWaiter.cancel()
        await expectCancellation(firstWaiter)
        #expect(await coordinator.testWaiterCountForWaiterCharacterization() == 1)

        await executor.releaseRun(1)
        await executor.waitForCompletedRun(1)
        #expect(await executor.wasCanceled(run: 1) == false)
        #expect(try await secondWaiter.value == .empty)
    }

    @Test("a foreground waiter retains a background-originated compatible run")
    func foregroundWaiter_retainsBackgroundOriginatedCompatibleRun() async throws {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)

        let backgroundWaiter = Task {
            try await coordinator.enqueueAndWait(.backgroundRefresh)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        await executor.waitForStartedRun(1)

        let foregroundWaiter = Task {
            try await coordinator.enqueueAndWait(.sessionTick)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 2)

        backgroundWaiter.cancel()
        await expectCancellation(backgroundWaiter)
        #expect(await coordinator.testWaiterCountForWaiterCharacterization() == 1)

        await executor.releaseRun(1)
        await executor.waitForCompletedRun(1)
        #expect(await executor.wasCanceled(run: 1) == false)
        #expect(try await foregroundWaiter.value == .empty)
    }

    @Test("a remote-alert waiter retains a compatible background-originated run")
    func remoteAlertWaiter_retainsBackgroundOriginatedCompatibleRun() async throws {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let remoteAlertContext = HomeRemoteAlertContext(alertID: "retained-alert")

        let backgroundWaiter = Task {
            try await coordinator.enqueueAndWait(
                HomeIngestionRequest(trigger: .backgroundRefresh, remoteAlertContext: remoteAlertContext)
            )
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        await executor.waitForStartedRun(1)

        let remoteWaiter = Task {
            try await coordinator.enqueueAndWait(.remoteHotAlertReceived, remoteAlertContext: remoteAlertContext)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 2)

        backgroundWaiter.cancel()
        await expectCancellation(backgroundWaiter)
        await executor.releaseRun(1)
        await executor.waitForCompletedRun(1)
        #expect(await executor.wasCanceled(run: 1) == false)
        #expect(try await remoteWaiter.value == .empty)
    }

    @Test("a location waiter retains a compatible background-originated run")
    func locationWaiter_retainsBackgroundOriginatedCompatibleRun() async throws {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let context = makeContext(latitude: 39.75, longitude: -104.44, timestamp: 100)

        let locationWaiter = Task {
            try await coordinator.enqueueAndWait(.backgroundLocationChange, locationContext: context)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        await executor.waitForStartedRun(1)

        let backgroundWaiter = Task {
            try await coordinator.enqueueAndWait(.backgroundRefresh)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 2)

        backgroundWaiter.cancel()
        await expectCancellation(backgroundWaiter)
        await executor.releaseRun(1)
        await executor.waitForCompletedRun(1)
        #expect(await executor.wasCanceled(run: 1) == false)
        #expect(try await locationWaiter.value == .empty)
    }

    @Test("background fire-and-forget ownership retains shared work after waiter cancellation")
    func backgroundFireAndForget_retainsSharedWorkAfterWaiterCancellation() async {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)

        await coordinator.enqueue(.backgroundRefresh)
        await executor.waitForStartedRun(1)

        let foregroundWaiter = Task {
            try await coordinator.enqueueAndWait(.sessionTick)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)

        foregroundWaiter.cancel()
        await expectCancellation(foregroundWaiter)
        #expect(await coordinator.testWaiterCountForWaiterCharacterization() == 0)

        await executor.releaseRun(1)
        await executor.waitForCompletedRun(1)
        #expect(await executor.wasCanceled(run: 1) == false)
    }

    @Test("a canceled queued background waiter leaves its follow-up plan running")
    func canceledQueuedBackgroundWaiter_leavesFollowUpRunningWithoutCallbacks() async {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let progressCallbacks = AsyncCount()
        let publicationCallbacks = AsyncCount()

        await coordinator.enqueue(.sessionTick)
        await executor.waitForStartedRun(1)

        let backgroundWaiter = Task {
            try await coordinator.enqueueAndWait(
                HomeIngestionRequest(trigger: .backgroundRefresh),
                progress: { _ in await progressCallbacks.record() },
                publication: { _ in await publicationCallbacks.record() }
            )
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        #expect(await coordinator.testPendingPlanForWaiterCharacterization()?.provenance.contains(.background) == true)

        backgroundWaiter.cancel()
        await expectCancellation(backgroundWaiter)
        #expect(await coordinator.testWaiterCountForWaiterCharacterization() == 0)

        await executor.releaseRun(1)
        await executor.waitForStartedRun(2)
        await executor.emitProgress(.started(.lane(.hotAlerts)), forRun: 2)
        await executor.emitCorePublication(forRun: 2)
        #expect(await progressCallbacks.value() == 0)
        #expect(await publicationCallbacks.value() == 0)

        await executor.releaseRun(2)
        await executor.waitForCompletedRun(2)
        #expect(await executor.wasCanceled(run: 2) == false)
    }

    @Test("queued fire-and-forget ownership survives a canceled background waiter")
    func queuedFireAndForgetOwnership_retainsFollowUpAfterWaiterCancellation() async {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)

        await coordinator.enqueue(.sessionTick)
        await executor.waitForStartedRun(1)
        await coordinator.enqueue(.backgroundRefresh)

        let backgroundWaiter = Task {
            try await coordinator.enqueueAndWait(.backgroundRefresh)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        backgroundWaiter.cancel()
        await expectCancellation(backgroundWaiter)

        await executor.releaseRun(1)
        await executor.waitForStartedRun(2)
        await executor.releaseRun(2)
        await executor.waitForCompletedRun(2)
        #expect(await executor.wasCanceled(run: 2) == false)
    }

    @Test("canceling an active waiter suppresses later callbacks while work continues")
    func cancelBeforeFinish_activeWaiterThrowsAndSuppressesCallbacks() async {
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
        await expectCancellation(waiter)
        #expect(await coordinator.testWaiterCountForWaiterCharacterization() == 0)
        await executor.emitProgress(.completed(.lane(.hotAlerts)), forRun: 1)
        await executor.emitCorePublication(forRun: 1)
        #expect(await progressCallbacks.value() == 1)
        #expect(await publicationCallbacks.value() == 0)

        await executor.releaseRun(1)
        await executor.waitForCompletedRun(1)
    }

    @Test("a canceled pending waiter is removed while its queued follow-up remains")
    func canceledPendingWaiter_isRemovedWhileQueuedRunContinues() async throws {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let pendingProgressCallbacks = AsyncCount()
        let pendingPublicationCallbacks = AsyncCount()

        let activeWaiter = Task {
            try await coordinator.enqueueAndWait(.sessionTick)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        await executor.waitForStartedRun(1)

        let pendingWaiter = Task {
            try await coordinator.enqueueAndWait(
                HomeIngestionRequest(trigger: .manualRefresh),
                progress: { _ in await pendingProgressCallbacks.record() },
                publication: { _ in await pendingPublicationCallbacks.record() }
            )
        }
        await coordinator.waitForTestWaiterCount(atLeast: 2)
        #expect(await coordinator.testPendingPlanForWaiterCharacterization() != nil)
        pendingWaiter.cancel()
        await expectCancellation(pendingWaiter)
        #expect(await coordinator.testWaiterCountForWaiterCharacterization() == 1)

        await executor.releaseRun(1)
        await executor.waitForStartedRun(2)
        #expect(try await activeWaiter.value == .empty)

        await executor.emitProgress(.started(.lane(.hotAlerts)), forRun: 2)
        await executor.emitCorePublication(forRun: 2)
        #expect(await pendingProgressCallbacks.value() == 0)
        #expect(await pendingPublicationCallbacks.value() == 0)
        await executor.releaseRun(2)
        await executor.waitForCompletedRun(2)
    }

    @Test("one canceled compatible waiter does not affect an uncanceled waiter")
    func canceledCompatibleWaiter_doesNotPreventOtherWaiterCompletion() async throws {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let canceledProgressCallbacks = AsyncCount()
        let canceledPublicationCallbacks = AsyncCount()
        let retainedProgressCallbacks = AsyncCount()
        let retainedPublicationCallbacks = AsyncCount()

        let canceledWaiter = Task {
            try await coordinator.enqueueAndWait(
                HomeIngestionRequest(trigger: .sessionTick),
                progress: { _ in await canceledProgressCallbacks.record() },
                publication: { _ in await canceledPublicationCallbacks.record() }
            )
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        await executor.waitForStartedRun(1)

        let retainedWaiter = Task {
            try await coordinator.enqueueAndWait(
                HomeIngestionRequest(trigger: .sessionTick),
                progress: { _ in await retainedProgressCallbacks.record() },
                publication: { _ in await retainedPublicationCallbacks.record() }
            )
        }
        await coordinator.waitForTestWaiterCount(atLeast: 2)
        canceledWaiter.cancel()
        await expectCancellation(canceledWaiter)

        await executor.emitProgress(.started(.lane(.hotAlerts)), forRun: 1)
        await executor.emitCorePublication(forRun: 1)
        #expect(await canceledProgressCallbacks.value() == 0)
        #expect(await canceledPublicationCallbacks.value() == 0)
        #expect(await retainedProgressCallbacks.value() == 1)
        #expect(await retainedPublicationCallbacks.value() == 1)

        await executor.releaseRun(1)
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
        await expectCancellation(waiter)
        #expect(await coordinator.testWaiterCountForWaiterCharacterization() == 0)

        await executor.releaseRun(1)
        await executor.waitForCompletedRun(1)
        #expect(await executor.wasCanceled(run: 1) == false)
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
        await coordinator.waitForTestWaiterCount(atMost: 0)
        waiter.cancel()

        #expect(try await waiter.value == .empty)
    }

    @Test("repeated cancellation resumes a waiter once without canceling shared work")
    func repeatedCancellation_resumesWaiterOnceAndLeavesRunActive() async {
        let executor = ControlledHomeIngestionExecutor()
        let coordinator = HomeIngestionCoordinator(executor: executor)

        let waiter = Task {
            try await coordinator.enqueueAndWait(.sessionTick)
        }
        await coordinator.waitForTestWaiterCount(atLeast: 1)
        await executor.waitForStartedRun(1)

        waiter.cancel()
        waiter.cancel()
        await expectCancellation(waiter)
        #expect(await coordinator.testWaiterCountForWaiterCharacterization() == 0)

        await executor.releaseRun(1)
        await executor.waitForCompletedRun(1)
        #expect(await executor.wasCanceled(run: 1) == false)
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

private actor BudgetCapturingHomeIngestionExecutor: HomeIngestionExecuting {
    private var inheritedBudget = false

    func run(plan: HomeIngestionPlan, progress: HomeIngestionRunProgress) async throws -> HomeSnapshot {
        inheritedBudget = BackgroundRefreshExecutionContext.current != nil
        return HomeSnapshot()
    }

    func sawBudget() -> Bool {
        inheritedBudget
    }
}

private actor QueuedBudgetCapturingHomeIngestionExecutor: HomeIngestionExecuting {
    private let gate: AsyncGate
    private var contexts: [Bool] = []

    init(gate: AsyncGate) {
        self.gate = gate
    }

    func run(plan: HomeIngestionPlan, progress: HomeIngestionRunProgress) async throws -> HomeSnapshot {
        contexts.append(BackgroundRefreshExecutionContext.current != nil)
        if contexts.count == 1 {
            await gate.wait()
        }
        return HomeSnapshot()
    }

    func runCount() -> Int {
        contexts.count
    }

    func observedBudgetContexts() -> [Bool] {
        contexts
    }
}

private actor DeadlineExhaustingHomeIngestionExecutor: HomeIngestionExecuting {
    private let gate: AsyncGate
    private var contexts: [Bool] = []

    init(gate: AsyncGate) {
        self.gate = gate
    }

    func run(plan: HomeIngestionPlan, progress: HomeIngestionRunProgress) async throws -> HomeSnapshot {
        contexts.append(BackgroundRefreshExecutionContext.current != nil)
        if contexts.count == 1 {
            await gate.wait()
            guard let context = BackgroundRefreshExecutionContext.current else {
                Issue.record("Expected the first run to have a background execution context")
                return .empty
            }
            await context.deadlineState.markExceeded()
            try await context.deadlineState.throwIfExceeded()
        }
        return .empty
    }

    func runCount() -> Int {
        contexts.count
    }

    func observedBudgetContexts() -> [Bool] {
        contexts
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

private actor ForwardingHomeIngestionCoordinator: HomeIngestionCoordinating {
    struct Submission: Sendable {
        let request: HomeIngestionRequest
        let hasProgress: Bool
        let hasPublication: Bool
    }

    private var recordedSubmissions: [Submission] = []

    func enqueueAndWait(
        _ request: HomeIngestionRequest,
        progress: HomeIngestionProgressHandler?,
        publication: HomeIngestionPublicationHandler?
    ) async throws -> HomeSnapshot {
        recordedSubmissions.append(
            Submission(
                request: request,
                hasProgress: progress != nil,
                hasPublication: publication != nil
            )
        )
        await progress?(.started(.lane(.hotAlerts)))
        await publication?(
            HomeIngestionPublication(
                runID: UUID(),
                stage: .core(.init(snapshot: .empty))
            )
        )
        return .empty
    }

    func submissions() -> [Submission] {
        recordedSubmissions
    }
}

private actor ForwardingCallbackRecorder {
    private var progress = 0
    private var publication = 0

    func recordProgress() {
        progress += 1
    }

    func recordPublication() {
        publication += 1
    }

    func progressCount() -> Int {
        progress
    }

    func publicationCount() -> Int {
        publication
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

    func value() -> Int {
        count
    }
}

private func expectCancellation(_ task: Task<HomeSnapshot, Error>) async {
    do {
        _ = try await task.value
        Issue.record("Expected CancellationError")
    } catch is CancellationError {
    } catch {
        Issue.record("Expected CancellationError, received \(error)")
    }
}

private actor ControlledHomeIngestionExecutor: HomeIngestionExecuting {
    private let snapshot: HomeSnapshot
    private var progresses: [HomeIngestionRunProgress] = []
    private var releaseContinuations: [Int: CheckedContinuation<Void, Never>] = [:]
    private let startedRuns = AsyncCount()
    private let completedRuns = AsyncCount()
    private let canceledRuns = AsyncCount()
    private var canceledRunNumbers: Set<Int> = []

    init(snapshot: HomeSnapshot = .empty) {
        self.snapshot = snapshot
    }

    func run(plan: HomeIngestionPlan, progress: HomeIngestionRunProgress) async throws -> HomeSnapshot {
        _ = plan
        progresses.append(progress)
        let run = progresses.count
        await startedRuns.record()

        do {
            try await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    releaseContinuations[run] = continuation
                }
                if Task.isCancelled {
                    cancel(run)
                }
                try Task.checkCancellation()
            } onCancel: {
                Task {
                    await self.cancel(run)
                }
            }
        } catch {
            await completedRuns.record()
            throw error
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

    private func cancel(_ run: Int) {
        guard canceledRunNumbers.insert(run).inserted else { return }
        releaseContinuations.removeValue(forKey: run)?.resume()
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
