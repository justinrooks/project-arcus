//
//  BackgroundRefreshBudget.swift
//  SkyAware
//

import Foundation

/// The soft application policy for one background refresh's work and finalization window.
///
/// These durations are not system execution guarantees. Callers use the work deadline to leave
/// time for persistence, cadence calculation, diagnostics, and completion before the task ends.
struct BackgroundRefreshBudget: Sendable {
    static let defaultTotalDuration: Duration = .seconds(30)
    static let defaultFinalizationReserve: Duration = .seconds(5)

    let start: ContinuousClock.Instant
    let completionDeadline: ContinuousClock.Instant
    let finalizationReserve: Duration
    let workDeadline: ContinuousClock.Instant

    init(
        start: ContinuousClock.Instant,
        completionDeadline: ContinuousClock.Instant,
        finalizationReserve: Duration
    ) {
        self.start = start
        self.completionDeadline = completionDeadline
        self.finalizationReserve = max(finalizationReserve, .zero)
        workDeadline = max(start, completionDeadline - self.finalizationReserve)
    }

    static func standard(start: ContinuousClock.Instant) -> Self {
        .init(
            start: start,
            completionDeadline: start + defaultTotalDuration,
            finalizationReserve: defaultFinalizationReserve
        )
    }

    func remainingWork(at instant: ContinuousClock.Instant) -> Duration {
        remaining(until: workDeadline, at: instant)
    }

    func remainingTotal(at instant: ContinuousClock.Instant) -> Duration {
        remaining(until: completionDeadline, at: instant)
    }

    func admission(
        for requestedDuration: Duration,
        at instant: ContinuousClock.Instant,
        isCancelled: Bool
    ) -> BackgroundRefreshBudgetAdmission {
        if isCancelled {
            return .cancelled
        }

        let remainingWork = remainingWork(at: instant)
        guard remainingWork > .zero else {
            return .workDeadlineReached
        }

        guard requestedDuration <= remainingWork else {
            return .insufficientTime
        }

        return .admitted
    }

    private func remaining(
        until deadline: ContinuousClock.Instant,
        at instant: ContinuousClock.Instant
    ) -> Duration {
        max(deadline - instant, .zero)
    }
}

enum BackgroundRefreshBudgetAdmission: Sendable, Equatable {
    case admitted
    case cancelled
    case workDeadlineReached
    case insufficientTime
}

struct BackgroundRefreshExecutionContext: Sendable {
    let budget: BackgroundRefreshBudget
    let deadlineState: BackgroundRefreshDeadlineState

    init(budget: BackgroundRefreshBudget, deadlineState: BackgroundRefreshDeadlineState = .init()) {
        self.budget = budget
        self.deadlineState = deadlineState
    }

    @TaskLocal static var current: BackgroundRefreshExecutionContext?

    static func merged(
        _ lhs: BackgroundRefreshExecutionContext?,
        _ rhs: BackgroundRefreshExecutionContext?
    ) -> BackgroundRefreshExecutionContext? {
        switch (lhs, rhs) {
        case (nil, nil): nil
        case let (context?, nil), let (nil, context?): context
        case let (lhs?, rhs?):
            lhs.budget.workDeadline <= rhs.budget.workDeadline ? lhs : rhs
        }
    }
}

actor BackgroundRefreshDeadlineState {
    private var isExceeded = false

    func markExceeded() {
        isExceeded = true
    }

    func exceeded() -> Bool {
        isExceeded
    }

    func throwIfExceeded() throws {
        guard isExceeded else { return }
        throw CancellationError()
    }
}
