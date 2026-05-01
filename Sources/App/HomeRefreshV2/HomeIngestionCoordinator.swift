//
//  HomeIngestionCoordinator.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import OSLog

protocol HomeIngestionCoordinating: Actor, Sendable {
    func enqueue(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext?,
        remoteAlertContext: HomeRemoteAlertContext?
    )

    func enqueueAndWait(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext?,
        remoteAlertContext: HomeRemoteAlertContext?
    ) async throws -> HomeSnapshot

    func enqueue(_ request: HomeIngestionRequest)
    func enqueueAndWait(_ request: HomeIngestionRequest) async throws -> HomeSnapshot
    func enqueueAndWait(
        _ request: HomeIngestionRequest,
        progress: HomeIngestionProgressHandler?
    ) async throws -> HomeSnapshot
}

extension HomeIngestionCoordinating {
    func enqueueAndWait(
        _ request: HomeIngestionRequest,
        progress: HomeIngestionProgressHandler?
    ) async throws -> HomeSnapshot {
        try await enqueueAndWait(request)
    }
}

actor HomeIngestionCoordinator: HomeIngestionCoordinating {
    private struct Waiter {
        let id: UUID
        let requestedPlan: HomeIngestionPlan
        let progress: HomeIngestionProgressHandler?
        let continuation: CheckedContinuation<HomeSnapshot, Error>
    }

    private let executor: any HomeIngestionExecuting
    private let logger = Logger.appHomeRefresh

    private var activePlan: HomeIngestionPlan?
    private var activeTask: Task<HomeSnapshot, Error>?
    private var activeRunStartedAt: Date?
    private var activeRunCanAbsorbRemoteHotAlert = false
    private var pendingPlan: HomeIngestionPlan?
    private var waiters: [UUID: Waiter] = [:]

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
        submit(request.plan, waiter: nil)
    }

    func enqueueAndWait(_ request: HomeIngestionRequest) async throws -> HomeSnapshot {
        try await enqueueAndWait(request, progress: nil)
    }

    func enqueueAndWait(
        _ request: HomeIngestionRequest,
        progress: HomeIngestionProgressHandler?
    ) async throws -> HomeSnapshot {
        let requestedPlan = request.plan
        return try await withCheckedThrowingContinuation { continuation in
            let waiter = Waiter(
                id: UUID(),
                requestedPlan: requestedPlan,
                progress: progress,
                continuation: continuation
            )
            submit(requestedPlan, waiter: waiter)
        }
    }

    private func submit(_ requestedPlan: HomeIngestionPlan, waiter: Waiter?) {
        if let activePlan, activePlan.satisfies(requestedPlan), activePlanCanSatisfy(requestedPlan) {
            logger.debug(
                "Home ingestion request joined active run requested={\(requestedPlan.logDescription)} active={\(activePlan.logDescription)}"
            )
            store(waiter)
            return
        }

        if activeTask != nil {
            if let pendingPlan {
                let mergedPlan = pendingPlan.merged(with: requestedPlan)
                logger.debug(
                    "Home ingestion request merged into pending follow-up requested={\(requestedPlan.logDescription)} pending={\(pendingPlan.logDescription)} merged={\(mergedPlan.logDescription)}"
                )
                self.pendingPlan = mergedPlan
            } else {
                logger.debug(
                    "Home ingestion request queued as follow-up requested={\(requestedPlan.logDescription)}"
                )
                pendingPlan = requestedPlan
            }
            store(waiter)
            return
        }

        store(waiter)
        startRun(with: requestedPlan)
    }

    private func store(_ waiter: Waiter?) {
        guard let waiter else { return }
        waiters[waiter.id] = waiter
    }

    private func startRun(with plan: HomeIngestionPlan) {
        activePlan = plan
        activeRunStartedAt = Date()
        activeRunCanAbsorbRemoteHotAlert = plan.forcedLanes.contains(.hotAlerts)
        logger.info("Home ingestion run started plan={\(plan.logDescription)}")

        let task = Task {
            try await executor.run(
                plan: plan,
                progress: HomeIngestionRunProgress(
                    markHotAlertsCompleted: {
                        await self.markHotAlertsCompleted(for: plan)
                    },
                    report: { event in
                        await self.reportProgress(event, for: plan)
                    }
                )
            )
        }
        activeTask = task

        Task {
            do {
                let snapshot = try await task.value
                finishRun(plan: plan, result: .success(snapshot))
            } catch {
                finishRun(plan: plan, result: .failure(error))
            }
        }
    }

    private func finishRun(plan: HomeIngestionPlan, result: Result<HomeSnapshot, Error>) {
        let durationMs = activeRunStartedAt.map { startedAt in
            Int(Date().timeIntervalSince(startedAt) * 1000)
        } ?? 0
        activePlan = nil
        activeTask = nil
        activeRunStartedAt = nil
        activeRunCanAbsorbRemoteHotAlert = false

        let satisfiedWaiterIDs = waiters.compactMap { id, waiter in
            plan.satisfies(waiter.requestedPlan) ? id : nil
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

        switch result {
        case .success(let snapshot):
            logger.info(
                "Home ingestion run finished plan={\(plan.logDescription)} result=success durationMs=\(durationMs, privacy: .public) waitsSatisfied=\(satisfiedWaiterIDs.count, privacy: .public) watches=\(snapshot.watches.count, privacy: .public) mesos=\(snapshot.mesos.count, privacy: .public) outlooks=\(snapshot.outlooks.count, privacy: .public) weather=\((snapshot.weather != nil), privacy: .public) pendingFollowUp=\((self.pendingPlan != nil), privacy: .public)"
            )
        case .failure(let error):
            logger.error(
                "Home ingestion run finished plan={\(plan.logDescription)} result=failure durationMs=\(durationMs, privacy: .public) waitsSatisfied=\(satisfiedWaiterIDs.count, privacy: .public) pendingFollowUp=\((self.pendingPlan != nil), privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }

        guard let pendingPlan else { return }

        self.pendingPlan = nil
        logger.info("Starting queued follow-up home ingestion plan={\(pendingPlan.logDescription)}")
        startRun(with: pendingPlan)
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
            plan.satisfies(waiter.requestedPlan) ? waiter.progress : nil
        }
        for handler in handlers {
            await handler(event)
        }
    }
}

private extension HomeIngestionRequest {
    var plan: HomeIngestionPlan {
        HomeIngestionPlan(request: self)
    }
}
