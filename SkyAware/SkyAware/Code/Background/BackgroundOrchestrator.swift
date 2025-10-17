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
    }
    
    func run() async -> BackgroundResult{
        await withTaskCancellationHandler {
            do {
                let mgr = NotificationManager()
                await spcProvider.sync()
                let outlook = try await spcProvider.getLatestConvectiveOutlook()
                
                guard let snap = await locationProvider.snapshot() else {
                    let message = "New convective outlook available"
                    await mgr.notify(for: outlook, with: message)
                    
                    return .success
                }
                
                async let updatedSnap = locationProvider.ensurePlacemark(for: snap.coordinates)
                async let severeRisk = spcProvider.getSevereRisk(for: snap.coordinates)
                async let stormRisk = spcProvider.getStormRisk(for: snap.coordinates)
                let message = "Latest severe weather outlook for \(await updatedSnap.placemarkSummary, default: "Unknown"):\nStorm Activity: \(try await stormRisk.summary)\nSevere Activity: \(try await severeRisk.summary)"
                
                await mgr.notify(for: outlook, with: message)
                
                return .success
            } catch {
                logger.error("Error refreshing background data: \(error.localizedDescription)")
                return .failed
            }
        } onCancel: {
            logger.warning("Background data fetch task cancelled")
        }
    }
}
