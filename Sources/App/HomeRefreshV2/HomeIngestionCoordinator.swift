//
//  HomeIngestionCoordinator.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

actor HomeIngestionCoordinator {
    private struct Waiter {
        let id: UUID
        let requestedPlan: HomeIngestionPlan
        let continuation: CheckedContinuation<HomeSnapshot, Error>
    }

    private let executor: any HomeIngestionExecuting

    private var activePlan: HomeIngestionPlan?
    private var activeTask: Task<HomeSnapshot, Error>?
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
        let requestedPlan = request.plan
        return try await withCheckedThrowingContinuation { continuation in
            let waiter = Waiter(
                id: UUID(),
                requestedPlan: requestedPlan,
                continuation: continuation
            )
            submit(requestedPlan, waiter: waiter)
        }
    }

    private func submit(_ requestedPlan: HomeIngestionPlan, waiter: Waiter?) {
        if let activePlan, activePlan.satisfies(requestedPlan) {
            store(waiter)
            return
        }

        if activeTask != nil {
            if let pendingPlan {
                self.pendingPlan = pendingPlan.merged(with: requestedPlan)
            } else {
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

        let task = Task {
            try await executor.run(plan: plan)
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
        activePlan = nil
        activeTask = nil

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

        guard let pendingPlan else { return }

        self.pendingPlan = nil
        startRun(with: pendingPlan)
    }
}

private extension HomeIngestionRequest {
    var plan: HomeIngestionPlan {
        HomeIngestionPlan(request: self)
    }
}
