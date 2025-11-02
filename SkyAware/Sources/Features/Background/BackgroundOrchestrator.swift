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
    private let signposter:OSSignposter
    private let spcProvider: any SpcSyncing & SpcRiskQuerying
    private let locationProvider: LocationProvider
    private let refreshPolicy: RefreshPolicy
    private let morningEngine: MorningEngine
    private let healthStore: BgHealthStore
    private let cadence: CadencePolicy
    
    private let clock = ContinuousClock()
    
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
        signposter = OSSignposter(logger: logger)
        logger.info("BackgroundOrchestrator initialized")
    }
    
    // MARK: Run Background Job
    func run() async -> Outcome {
        logger.info("Background run started")
        // Mark the entire background job
        let runInterval = signposter.beginInterval("Background Run")
        let startInstant = clock.now
        let start = Date()
        
        return await withTaskCancellationHandler {
            var reasonNoNotify: String?
            
            do {
                try Task.checkCancellation()
                
                // MARK: Get fresh data
                logger.info("Starting SPC sync")
                let syncInterval = signposter.beginInterval("SPC Sync")
                await spcProvider.sync()
                signposter.endInterval("SPC Sync", syncInterval)
                logger.info("SPC sync completed")
                
                // - Get the latest convective outlook details
                logger.debug("Fetching latest convective outlook")
                let outlook = try await spcProvider.getLatestConvectiveOutlook()
                logger.debug("Latest convective outlook fetched")

                try Task.checkCancellation()
                
                // MARK: Get location snapshot
                logger.debug("Attempting to obtain latest location snapshot")
                guard let snap = await locationProvider.snapshot() else {
                    logger.info("No location snapshot available; rechecking in 20m")
                    let nextRun = refreshPolicy.getNextRunTime(for: .short(20))
                    let end = Date()
                    let active = clock.now - startInstant
                    
                    try? await recordBgRun(start: start, end: end, result: .success, didNotify: false, notificationReason: "No location snapshot available. Rechecking in 20m", nextRun: nextRun, cadence: 0, cadenceReason: "Early exit", active: active)

                    return .init(next: nextRun, result: .skipped, didNotify: false, feedsChanged: [])
                }
                
                logger.debug("Location snapshot obtained; preparing risk queries and placemark update")
                let updatedSnap = await locationProvider.ensurePlacemark(for: snap.coordinates)
                
                // MARK: Get Risk Status
                let (severeRisk, stormRisk) = try await withTimeout(seconds: 8, clock: clock) {
                    async let sr = self.spcProvider.getSevereRisk(for: snap.coordinates)
                    async let cr = self.spcProvider.getStormRisk(for: snap.coordinates)
                    return try await (sr, cr)
                }
                
                // MARK: Send the AM Notification
                signposter.emitEvent("Morning Summary Notification")
                let didAmNotify = await morningEngine.run(
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
                if !didAmNotify { reasonNoNotify = "Morning summary skipped" }

                // MARK: Cadence decision
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
                let active = clock.now - startInstant

                try? await recordBgRun(
                    start: start,
                    end: end,
                    result: .success,
                    didNotify: reasonNoNotify == nil ? true : false,
                    notificationReason: reasonNoNotify,
                    nextRun: nextRun,
                    cadence: cadenceResult.cadence.getMinutes(),
                    cadenceReason: cadenceResult.reason,
                    active: active
                )
                
                signposter.endInterval("Background Run", runInterval)
                logger.info("Background run finished with result: success")
                return .init(next: nextRun, result: .success, didNotify: true, feedsChanged: [])
            } catch {
                signposter.endInterval("Background Run", runInterval)
                let nextRun = refreshPolicy.getNextRunTime(for: .short(20))
                let end = Date()
                let active = clock.now - startInstant
                
                if error is CancellationError {
                    logger.warning("Background refresh was cancelled: \(error.localizedDescription, privacy: .public)")
                    try? await recordBgRun(start: start, end: end, result: .cancelled, didNotify: false, notificationReason: "Cancelled by iOS", nextRun: nextRun, cadence: 0, cadenceReason: "Background refresh cancelled", active: active)
                    return .init(next: nextRun, result: .cancelled, didNotify: false, feedsChanged: [])
                } else {
                    logger.error("Error refreshing background data: \(error.localizedDescription, privacy: .public)")
                    
                    try? await recordBgRun(start: start, end: end, result: .failed, didNotify: false, notificationReason: "Error refreshing background data", nextRun: nextRun, cadence: 0, cadenceReason: "Background refresh failed", active: active)
                        
                    return .init(next: nextRun, result: .failed, didNotify: false, feedsChanged: [])
                }
            }
        } onCancel: {
            logger.notice("Background run cancelled")
        }
    }
    
    // MARK: Convenience bg run record
    private func recordBgRun(
        start: Date,
        end: Date,
        result: Outcome.BackgroundResult,
        didNotify: Bool,
        notificationReason: String?,
        nextRun: Date,
        cadence: Int,
        cadenceReason: String?,
        active: Duration
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
                cadenceReason: cadenceReason,
                active: active
            )
    }
}
