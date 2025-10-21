//
//  Scheduler.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/28/25.
//

import Foundation
import OSLog
import BackgroundTasks

struct Scheduler {
    private let logger = Logger.scheduler
    private let appRefreshID: String
    
    init(refreshId: String) {
        appRefreshID = refreshId
    }
    
    // MARK: - Schedule Next App Refresh
    func scheduleNextAppRefresh(nextRun: Date) {
        logger.debug("Checking for any pending app refreshes")
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            // If we don't have any pending SkyAware tasks, we can schedule a new one
            let hasPending = requests.contains { $0.identifier == appRefreshID }
            guard !hasPending else {
                logger.info("Refresh task already pending: \(requests.count), skipping")
                return
            }
            
            // Create the task and set its next runtime
            let request = BGAppRefreshTaskRequest(identifier: appRefreshID)
            request.earliestBeginDate = nextRun
            
            do {
                try BGTaskScheduler.shared.submit(request)
                logger.info("Refresh task scheduled for: \(nextRun)")
            }
            catch { logger.error("Error scheduling background task (\(appRefreshID)): \(error.localizedDescription)")}
        }
    }
}

extension Scheduler {
    func ensureScheduled(using policy: RefreshPolicy, now: Date = .now) async {
        let hasPending = await hasPendingRequest(for: appRefreshID)
        guard !hasPending else { return }
        let next = policy.getNextRunTime(for: .short(20))
        scheduleNextAppRefresh(nextRun: next)
    }
    
    private func hasPendingRequest(for id: String) async -> Bool {
        await withCheckedContinuation { cont in
            BGTaskScheduler.shared.getPendingTaskRequests { requests in
                cont.resume(returning: requests.contains { $0.identifier == id })
            }
        }
    }
}
