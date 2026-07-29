//
//  BackgroundRefreshLifecycle.swift
//  SkyAware
//

import Foundation
import OSLog

struct BackgroundRefreshRun: Sendable {
    let runId: String
    let startedAt: Date
    private let schedulingRecorder: @Sendable (BgSchedulingPhase, BgSchedulingOutcome) async -> Void

    init(
        runId: String,
        startedAt: Date,
        schedulingRecorder: @escaping @Sendable (BgSchedulingPhase, BgSchedulingOutcome) async -> Void
    ) {
        self.runId = runId
        self.startedAt = startedAt
        self.schedulingRecorder = schedulingRecorder
    }

    func recordScheduling(phase: BgSchedulingPhase, outcome: BgSchedulingOutcome) async {
        await schedulingRecorder(phase, outcome)
    }
}

struct BackgroundRefreshLifecycle: Sendable {
    private let beginRun: @Sendable () async -> BackgroundRefreshRun
    private let scheduleFallback: @Sendable () async -> BackgroundScheduler.SchedulingOutcome
    private let runOrchestration: @Sendable (BackgroundRefreshRun) async -> Outcome
    private let scheduleAuthoritative: @Sendable (Date) async -> BackgroundScheduler.SchedulingOutcome
    private let logger: Logger

    init(
        beginRun: @escaping @Sendable () async -> BackgroundRefreshRun,
        scheduleFallback: @escaping @Sendable () async -> BackgroundScheduler.SchedulingOutcome,
        runOrchestration: @escaping @Sendable (BackgroundRefreshRun) async -> Outcome,
        scheduleAuthoritative: @escaping @Sendable (Date) async -> BackgroundScheduler.SchedulingOutcome,
        logger: Logger = .appMain
    ) {
        self.beginRun = beginRun
        self.scheduleFallback = scheduleFallback
        self.runOrchestration = runOrchestration
        self.scheduleAuthoritative = scheduleAuthoritative
        self.logger = logger
    }

    func run() async -> Outcome {
        let run = await beginRun()
        let fallbackOutcome = await scheduleFallback()
        log(fallbackOutcome, action: "Fallback app refresh scheduling")
        await run.recordScheduling(
            phase: .fallback,
            outcome: diagnosticOutcome(for: fallbackOutcome)
        )

        let result = await runOrchestration(run)
        logger.notice("Background app refresh completed with result: \(String(describing: result), privacy: .public)")

        let authoritativeOutcome = await scheduleAuthoritative(result.next)
        log(authoritativeOutcome, action: "Evaluated app refresh scheduling")
        await run.recordScheduling(
            phase: .authoritative,
            outcome: diagnosticOutcome(for: authoritativeOutcome)
        )
        return result
    }

    private func diagnosticOutcome(
        for outcome: BackgroundScheduler.SchedulingOutcome
    ) -> BgSchedulingOutcome {
        switch outcome {
        case .submitted: .submitted
        case .preservedExisting: .preservedExisting
        case .preservedImmediate: .preservedImmediate
        case .submissionFailed: .submissionFailed
        case .restoredPrevious: .restoredPrevious
        case .restorationFailed: .restorationFailed
        }
    }

    private func log(_ outcome: BackgroundScheduler.SchedulingOutcome, action: String) {
        if outcome.preservesSuccessor {
            logger.notice("\(action, privacy: .public) preserved a successor: \(String(describing: outcome), privacy: .public)")
        } else {
            logger.error("\(action, privacy: .public) failed: \(String(describing: outcome), privacy: .public)")
        }
    }
}
