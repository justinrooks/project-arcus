//
//  BackgroundScheduler.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/28/25.
//

import Foundation
import OSLog
import BackgroundTasks

struct BackgroundScheduler {
    private let logger = Logger.backgroundScheduler
    private let appRefreshID: String
    private let replacementTolerance: TimeInterval = 120
    
    init(refreshId: String) {
        appRefreshID = refreshId
    }
    
    enum SchedulingIntent {
        case ensure
        case authoritative
    }

    enum PendingRequest: Sendable, Equatable {
        case none
        case immediate
        case at(Date)
    }

    enum SchedulingDecision: Sendable, Equatable {
        case submit
        case keepExisting
        case keepImmediate
        case replace(existing: Date)
    }

    // MARK: - Schedule Next App Refresh
    func scheduleEvaluatedNextAppRefresh(nextRun: Date) async {
        await schedule(nextRun: nextRun, intent: .authoritative)
    }

    func ensureScheduled(using policy: RefreshPolicy, now: Date = .now) async {
        let next = policy.getNextRunTime(for: .short, now: now)
        await schedule(nextRun: next, intent: .ensure)
    }

    private func schedule(nextRun: Date, intent: SchedulingIntent) async {
        logger.debug("Checking for any pending app refreshes")
        let pending = await pendingRequest(for: appRefreshID)

        switch Self.decision(for: pending, requested: nextRun, intent: intent, minimumDifference: replacementTolerance) {
        case .submit:
            submitRequest(nextRun: nextRun)
        case .keepExisting:
            if case .at(let existing) = pending {
                logger.debug("Keeping existing refresh task at \(existing, privacy: .public); requested \(nextRun, privacy: .public)")
            }
        case .keepImmediate:
            logger.debug("Keeping existing immediate refresh task; requested \(nextRun, privacy: .public)")
        case .replace(let existing):
            logger.notice("Replacing refresh task from \(existing, privacy: .public) to \(nextRun, privacy: .public)")
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: appRefreshID)
            submitRequest(nextRun: nextRun, restoreOnFailure: existing)
        }
    }

    static func decision(
        for pending: PendingRequest,
        requested: Date,
        intent: SchedulingIntent,
        minimumDifference: TimeInterval = 120
    ) -> SchedulingDecision {
        switch pending {
        case .none:
            return .submit
        case .immediate:
            return .keepImmediate
        case .at(let existing):
            guard intent == .authoritative else {
                return .keepExisting
            }

            guard shouldReplace(existing: existing, requested: requested, minimumAdvance: minimumDifference) else {
                return .keepExisting
            }

            return .replace(existing: existing)
        }
    }
    
    static func shouldReplace(
        existing: Date,
        requested: Date,
        minimumAdvance: TimeInterval = 120
    ) -> Bool {
        abs(existing.timeIntervalSince(requested)) > minimumAdvance
    }
    
    private func submitRequest(nextRun: Date, restoreOnFailure previousRun: Date? = nil) {
        let request = BGAppRefreshTaskRequest(identifier: appRefreshID)
        request.earliestBeginDate = nextRun
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.notice("Refresh task scheduled for: \(nextRun, privacy: .public)")
            return
        }
        catch {
            logger.error("Error scheduling background task (\(appRefreshID, privacy: .public)): \(error.localizedDescription, privacy: .public)")
        }
        
        guard let previousRun else { return }
        let fallback = BGAppRefreshTaskRequest(identifier: appRefreshID)
        fallback.earliestBeginDate = previousRun
        
        do {
            try BGTaskScheduler.shared.submit(fallback)
            logger.notice("Restored previous refresh task at \(previousRun, privacy: .public)")
        } catch {
            logger.error("Failed to restore previous background task (\(appRefreshID, privacy: .public)): \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func pendingRequest(for id: String) async -> PendingRequest {
        await withCheckedContinuation { cont in
            BGTaskScheduler.shared.getPendingTaskRequests { requests in
                let matching = requests.filter { $0.identifier == id }
                guard !matching.isEmpty else {
                    cont.resume(returning: .none)
                    return
                }
                
                if matching.contains(where: { $0.earliestBeginDate == nil }) {
                    cont.resume(returning: .immediate)
                    return
                }
                
                let earliest = matching.compactMap(\.earliestBeginDate).min()
                if let earliest {
                    cont.resume(returning: .at(earliest))
                } else {
                    cont.resume(returning: .none)
                }
            }
        }
    }
}
