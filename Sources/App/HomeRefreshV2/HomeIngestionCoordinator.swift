//
//  HomeIngestionCoordinator.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import OSLog

protocol HomeIngestionCoordinating: Actor, Sendable {
    func enqueueAndWait(
        _ request: HomeIngestionRequest,
        progress: HomeIngestionProgressHandler?,
        publication: HomeIngestionPublicationHandler?
    ) async throws -> HomeSnapshot
}

extension HomeIngestionCoordinating {
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
            ),
            progress: nil,
            publication: nil
        )
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
}

actor HomeIngestionCoordinator: HomeIngestionCoordinating {
    private struct Waiter {
        let id: UUID
        let requestedPlan: HomeIngestionPlan
        let progress: HomeIngestionProgressHandler?
        let publication: HomeIngestionPublicationHandler?
        let continuation: CheckedContinuation<HomeSnapshot, Error>
        var earliestRunNumber = 0
    }

    private struct PendingRun {
        let plan: HomeIngestionPlan
        let executionContext: BackgroundRefreshExecutionContext?
    }

    private let executor: any HomeIngestionExecuting
    private let logger = Logger.appHomeRefresh

    private var activePlan: HomeIngestionPlan?
    private var activeTask: Task<HomeSnapshot, Error>?
    private var activeExecutionContext: BackgroundRefreshExecutionContext?
    private var activeRunNumber = 0
    private var activeRunStartedAt: Date?
    private var activeRunCanAbsorbRemoteHotAlert = false
    private var pendingRun: PendingRun?
    private var waiters: [UUID: Waiter] = [:]

    #if DEBUG
    // Debug-test observation only. Issue #332 needs a storage acknowledgement to order cancellation tests without
    // polling or changing waiter ownership; Release builds do not include this seam.
    private var waiterCountContinuations: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private var waiterAtMostCountContinuations: [Int: [CheckedContinuation<Void, Never>]] = [:]
    #endif

    init(executor: any HomeIngestionExecuting) {
        self.executor = executor
    }

    func enqueue(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) {
        let request = HomeIngestionRequest(
            trigger: trigger,
            locationContext: locationContext,
            remoteAlertContext: remoteAlertContext
        )
        submit(request.plan, waiter: nil)
    }

    func enqueue(_ request: HomeIngestionRequest) {
        submit(request.plan, waiter: nil)
    }

    func enqueueAndWait(
        _ request: HomeIngestionRequest,
        progress: HomeIngestionProgressHandler?,
        publication: HomeIngestionPublicationHandler?
    ) async throws -> HomeSnapshot {
        let requestedPlan = request.plan
        let waiterID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let waiter = Waiter(
                    id: waiterID,
                    requestedPlan: requestedPlan,
                    progress: progress,
                    publication: publication,
                    continuation: continuation
                )
                submit(requestedPlan, waiter: waiter)
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(withID: waiterID)
            }
        }
    }

    private func submit(_ requestedPlan: HomeIngestionPlan, waiter: Waiter?) {
        let executionContext = BackgroundRefreshExecutionContext.current
        if let activePlan,
           activePlan.satisfies(requestedPlan),
           activePlanCanSatisfy(requestedPlan),
           !(activeExecutionContext != nil && isForegroundOwner(requestedPlan)) {
            logger.debug(
                "Home ingestion request joined active run requested={\(requestedPlan.logDescription)} active={\(activePlan.logDescription)}"
            )
            store(waiter, earliestRunNumber: activeRunNumber)
            return
        }

        if activeTask != nil {
            if let pendingRun {
                let mergedPlan = pendingRun.plan.merged(with: requestedPlan)
                logger.debug(
                    "Home ingestion request merged into pending follow-up requested={\(requestedPlan.logDescription)} pending={\(pendingRun.plan.logDescription)} merged={\(mergedPlan.logDescription)}"
                )
                self.pendingRun = .init(
                    plan: mergedPlan,
                    executionContext: mergedExecutionContext(
                        pendingPlan: pendingRun.plan,
                        pending: pendingRun.executionContext,
                        submittedPlan: requestedPlan,
                        submitted: executionContext
                    )
                )
            } else {
                logger.debug(
                    "Home ingestion request queued as follow-up requested={\(requestedPlan.logDescription)}"
                )
                pendingRun = .init(plan: requestedPlan, executionContext: executionContext)
            }
            store(waiter, earliestRunNumber: activeRunNumber + 1)
            return
        }

        store(waiter, earliestRunNumber: activeRunNumber + 1)
        startRun(with: requestedPlan, executionContext: executionContext)
    }

    private func mergedExecutionContext(
        pendingPlan: HomeIngestionPlan,
        pending: BackgroundRefreshExecutionContext?,
        submittedPlan: HomeIngestionPlan,
        submitted: BackgroundRefreshExecutionContext?
    ) -> BackgroundRefreshExecutionContext? {
        guard !isForegroundOwner(pendingPlan), !isForegroundOwner(submittedPlan) else { return nil }
        return .merged(pending, submitted)
    }

    private func isForegroundOwner(_ plan: HomeIngestionPlan) -> Bool {
        !plan.provenance.contains(.background)
    }

    private func store(_ waiter: Waiter?, earliestRunNumber: Int) {
        guard var waiter else { return }
        waiter.earliestRunNumber = earliestRunNumber
        waiters[waiter.id] = waiter

        #if DEBUG
        notifyWaiterCountObservers()
        #endif
    }

    private func cancelWaiter(withID waiterID: UUID) {
        guard let waiter = waiters.removeValue(forKey: waiterID) else { return }
        waiter.continuation.resume(throwing: CancellationError())
        #if DEBUG
        notifyWaiterCountObservers()
        #endif
    }

    #if DEBUG
    func waitForTestWaiterCount(atLeast count: Int) async {
        guard waiters.count < count else { return }
        await withCheckedContinuation { continuation in
            waiterCountContinuations[count, default: []].append(continuation)
        }
    }

    func waitForTestWaiterCount(atMost count: Int) async {
        guard waiters.count > count else { return }
        await withCheckedContinuation { continuation in
            waiterAtMostCountContinuations[count, default: []].append(continuation)
        }
    }

    private func notifyWaiterCountObservers() {
        let satisfiedAtLeastCounts = waiterCountContinuations.keys.filter { $0 <= waiters.count }
        for count in satisfiedAtLeastCounts {
            let continuations = waiterCountContinuations.removeValue(forKey: count) ?? []
            continuations.forEach { $0.resume() }
        }

        let satisfiedAtMostCounts = waiterAtMostCountContinuations.keys.filter { waiters.count <= $0 }
        for count in satisfiedAtMostCounts {
            let continuations = waiterAtMostCountContinuations.removeValue(forKey: count) ?? []
            continuations.forEach { $0.resume() }
        }
    }

    func testPendingPlanForWaiterCharacterization() -> HomeIngestionPlan? {
        pendingRun?.plan
    }

    func testWaiterCountForWaiterCharacterization() -> Int {
        waiters.count
    }
    #endif

    private func startRun(
        with plan: HomeIngestionPlan,
        executionContext: BackgroundRefreshExecutionContext?
    ) {
        let runID = UUID()
        activeRunNumber += 1
        let runNumber = activeRunNumber
        activePlan = plan
        activeExecutionContext = executionContext
        activeRunStartedAt = Date()
        activeRunCanAbsorbRemoteHotAlert = plan.forcedLanes.contains(.hotAlerts)
        logger.info("Home ingestion run started plan={\(plan.logDescription)}")

        let task = Task {
            try await BackgroundRefreshExecutionContext.$current.withValue(executionContext) {
                try await executor.run(
                    plan: plan,
                    progress: HomeIngestionRunProgress(
                        runID: runID,
                        markHotAlertsCompleted: {
                            await self.markHotAlertsCompleted(for: plan)
                        },
                        report: { event in
                            await self.reportProgress(event, for: plan)
                        },
                        publish: { publication in
                            await self.publish(publication, for: plan, runID: runID)
                        }
                    )
                )
            }
        }
        activeTask = task

        Task {
            do {
                let snapshot = try await task.value
                finishRun(plan: plan, runNumber: runNumber, result: .success(snapshot))
            } catch {
                finishRun(plan: plan, runNumber: runNumber, result: .failure(error))
            }
        }
    }

    private func finishRun(plan: HomeIngestionPlan, runNumber: Int, result: Result<HomeSnapshot, Error>) {
        let durationMs = activeRunStartedAt.map { startedAt in
            Int(Date().timeIntervalSince(startedAt) * 1000)
        } ?? 0
        activePlan = nil
        activeTask = nil
        activeExecutionContext = nil
        activeRunStartedAt = nil
        activeRunCanAbsorbRemoteHotAlert = false

        let satisfiedWaiterIDs = waiters.compactMap { id, waiter in
            waiter.earliestRunNumber <= runNumber && plan.satisfies(waiter.requestedPlan) ? id : nil
        }

        for waiterID in satisfiedWaiterIDs {
            guard let waiter = waiters.removeValue(forKey: waiterID) else { continue }
            switch result {
            case .success(let snapshot):
                waiter.continuation.resume(returning: snapshot)
            case .failure(let error):
                waiter.continuation.resume(throwing: error)
            }
        }

        #if DEBUG
        notifyWaiterCountObservers()
        #endif

        switch result {
        case .success(let snapshot):
            logger.info(
                "Home ingestion run finished plan={\(plan.logDescription)} result=success durationMs=\(durationMs, privacy: .public) waitsSatisfied=\(satisfiedWaiterIDs.count, privacy: .public) alerts=\(snapshot.alerts.count, privacy: .public) mesos=\(snapshot.mesos.count, privacy: .public) outlooks=\(snapshot.outlooks.count, privacy: .public) weather=\((snapshot.weather != nil), privacy: .public) pendingFollowUp=\((self.pendingRun != nil), privacy: .public)"
            )
        case .failure(let error):
            logger.error(
                "Home ingestion run finished plan={\(plan.logDescription)} result=failure durationMs=\(durationMs, privacy: .public) waitsSatisfied=\(satisfiedWaiterIDs.count, privacy: .public) pendingFollowUp=\((self.pendingRun != nil), privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }

        guard let pendingRun else { return }

        self.pendingRun = nil
        logger.info("Starting queued follow-up home ingestion plan={\(pendingRun.plan.logDescription)}")
        startRun(with: pendingRun.plan, executionContext: pendingRun.executionContext)
    }

    private func activePlanCanSatisfy(_ requestedPlan: HomeIngestionPlan) -> Bool {
        guard requestedPlan.remoteAlertContext != nil else {
            return true
        }

        guard activePlan?.remoteAlertContext != nil else {
            return false
        }

        return activeRunCanAbsorbRemoteHotAlert
    }

    private func markHotAlertsCompleted(for plan: HomeIngestionPlan) {
        guard activePlan == plan else { return }
        activeRunCanAbsorbRemoteHotAlert = false
    }

    private func reportProgress(_ event: HomeIngestionProgressEvent, for plan: HomeIngestionPlan) async {
        if event == .completed(.lane(.hotAlerts)) {
            markHotAlertsCompleted(for: plan)
        }

        let handlers = waiters.values.compactMap { waiter in
            waiter.earliestRunNumber <= activeRunNumber && plan.satisfies(waiter.requestedPlan) ? waiter.progress : nil
        }
        for handler in handlers {
            await handler(event)
        }
    }

    private func publish(
        _ publication: HomeIngestionPublication,
        for plan: HomeIngestionPlan,
        runID: UUID
    ) async {
        guard publication.runID == runID, activePlan == plan else { return }
        let handlers = waiters.values.compactMap { waiter in
            waiter.earliestRunNumber <= activeRunNumber && plan.satisfies(waiter.requestedPlan) ? waiter.publication : nil
        }
        for handler in handlers {
            await handler(publication)
        }
    }
}

private extension HomeIngestionRequest {
    var plan: HomeIngestionPlan {
        HomeIngestionPlan(request: self)
    }
}
