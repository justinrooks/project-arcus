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
        if let inFlight = mapSyncTask {
            logger.debug("SPC map sync already in-flight; joining existing task")
            await inFlight.value
            return
        }

        if shouldSkipMapSync() {
            logger.debug("Skipping SPC map sync because a recent run already completed")
            return
        }

        let task = Task { [self] in
            await runMapProductsSync()
        }
        mapSyncTask = task
        await task.value
    }

    private func runMapProductsSync() async {
        let runInterval = signposter.beginInterval("Spc Sync Map Products")
        defer {
            signposter.endInterval("Background Run", runInterval)
            mapSyncTask = nil
            if !Task.isCancelled {
                lastMapSyncFinishedAt = Date()
            }
        }

        if Task.isCancelled {
            return
        }
        await refreshMapProduct(named: "categorical") {
            try await stormRiskRepo.refreshStormRisk(using: client)
        }
        if Task.isCancelled {
            return
        }
        await refreshMapProduct(named: "hail") {
            try await severeRiskRepo.refreshHailRisk(using: client)
        }
        if Task.isCancelled {
            return
        }
        await refreshMapProduct(named: "wind") {
            try await severeRiskRepo.refreshWindRisk(using: client)
        }
        if Task.isCancelled {
            return
        }
        await refreshMapProduct(named: "tornado") {
            try await severeRiskRepo.refreshTornadoRisk(using: client)
        }
        
        if Task.isCancelled {
            return
        }
        await refreshMapProduct(named: "fire") {
            try await fireRiskRepo.refreshFireRisk(using: client)
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
