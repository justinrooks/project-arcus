//
//  BackgroundRefreshLifecycle.swift
//  SkyAware
//

import Foundation
import OSLog

struct BackgroundRefreshLifecycle: Sendable {
    private let scheduleFallback: @Sendable () async -> BackgroundScheduler.SchedulingOutcome
    private let runOrchestration: @Sendable () async -> Outcome
    private let scheduleAuthoritative: @Sendable (Date) async -> BackgroundScheduler.SchedulingOutcome
    private let logger: Logger

    init(
        scheduleFallback: @escaping @Sendable () async -> BackgroundScheduler.SchedulingOutcome,
        runOrchestration: @escaping @Sendable () async -> Outcome,
        scheduleAuthoritative: @escaping @Sendable (Date) async -> BackgroundScheduler.SchedulingOutcome,
        logger: Logger = .appMain
    ) {
        self.scheduleFallback = scheduleFallback
        self.runOrchestration = runOrchestration
        self.scheduleAuthoritative = scheduleAuthoritative
        self.logger = logger
    }

    func run() async -> Outcome {
        let fallbackOutcome = await scheduleFallback()
        log(fallbackOutcome, action: "Fallback app refresh scheduling")

        let result = await runOrchestration()
        logger.notice("Background app refresh completed with result: \(String(describing: result), privacy: .public)")

        let authoritativeOutcome = await scheduleAuthoritative(result.next)
        log(authoritativeOutcome, action: "Evaluated app refresh scheduling")
        return result
    }

    private func log(_ outcome: BackgroundScheduler.SchedulingOutcome, action: String) {
        if outcome.preservesSuccessor {
            logger.notice("\(action, privacy: .public) preserved a successor: \(String(describing: outcome), privacy: .public)")
        } else {
            logger.error("\(action, privacy: .public) failed: \(String(describing: outcome), privacy: .public)")
        }
    }
}
