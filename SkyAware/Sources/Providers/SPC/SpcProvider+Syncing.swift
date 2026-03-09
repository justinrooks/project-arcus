//
//  SpcProvider+Syncing.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/1/25.
//

import Foundation
import OSLog

// MARK: SpcSyncing
extension SpcProvider: SpcSyncing {
    private static let mapSyncMaxConcurrentProducts = 3

    func sync() async {
        let runInterval = signposter.beginInterval("Spc Sync")

        async let textSync: Void = syncTextProducts()
        async let mapSync: Void = syncMapProducts()
        _ = await (textSync, mapSync)

        signposter.endInterval("Background Run", runInterval)
    }
    
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
        var completedWithoutFailures = true
        defer {
            signposter.endInterval("Background Run", runInterval)
            mapSyncTask = nil
            if !Task.isCancelled && completedWithoutFailures {
                lastMapSyncFinishedAt = Date()
            }
        }

        if Task.isCancelled { return }

        let client = self.client
        let stormRiskRepo = self.stormRiskRepo
        let severeRiskRepo = self.severeRiskRepo
        let fireRiskRepo = self.fireRiskRepo
        let logger = self.logger

        let products: [(name: String, operation: @Sendable () async throws -> Void)] = [
            ("categorical", { try await stormRiskRepo.refreshStormRisk(using: client) }),
            ("hail", { try await severeRiskRepo.refreshHailRisk(using: client) }),
            ("wind", { try await severeRiskRepo.refreshWindRisk(using: client) }),
            ("tornado", { try await severeRiskRepo.refreshTornadoRisk(using: client) }),
            ("fire", { try await fireRiskRepo.refreshFireRisk(using: client) })
        ]

        let allSucceeded = await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            var pending = products[...]
            var active = 0
            var succeeded = true

            func enqueueNext() {
                guard let next = pending.popFirst() else { return }
                active += 1
                group.addTask {
                    await Self.runMapProductSync(named: next.name, logger: logger, operation: next.operation)
                }
            }

            for _ in 0..<min(Self.mapSyncMaxConcurrentProducts, products.count) {
                enqueueNext()
            }

            while active > 0 {
                guard let completed = await group.next() else { break }
                active -= 1
                succeeded = succeeded && completed

                if Task.isCancelled {
                    group.cancelAll()
                    return false
                }

                enqueueNext()
            }

            return succeeded
        }

        completedWithoutFailures = allSucceeded && completedWithoutFailures
    }
    
    func syncTextProducts() async {
        let runInterval = signposter.beginInterval("Spc Sync Text")
        async let convectiveSync: Void = syncConvectiveOutlooks()
        async let mesoSync: Void = syncMesoscaleDiscussions()
        _ = await (convectiveSync, mesoSync)
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
        } catch is CancellationError {
            signposter.endInterval("Background Run", runInterval)
            logger.notice("Convective outlook sync cancelled")
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
        } catch is CancellationError {
            signposter.endInterval("Background Run", runInterval)
            logger.notice("Mesoscale discussion sync cancelled")
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

    private static func runMapProductSync(
        named name: String,
        logger: Logger,
        operation: @Sendable () async throws -> Void
    ) async -> Bool {
        do {
            try await operation()
            return true
        } catch is CancellationError {
            logger.notice("SPC map product sync cancelled for \(name, privacy: .public)")
            return false
        } catch {
            logger.error("Error loading SPC map feed product=\(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
