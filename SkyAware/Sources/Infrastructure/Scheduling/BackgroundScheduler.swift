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
    
    init(refreshId: String) {
        appRefreshID = refreshId
    }
    
    // MARK: - Schedule Next App Refresh
    func scheduleNextAppRefresh(nextRun: Date) async {
        logger.debug("Checking for any pending app refreshes")
        // If we don't have any pending SkyAware tasks, we can schedule a new one
        let hasPending = await hasPendingRequest(for: appRefreshID)
        guard !hasPending else {
            logger.debug("Refresh task already pending")
            return
        }
        
        // Create the task and set its next runtime
        let request = BGAppRefreshTaskRequest(identifier: appRefreshID)
        request.earliestBeginDate = nextRun
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.notice("Refresh task scheduled for: \(nextRun)")
        }
        catch { logger.error("Error scheduling background task (\(appRefreshID)): \(error.localizedDescription)")}
    }
    
    private func hasPendingRequest(for id: String) async -> Bool {
        await withCheckedContinuation { cont in
            BGTaskScheduler.shared.getPendingTaskRequests { requests in
                cont.resume(returning: requests.contains { $0.identifier == id })
            }
        }
    }
}

extension BackgroundScheduler {
    func ensureScheduled(using policy: RefreshPolicy, now: Date = .now) async {
        let next = policy.getNextRunTime(for: .short(20))
        await scheduleNextAppRefresh(nextRun: next)
    }
}
