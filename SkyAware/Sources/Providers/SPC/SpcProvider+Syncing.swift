//
//  SpcProvider+Syncing.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/1/25.
//

import Foundation

// MARK: SpcSyncing
extension SpcProvider: SpcSyncing {
    func sync() async {
        let runInterval = signposter.beginInterval("Spc Sync")
        do {
            await syncTextProducts()
            
            try await stormRiskRepo.refreshStormRisk(using: client)
            try await severeRiskRepo.refreshHailRisk(using: client)
            try await severeRiskRepo.refreshWindRisk(using: client)
            try await severeRiskRepo.refreshTornadoRisk(using: client)
            signposter.endInterval("Background Run", runInterval)
        } catch {
            signposter.endInterval("Background Run", runInterval)
            logger.error("Error loading Spc feed: \(error.localizedDescription)")
        }
    }
    
    func syncTextProducts() async {
        let runInterval = signposter.beginInterval("Spc Sync Text")
        do {
            try await outlookRepo.refreshConvectiveOutlooks(using: client)
            
            // After refresh, fetch the latest and publish (keeps it simple and reactive)
            if let d = try? await latestIssue(for: .convective) {
                logger.info("Convective outlook published: \(d)")
                publishConvectiveIssue(d)
            }
            
            try await mesoRepo.refreshMesoscaleDiscussions(using: client)
            try await watchRepo.refreshWatches(using: client)
            signposter.endInterval("Background Run", runInterval)
        } catch {
            signposter.endInterval("Background Run", runInterval)
            logger.error("Error loading Spc feed: \(error.localizedDescription)")
        }
    }
    
    // MARK: Private methods
    private func publishConvectiveIssue(_ date: Date) {
        latestConvective = date
        for c in convectiveContinuations.values { c.yield(date) }
    }
}
