//
//  BackgroundScheduler.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/28/25.
//

import Foundation
import OSLog
import BackgroundTasks

protocol BackgroundSchedulingBackend: Sendable {
    func pendingRequest(for id: String) async -> BackgroundScheduler.PendingRequest
    func cancel(taskRequestWithIdentifier id: String) async
    func submit(identifier: String, earliestBeginDate: Date) async throws
}

private struct SystemBackgroundSchedulingBackend: BackgroundSchedulingBackend {
    func pendingRequest(for id: String) async -> BackgroundScheduler.PendingRequest {
        await withCheckedContinuation { continuation in
            BGTaskScheduler.shared.getPendingTaskRequests { requests in
                let matching = requests.filter { $0.identifier == id }
                guard matching.isEmpty == false else {
                    continuation.resume(returning: .none)
                    return
                }

                if matching.contains(where: { $0.earliestBeginDate == nil }) {
                    continuation.resume(returning: .immediate)
                    return
                }

                if let earliest = matching.compactMap(\.earliestBeginDate).min() {
                    continuation.resume(returning: .at(earliest))
                } else {
                    continuation.resume(returning: .none)
                }
            }
        }
    }

    func cancel(taskRequestWithIdentifier id: String) async {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: id)
    }

    func submit(identifier: String, earliestBeginDate: Date) async throws {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBeginDate
        try BGTaskScheduler.shared.submit(request)
    }
}

struct BackgroundScheduler {
    private let logger = Logger.backgroundScheduler
    private let appRefreshID: String
    private let replacementTolerance: TimeInterval = 120
    private let backend: any BackgroundSchedulingBackend
    
    init(
        refreshId: String,
        backend: any BackgroundSchedulingBackend = SystemBackgroundSchedulingBackend()
    ) {
        appRefreshID = refreshId
        self.backend = backend
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

    enum SchedulingOutcome: Sendable, Equatable {
        case submitted
        case preservedExisting
        case preservedImmediate
        case submissionFailed
        case restoredPrevious
        case restorationFailed

        var preservesSuccessor: Bool {
            switch self {
            case .submitted, .preservedExisting, .preservedImmediate, .restoredPrevious:
                return true
            case .submissionFailed, .restorationFailed:
                return false
            }
        }
    }

    // MARK: - Schedule Next App Refresh
    func scheduleEvaluatedNextAppRefresh(nextRun: Date) async -> SchedulingOutcome {
        await schedule(nextRun: nextRun, intent: .authoritative)
    }

    func ensureScheduled(using policy: RefreshPolicy, now: Date = .now) async -> SchedulingOutcome {
        let next = policy.getNextRunTime(for: .short, now: now)
        return await schedule(nextRun: next, intent: .ensure)
    }

    private func schedule(nextRun: Date, intent: SchedulingIntent) async -> SchedulingOutcome {
        logger.debug("Checking for any pending app refreshes")
        let pending = await backend.pendingRequest(for: appRefreshID)

        switch Self.decision(for: pending, requested: nextRun, intent: intent, minimumDifference: replacementTolerance) {
        case .submit:
            return await submitRequest(nextRun: nextRun)
        case .keepExisting:
            if case .at(let existing) = pending {
                logger.debug("Keeping existing refresh task at \(existing, privacy: .public); requested \(nextRun, privacy: .public)")
            }
            return .preservedExisting
        case .keepImmediate:
            logger.debug("Keeping existing immediate refresh task; requested \(nextRun, privacy: .public)")
            return .preservedImmediate
        case .replace(let existing):
            logger.notice("Replacing refresh task from \(existing, privacy: .public) to \(nextRun, privacy: .public)")
            await backend.cancel(taskRequestWithIdentifier: appRefreshID)
            return await submitRequest(nextRun: nextRun, restoreOnFailure: existing)
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
    
    private func submitRequest(
        nextRun: Date,
        restoreOnFailure previousRun: Date? = nil
    ) async -> SchedulingOutcome {
        do {
            try await backend.submit(identifier: appRefreshID, earliestBeginDate: nextRun)
            logger.notice("Refresh task scheduled for: \(nextRun, privacy: .public)")
            return .submitted
        }
        catch {
            logger.error("Error scheduling background task (\(appRefreshID, privacy: .public)): \(error.localizedDescription, privacy: .public)")
        }
        
        guard let previousRun else { return .submissionFailed }
        
        do {
            try await backend.submit(identifier: appRefreshID, earliestBeginDate: previousRun)
            logger.notice("Restored previous refresh task at \(previousRun, privacy: .public)")
            return .restoredPrevious
        } catch {
            logger.error("Failed to restore previous background task (\(appRefreshID, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return .restorationFailed
        }
    }
}
