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
    private let replacementLeadTime: TimeInterval = 120
    
    init(refreshId: String) {
        appRefreshID = refreshId
    }
    
    // MARK: - Schedule Next App Refresh
    func scheduleNextAppRefresh(nextRun: Date) async {
        logger.debug("Checking for any pending app refreshes")
        let pending = await pendingRequest(for: appRefreshID)
        
        switch pending {
        case .none:
            submitRequest(nextRun: nextRun)
        case .at(let existing):
            guard Self.shouldReplace(existing: existing, requested: nextRun, minimumAdvance: replacementLeadTime) else {
                logger.debug("Keeping existing refresh task at \(existing, privacy: .public); requested \(nextRun, privacy: .public)")
                return
            }
            
            logger.notice("Replacing refresh task from \(existing, privacy: .public) to \(nextRun, privacy: .public)")
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: appRefreshID)
            submitRequest(nextRun: nextRun, restoreOnFailure: existing)
        case .immediate:
            logger.debug("Keeping existing immediate refresh task; requested \(nextRun, privacy: .public)")
        }
    }
    
    static func shouldReplace(
        existing: Date,
        requested: Date,
        minimumAdvance: TimeInterval = 120
    ) -> Bool {
        requested.addingTimeInterval(minimumAdvance) < existing
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
    
    private enum PendingRequest {
        case none
        case immediate
        case at(Date)
    }
}

extension BackgroundScheduler {
    func ensureScheduled(using policy: RefreshPolicy, now: Date = .now) async {
        let next = policy.getNextRunTime(for: .short(20))
        await scheduleNextAppRefresh(nextRun: next)
    }
}
