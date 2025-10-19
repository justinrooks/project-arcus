//
//  BackgroundOrchestrator.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/16/25.
//

import Foundation
import OSLog

enum BackgroundResult { case success, cancelled, failed }

actor BackgroundOrchestrator {
    private let logger = Logger.orchestrator
    private let spcProvider: any SpcSyncing & SpcRiskQuerying
    private let locationProvider: LocationProvider
    
    init(spcProvider: any SpcSyncing & SpcRiskQuerying, locationProvider: LocationProvider) {
        self.spcProvider = spcProvider
        self.locationProvider = locationProvider
        logger.info("BackgroundOrchestrator initialized")
    }
    
    func run() async -> BackgroundResult{
        logger.info("Background run started")
        return await withTaskCancellationHandler {
            do {
                let mgr = NotificationManager()
                logger.info("Starting SPC sync")
                await spcProvider.sync()
                logger.info("SPC sync completed")
                logger.debug("Fetching latest convective outlook")
                let outlook = try await spcProvider.getLatestConvectiveOutlook()
                logger.debug("Latest convective outlook fetched")
                
                logger.debug("Attempting to obtain latest location snapshot")
                guard let snap = await locationProvider.snapshot() else {
                    let message = "New convective outlook available"
                    logger.notice("No location snapshot available; sending generic outlook notification")
                    await mgr.notify(for: outlook, with: message)
                    logger.info("Background notification posted (generic)")
                    logger.info("Background run finished with result: success (no location)")
                    return BackgroundResult.success
                }
                
                logger.debug("Location snapshot obtained; preparing risk queries and placemark update")
                async let updatedSnap = locationProvider.ensurePlacemark(for: snap.coordinates)
                async let severeRisk = spcProvider.getSevereRisk(for: snap.coordinates)
                async let stormRisk = spcProvider.getStormRisk(for: snap.coordinates)
                logger.debug("Composing notification message with placemark and risk summaries")
                let message = "Latest severe weather outlook for \(await updatedSnap.placemarkSummary, default: "Unknown"):\nStorm Activity: \(try await stormRisk.summary)\nSevere Activity: \(try await severeRisk.summary)"
                
                await mgr.notify(for: outlook, with: message)
                logger.info("Background notification posted (personalized)")
                logger.info("Background run finished with result: success")
                
                return .success
            } catch {
                logger.error("Error refreshing background data: \(error.localizedDescription, privacy: .public)")
                logger.info("Background run finished with result: failed")
                return .failed
            }
        } onCancel: {
            logger.notice("Background run cancelled")
        }
    }
}

