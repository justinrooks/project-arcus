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
    private static let mapProducts: [GeoJSONProduct] = [.categorical, .hail, .wind, .tornado, .fireRH]

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

        logger.info("SPC map sync started")
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
            logger.info(
                "SPC map sync finished result=\(completedWithoutFailures ? "success" : "partial-failure", privacy: .public)"
            )
        }

        if Task.isCancelled { return }

        let stagedBatch = await stageMapProducts(now: Date())
        let allSucceeded = await persistStagedMapProducts(stagedBatch)

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
        logger.info("SPC convective outlook sync started")
        do {
            try await outlookRepo.refreshConvectiveOutlooks(using: client)
            
            // After refresh, fetch the latest and publish (keeps it simple and reactive)
            if let d = try? await latestIssue(for: .convective) {
                logger.info(
                    "SPC convective outlook sync finished result=success latestPersistedPublished=\(d, privacy: .public)"
                )
                publishConvectiveIssue(d)
            } else {
                logger.info("SPC convective outlook sync finished result=success latestPersistedPublished=none")
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
        if let inFlight = mesoSyncTask {
            logger.debug("SPC meso sync already in-flight; joining existing task")
            await inFlight.value
            return
        }

        logger.info("SPC meso sync started")
        let task = Task { [self] in
            await runMesoscaleDiscussionSync()
        }
        mesoSyncTask = task
        await task.value
    }

    private func runMesoscaleDiscussionSync() async {
        let runInterval = signposter.beginInterval("Spc Sync Mesos")
        defer {
            signposter.endInterval("Background Run", runInterval)
            mesoSyncTask = nil
        }

        do {
            try await mesoRepo.refreshMesoscaleDiscussions(using: client)
            logger.info("SPC meso sync finished result=success")
        } catch is CancellationError {
            logger.notice("Mesoscale discussion sync cancelled")
        } catch {
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

    private func stageMapProducts(now: Date) async -> StagedSpcMapProductBatch {
        let logger = self.logger
        let client = self.client

        let stagedProducts = await withTaskGroup(
            of: (GeoJSONProduct, StagedSpcMapProduct).self,
            returning: [GeoJSONProduct: StagedSpcMapProduct].self
        ) { group in
            var pending = Self.mapProducts[...]
            var active = 0
            var results: [GeoJSONProduct: StagedSpcMapProduct] = [:]

            func enqueueNext() {
                guard let product = pending.popFirst() else { return }
                active += 1
                group.addTask {
                    let staged = await Self.fetchStagedMapProduct(product: product, client: client, now: now)
                    return (product, staged)
                }
            }

            for _ in 0..<min(Self.mapSyncMaxConcurrentProducts, Self.mapProducts.count) {
                enqueueNext()
            }

            while active > 0 {
                guard let (product, staged) = await group.next() else { break }
                active -= 1
                results[product] = staged

                if Task.isCancelled {
                    group.cancelAll()
                    break
                }

                enqueueNext()
            }

            return results
        }

        let validation = validateStagedMapBatch(stagedProducts, now: now)
        switch validation {
        case .accepted:
            logger.debug("SPC map candidate batch accepted")
        case .rejected(let reason):
            logger.warning("SPC map candidate batch rejected reason=\(reason, privacy: .public)")
        }
        return StagedSpcMapProductBatch(products: stagedProducts, validation: validation)
    }

    private func persistStagedMapProducts(_ batch: StagedSpcMapProductBatch) async -> Bool {
        guard case .accepted = batch.validation else {
            return false
        }

        let stagedClient = StagedMapSyncClient(stagedProducts: batch.products)
        let stormRiskRepo = self.stormRiskRepo
        let severeRiskRepo = self.severeRiskRepo
        let fireRiskRepo = self.fireRiskRepo
        let logger = self.logger

        let products: [(name: String, operation: @Sendable () async throws -> Void)] = [
            ("categorical", { try await stormRiskRepo.refreshStormRisk(using: stagedClient) }),
            ("hail", { try await severeRiskRepo.refreshHailRisk(using: stagedClient) }),
            ("wind", { try await severeRiskRepo.refreshWindRisk(using: stagedClient) }),
            ("tornado", { try await severeRiskRepo.refreshTornadoRisk(using: stagedClient) }),
            ("fire", { try await fireRiskRepo.refreshFireRisk(using: stagedClient) })
        ]

        return await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
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
    }

    private static func fetchStagedMapProduct(
        product: GeoJSONProduct,
        client: any SpcClient,
        now: Date
    ) async -> StagedSpcMapProduct {
        do {
            let data = try await client.fetchGeoJsonData(for: product)
            guard let decoded: GeoJSONFeatureCollection = JsonParser.decode(from: data) else {
                return StagedSpcMapProduct(
                    product: product,
                    decoded: .empty,
                    featureCount: 0,
                    issued: nil,
                    valid: nil,
                    expires: nil,
                    data: nil,
                    status: .rejected(reason: "decode_failed")
                )
            }

            let metadata = decoded.features.first.map(\.properties)
            let issued = metadata?.ISSUE.asUTCDate()
            let valid = metadata?.VALID.asUTCDate()
            let expires = metadata?.EXPIRE.asUTCDate()
            let status = validateStagedProduct(
                product: product,
                featureCount: decoded.features.count,
                issued: issued,
                valid: valid,
                expires: expires,
                now: now
            )

            return StagedSpcMapProduct(
                product: product,
                decoded: decoded,
                featureCount: decoded.features.count,
                issued: issued,
                valid: valid,
                expires: expires,
                data: data,
                status: status
            )
        } catch {
            return StagedSpcMapProduct(
                product: product,
                decoded: .empty,
                featureCount: 0,
                issued: nil,
                valid: nil,
                expires: nil,
                data: nil,
                status: .rejected(reason: "fetch_failed")
            )
        }
    }

    private func validateStagedMapBatch(
        _ stagedProducts: [GeoJSONProduct: StagedSpcMapProduct],
        now: Date
    ) -> StagedSpcMapBatchValidation {
        guard let categorical = stagedProducts[.categorical] else {
            return .rejected(reason: "categorical_missing")
        }

        if categorical.featureCount == 0 {
            return .rejected(reason: "categorical_empty")
        }

        guard
            let issued = categorical.issued,
            let valid = categorical.valid,
            let expires = categorical.expires
        else {
            return .rejected(reason: "categorical_metadata_invalid")
        }

        if expires <= now {
            return .rejected(reason: "categorical_expired")
        }

        if valid > now {
            return .rejected(reason: "categorical_future_only")
        }

        guard case .accepted = categorical.status else {
            return .rejected(reason: "categorical_rejected")
        }

        return .accepted(anchorIssued: issued, anchorValid: valid, anchorExpires: expires)
    }

    private static func validateStagedProduct(
        product: GeoJSONProduct,
        featureCount: Int,
        issued: Date?,
        valid: Date?,
        expires: Date?,
        now: Date
    ) -> StagedSpcMapProductValidation {
        if featureCount == 0 {
            return product == .categorical ? .rejected(reason: "categorical_empty") : .accepted
        }

        guard
            let issued,
            let valid,
            let expires
        else {
            return .rejected(reason: "\(product.rawValue)_metadata_invalid")
        }

        guard issued <= expires, valid <= expires else {
            return .rejected(reason: "\(product.rawValue)_window_invalid")
        }

        if expires <= now {
            return .rejected(reason: "\(product.rawValue)_expired")
        }

        return .accepted
    }
}

private struct StagedSpcMapProductBatch: Sendable {
    let products: [GeoJSONProduct: StagedSpcMapProduct]
    let validation: StagedSpcMapBatchValidation
}

private struct StagedSpcMapProduct: Sendable {
    let product: GeoJSONProduct
    let decoded: GeoJSONFeatureCollection
    let featureCount: Int
    let issued: Date?
    let valid: Date?
    let expires: Date?
    let data: Data?
    let status: StagedSpcMapProductValidation
}

private enum StagedSpcMapProductValidation: Sendable {
    case accepted
    case rejected(reason: String)
}

private enum StagedSpcMapBatchValidation: Sendable {
    case accepted(anchorIssued: Date, anchorValid: Date, anchorExpires: Date)
    case rejected(reason: String)
}

private struct StagedMapSyncClient: SpcClient {
    let stagedProducts: [GeoJSONProduct: StagedSpcMapProduct]

    func fetchRssData(for product: RssProduct) async throws -> Data {
        throw SpcError.missingRssData
    }

    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data {
        guard let staged = stagedProducts[product], let data = staged.data else {
            throw SpcError.missingGeoJsonData
        }
        return data
    }
}
