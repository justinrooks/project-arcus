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
        
        await syncTextProducts()
        await syncMapProducts()
        
        signposter.endInterval("Background Run", runInterval)    }
    
    func syncMapProducts() async {
        let runInterval = signposter.beginInterval("Spc Sync Map Products")
        do {
            try await stormRiskRepo.refreshStormRisk(using: client)
            try await severeRiskRepo.refreshHailRisk(using: client)
            try await severeRiskRepo.refreshWindRisk(using: client)
            try await severeRiskRepo.refreshTornadoRisk(using: client)
            signposter.endInterval("Background Run", runInterval)
        } catch {
            signposter.endInterval("Background Run", runInterval)
            logger.error("Error loading Spc map feed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func syncTextProducts() async {
        let runInterval = signposter.beginInterval("Spc Sync Text")
        await syncConvectiveOutlooks()
        await syncMesoscaleDiscussions()
        signposter.endInterval("Background Run", runInterval)
    }

    func syncConvectiveOutlooks() async {
        let runInterval = signposter.beginInterval("Spc Sync Convective Outlooks")
        do {
            try await outlookRepo.refreshConvectiveOutlooks(using: client)
            
            // After refresh, fetch the latest and publish (keeps it simple and reactive)
            if let d = try? await latestIssue(for: .convective) {
                logger.info("Convective outlook published: \(d, privacy: .public)")
                publishConvectiveIssue(d)
            }
            signposter.endInterval("Background Run", runInterval)
        } catch {
            signposter.endInterval("Background Run", runInterval)
            logger.error("Error syncing convective outlook text products: \(error.localizedDescription, privacy: .public)")
        }
    }

    func syncMesoscaleDiscussions() async {
        let runInterval = signposter.beginInterval("Spc Sync Mesos")
        do {
            try await mesoRepo.refreshMesoscaleDiscussions(using: client)
            signposter.endInterval("Background Run", runInterval)
        } catch {
            signposter.endInterval("Background Run", runInterval)
            logger.error("Error syncing mesoscale discussion text products: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: Private methods
    private func publishConvectiveIssue(_ date: Date) {
        latestConvective = date
        for c in convectiveContinuations.values { c.yield(date) }
    }
}
