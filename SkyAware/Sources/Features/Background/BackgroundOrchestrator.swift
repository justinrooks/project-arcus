//
//  BackgroundOrchestrator.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/16/25.
//

import Foundation
import OSLog

struct Outcome: Sendable {
    enum BackgroundResult: Sendable { case success, cancelled, failed, skipped }
    let next: Date
    let result: BackgroundResult
    let didNotify: Bool
    let feedsChanged: Set<Feed> // [.convective, .meso, .watch]
}

actor BackgroundOrchestrator {
    private let logger = Logger.orchestrator
    private let spcProvider: any SpcSyncing & SpcRiskQuerying
    private let locationProvider: LocationProvider
    private let refreshPolicy: RefreshPolicy
    private let morningEngine: MorningEngine
    private let healthStore: BgHealthStore
    private let cadence: CadencePolicy
    
    init(
        spcProvider: any SpcSyncing & SpcRiskQuerying,
        locationProvider: LocationProvider,
        policy: RefreshPolicy,
        engine: MorningEngine,
        health: BgHealthStore,
        cadence: CadencePolicy
    ) {
        self.spcProvider = spcProvider
        self.locationProvider = locationProvider
        morningEngine = engine
        refreshPolicy = policy
        healthStore = health
        self.cadence = cadence
        logger.info("BackgroundOrchestrator initialized")
    }
    
    func run() async -> Outcome {
        logger.info("Background run started")
        let start = Date()
        
        return await withTaskCancellationHandler {
            var reasonNoNotify: String?
            
            do {
                logger.info("Starting SPC sync")
                await spcProvider.sync()
                logger.info("SPC sync completed")
                logger.debug("Fetching latest convective outlook")
                let outlook = try await spcProvider.getLatestConvectiveOutlook()
                logger.debug("Latest convective outlook fetched")
                
                logger.debug("Attempting to obtain latest location snapshot")
                guard let snap = await locationProvider.snapshot() else {
                    logger.info("No location snapshot available; rechecking at 20 past")
                    let nextRun = refreshPolicy.getNextRunTime(for: .short(20))
                    
                    let end = Date()
                    try? await recordBgRun(start: start, end: end, result: .success, didNotify: false, notificationReason: "No location snapshot available. Rechecking in 20m", nextRun: nextRun, cadence: 0, cadenceReason: "Early exit")

                    return .init(next: nextRun, result: .skipped, didNotify: false, feedsChanged: [])
                }
                
                logger.debug("Location snapshot obtained; preparing risk queries and placemark update")
                // TODO: Check for wind, hail, and tornado features, if any then analyze, otherwise drop out
                let updatedSnap = await locationProvider.ensurePlacemark(for: snap.coordinates)
                let severeRisk = try await spcProvider.getSevereRisk(for: snap.coordinates)
                let stormRisk = try await spcProvider.getStormRisk(for: snap.coordinates)
                
                let morningSummary = await morningEngine.run(
                    ctx: .init(
                        now: .now,
                        lastConvectiveIssue: outlook?.published,
                        localTZ: TimeZone(identifier: "America/Denver")!,
                        quietHours: nil,
                        stormRisk: stormRisk,
                        severeRisk: severeRisk,
                        placeMark: updatedSnap.placemarkSummary ?? "Unknown"
                    )
                )
                if morningSummary {
                    logger.info("Morning summary notification posted")
                } else {
                    logger.info("Morning summary skipped")
                    reasonNoNotify = "Morning summary skipped"
                }
                
                // Build and send out cadence contxt object to the
                // decider. This will return our cadence based on
                // the internal logic there. It'll evaluate the
                // context and is the engine of handling the
                // determination of our next run.
                let cadenceResult = cadence.decide(
                    for: .init(
                        now: .now,
                        categorical: stormRisk,
                        recentlyChangedLocation: false,
                        inMeso: false,
                        inWatch: false
                    )
                )
                
                let nextRun = refreshPolicy.getNextRunTime(for: cadenceResult.cadence)
                let end = Date()
                let didNotify = reasonNoNotify == nil ? true : false
                try? await recordBgRun(start: start, end: end, result: .success, didNotify: didNotify, notificationReason: reasonNoNotify, nextRun: nextRun, cadence: getMinutes(from: cadenceResult.cadence), cadenceReason: cadenceResult.reason)
                
                logger.info("Background run finished with result: success")
                return .init(next: nextRun, result: .success, didNotify: true, feedsChanged: [])
            } catch {
                let nextRun = refreshPolicy.getNextRunTime(for: .short(20))
                let end = Date()
                
                if error is CancellationError {
                    logger.warning("Background refresh was cancelled: \(error.localizedDescription, privacy: .public)")
                    try? await recordBgRun(start: start, end: end, result: .cancelled, didNotify: false, notificationReason: "Cancelled by iOS", nextRun: nextRun, cadence: 0, cadenceReason: "Background refresh cancelled")
                    return .init(next: nextRun, result: .cancelled, didNotify: false, feedsChanged: [])
                } else {
                    logger.error("Error refreshing background data: \(error.localizedDescription, privacy: .public)")
                    
                    try? await recordBgRun(start: start, end: end, result: .failed, didNotify: false, notificationReason: "Error refreshing background data", nextRun: nextRun, cadence: 0, cadenceReason: "Background refresh failed")
                    
                    logger.info("Background run finished with result: failed")
                    return .init(next: nextRun, result: .failed, didNotify: false, feedsChanged: [])
                }
            }
        } onCancel: {
            let end = Date()
            Task {
                try? await recordBgRun(start: start, end: end, result: .cancelled, didNotify: false, notificationReason: "Task was cancelled by iOS", nextRun: end, cadence: 0, cadenceReason: "Task cancelled by iOS")
            }
            
            logger.notice("Background run cancelled")
        }
    }
    
    private func getMinutes(from cadence: Cadence) -> Int {
        switch cadence {
        case .short(let m):  m
        case .normal(let m): m
        case .long(let m):   m
        }
    }
    
    private func recordBgRun(
        start: Date,
        end: Date,
        result: Outcome.BackgroundResult,
        didNotify: Bool,
        notificationReason: String?,
        nextRun: Date,
        cadence: Int,
        cadenceReason: String?
    ) async throws {
        let duration = Int(end.timeIntervalSince(start))
        let outcome = result == .success ? 0 : 2
        
        try await healthStore
            .record(
                runId: UUID().uuidString,
                startedAt: start,
                endedAt: end,
                outcomeCode: outcome,
                didNotify: didNotify,
                reasonNoNotify: notificationReason,
                budgetSecUsed: duration,
                nextScheduledAt: nextRun,
                cadence: cadence,
                cadenceReason: cadenceReason
            )
    }
}
