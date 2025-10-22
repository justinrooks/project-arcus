//
//  BackgroundOrchestrator.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/16/25.
//

import Foundation
import OSLog

struct Outcome: Sendable {
//    enum Next: Sendable { case short(minutes: Int), normal(minutes: Int), long(minutes: Int) }
    enum BackgroundResult: Sendable { case success, cancelled, failed }
    let next: Date
//    let earliest: Date
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
    
    init(spcProvider: any SpcSyncing & SpcRiskQuerying, locationProvider: LocationProvider, policy: RefreshPolicy, engine: MorningEngine) {
        self.spcProvider = spcProvider
        self.locationProvider = locationProvider
        morningEngine = engine
        refreshPolicy = policy
        logger.info("BackgroundOrchestrator initialized")
    }
    
    func run() async -> Outcome {
        logger.info("Background run started")
        return await withTaskCancellationHandler {
            do {
                logger.info("Starting SPC sync")
                await spcProvider.sync()
                logger.info("SPC sync completed")
                logger.debug("Fetching latest convective outlook")
                let outlook = try await spcProvider.getLatestConvectiveOutlook()
                logger.debug("Latest convective outlook fetched")
                
                logger.debug("Attempting to obtain latest location snapshot")
                guard let snap = await locationProvider.snapshot() else {
//                    let message = "New convective outlook available"
//                    logger.notice("No location snapshot available; sending generic outlook notification")
//                    let mgr = NotificationManager()
//                    await mgr.notify(for: outlook, with: message)
//                    logger.info("Background notification posted (generic)")
//                    logger.info("Background run finished with result: success (no location)")
//                    
                    logger.info("No location snapshot available; rechecking at 20 past")
                    let nextRun = refreshPolicy.getNextRunTime(for: .short(20))
                    return .init(next: nextRun, result: .success, didNotify: true, feedsChanged: [])
                }
                
                logger.debug("Location snapshot obtained; preparing risk queries and placemark update")
                // TODO: Check for wind, hail, and tornado features, if any then analyze, otherwise drop out
                async let updatedSnap = locationProvider.ensurePlacemark(for: snap.coordinates)
                async let severeRisk = spcProvider.getSevereRisk(for: snap.coordinates)
                async let stormRisk = spcProvider.getStormRisk(for: snap.coordinates)
                
                let morningSummary = await morningEngine.run(
                    ctx: .init(
                        now: .now,
                        lastConvectiveIssue: outlook?.published,
                        localTZ: TimeZone(identifier: "America/Denver")!,
                        quietHours: nil,
                        stormRisk: try await stormRisk,
                        severeRisk: try await severeRisk,
                        placeMark: await updatedSnap.placemarkSummary ?? "Unknown"
                    )
                )
                if morningSummary {
                    logger.info("Morning summary notification posted")
                } else {
                    logger.info("Morning summary skipped")
                }
                
                logger.info("Background run finished with result: success")
                
                let nextRun = refreshPolicy.getNextRunTime(for: .normal(60))
                return .init(next: nextRun, result: .success, didNotify: true, feedsChanged: [])
            } catch {
                logger.error("Error refreshing background data: \(error.localizedDescription, privacy: .public)")
                logger.info("Background run finished with result: failed")
                
                let nextRun = refreshPolicy.getNextRunTime(for: .short(20))
                return .init(next: nextRun, result: .failed, didNotify: false, feedsChanged: [])
            }
        } onCancel: {
            logger.notice("Background run cancelled")
        }
    }
}
