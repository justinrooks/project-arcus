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

        if Task.isCancelled {
            signposter.endInterval("Background Run", runInterval)
            return
        }
        await refreshMapProduct(named: "categorical") {
            try await stormRiskRepo.refreshStormRisk(using: client)
        }
        if Task.isCancelled {
            signposter.endInterval("Background Run", runInterval)
            return
        }
        await refreshMapProduct(named: "hail") {
            try await severeRiskRepo.refreshHailRisk(using: client)
        }
        if Task.isCancelled {
            signposter.endInterval("Background Run", runInterval)
            return
        }
        await refreshMapProduct(named: "wind") {
            try await severeRiskRepo.refreshWindRisk(using: client)
        }
        if Task.isCancelled {
            signposter.endInterval("Background Run", runInterval)
            return
        }
        await refreshMapProduct(named: "tornado") {
            try await severeRiskRepo.refreshTornadoRisk(using: client)
        }
        
        if Task.isCancelled {
            signposter.endInterval("Background Run", runInterval)
            return
        }
        await refreshMapProduct(named: "fire") {
            try await fireRiskRepo.refreshFireRisk(using: client)
        }

        signposter.endInterval("Background Run", runInterval)
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

    private func refreshMapProduct(named name: String, operation: () async throws -> Void) async {
        do {
            try await operation()
        } catch is CancellationError {
            logger.notice("SPC map product sync cancelled for \(name, privacy: .public)")
        } catch {
            logger.error("Error loading SPC map feed product=\(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
