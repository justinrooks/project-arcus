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
        _ = await syncMapProductsOutcome()
    }

    func syncMapProductsOutcome() async -> SpcMapSyncOutcome {
        if let inFlight = mapSyncTask {
            logger.debug("SPC map sync already in-flight; joining existing task")
            return await inFlight.value
        }

        if shouldSkipMapSync() {
            logger.debug("Skipping SPC map sync because a recent run already completed")
            return .skipped
        }

        logger.info("SPC map sync started")
        let task = Task { [self] in
            await runMapProductsSync()
        }
        mapSyncTask = task
        return await task.value
    }

    private func runMapProductsSync() async -> SpcMapSyncOutcome {
        let runInterval = signposter.beginInterval("Spc Sync Map Products")
        var completedWithoutFailures = true
        var mapSyncOutcome: SpcMapSyncOutcome = .failed
        defer {
            signposter.endInterval("Background Run", runInterval)
            mapSyncTask = nil
            if !Task.isCancelled && mapSyncOutcome == .accepted {
                lastMapSyncFinishedAt = Date()
            }
            logger.info(
                "SPC map sync finished result=\(completedWithoutFailures ? "success" : "partial-failure", privacy: .public)"
            )
        }

        if Task.isCancelled { return .failed }

        let stagedBatch = await stageMapProducts(now: Date())
        let allSucceeded = await persistStagedMapProducts(stagedBatch)

        completedWithoutFailures = allSucceeded && completedWithoutFailures
        if case .rejected = stagedBatch.validation {
            mapSyncOutcome = .rejected
        } else {
            mapSyncOutcome = allSucceeded ? .accepted : .failed
        }
        return mapSyncOutcome
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
                    let staged = await self.fetchStagedMapProduct(product: product, client: client, now: now)
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
        logStagedMapBatchProducts(stagedProducts)
        switch validation {
        case .accepted(let anchorIssued, let anchorValid, let anchorExpires):
            logger.info(
                "spc_map_batch_validation result=accepted reason=none productCount=\(stagedProducts.count, privacy: .public) anchorIssued=\(Self.isoTimestamp(anchorIssued), privacy: .public) anchorValid=\(Self.isoTimestamp(anchorValid), privacy: .public) anchorExpires=\(Self.isoTimestamp(anchorExpires), privacy: .public)"
            )
        case .rejected(let reason):
            logger.warning(
                "spc_map_batch_validation result=rejected reason=\(reason, privacy: .public) productCount=\(stagedProducts.count, privacy: .public)"
            )
        }
        return StagedSpcMapProductBatch(products: stagedProducts, validation: validation)
    }

    private func persistStagedMapProducts(_ batch: StagedSpcMapProductBatch) async -> Bool {
        guard case .accepted(let anchorIssued, let anchorValid, let anchorExpires) = batch.validation else {
            if case let .rejected(reason) = batch.validation {
                logger.info(
                    "spc_map_batch_persistence result=skipped reason=\(reason, privacy: .public) committed=false"
                )
            }
            // Rejected batches intentionally skip persistence but are not transport failures.
            return true
        }

        let stagedClient = StagedMapSyncClient(stagedProducts: batch.products)
        let succeeded = await Self.runMapProductSync(
            named: "accepted_batch_transaction",
            logger: logger,
            operation: { [spcMapBatchPersistenceRepo] in
                try await spcMapBatchPersistenceRepo.commitAcceptedMapBatch(
                    using: stagedClient,
                    anchorIssued: anchorIssued,
                    anchorValid: anchorValid,
                    anchorExpires: anchorExpires,
                    failureInjection: mapBatchPersistenceFailureInjection
                )
            }
        )
        logger.info(
            "spc_map_batch_persistence result=\(succeeded ? "committed" : "partial_failure", privacy: .public) committed=\(succeeded, privacy: .public) anchorIssued=\(Self.isoTimestamp(anchorIssued), privacy: .public) anchorValid=\(Self.isoTimestamp(anchorValid), privacy: .public) anchorExpires=\(Self.isoTimestamp(anchorExpires), privacy: .public)"
        )
        return succeeded
    }

    private func fetchStagedMapProduct(
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
                    status: .rejected(reason: "decode_failed"),
                    windowMetadata: nil
                )
            }

            let metadata: StagedProductWindowMetadata?
            do {
                metadata = try await preflightMetadata(for: product, decoded: decoded, now: now)
            } catch let preflightError as StagedProductPreflightError {
                return StagedSpcMapProduct(
                    product: product,
                    decoded: decoded,
                    featureCount: decoded.features.count,
                    issued: nil,
                    valid: nil,
                    expires: nil,
                    data: data,
                    status: .rejected(reason: preflightError.reason),
                    windowMetadata: nil
                )
            } catch {
                return StagedSpcMapProduct(
                    product: product,
                    decoded: decoded,
                    featureCount: decoded.features.count,
                    issued: nil,
                    valid: nil,
                    expires: nil,
                    data: data,
                    status: .rejected(reason: "\(product.rawValue)_preflight_failed"),
                    windowMetadata: nil
                )
            }
            let issued = metadata?.issued
            let valid = metadata?.valid
            let expires = metadata?.expires
            let status = Self.validateStagedProduct(
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
                status: status,
                windowMetadata: metadata
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
                status: .rejected(reason: "fetch_failed"),
                windowMetadata: nil
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

        guard let categoricalWindow = categorical.windowMetadata else {
            return .rejected(reason: "categorical_metadata_invalid")
        }
        let issued = categoricalWindow.issued
        let valid = categoricalWindow.valid
        let expires = categoricalWindow.expires

        if expires <= now {
            return .rejected(reason: "categorical_expired")
        }

        if valid > now {
            return .rejected(reason: "categorical_future_only")
        }

        guard case .accepted = categorical.status else {
            return .rejected(reason: "categorical_rejected")
        }

        let excludedProducts: Set<GeoJSONProduct> = [.categorical, .fireRH]

        for product in Self.mapProducts where !excludedProducts.contains(product) {
//        for product in Self.mapProducts where product != .categorical {
            guard let staged = stagedProducts[product] else {
                return .rejected(reason: "\(product.rawValue)_missing")
            }
            guard case .accepted = staged.status else {
                return .rejected(reason: "\(product.rawValue)_rejected")
            }
            guard staged.featureCount > 0 else { continue }
            guard let window = staged.windowMetadata else {
                return .rejected(reason: "\(product.rawValue)_metadata_invalid")
            }
            guard
                window.issued == issued,
                window.valid == valid,
                window.expires == expires
            else {
                return .rejected(reason: "\(product.rawValue)_mixed_window")
            }
        }
        // TODO: Figure out how/if we need to validate the fire content the same way...
//
//        guard let fireRH = stagedProducts[.fireRH] else {
//            return .rejected(reason: "fireRH_missing")
//        }
//
//        if fireRH.featureCount == 0 {
//            return .rejected(reason: "fireRH_empty")
//        }
//
//        guard let fireRhWindow = fireRH.windowMetadata else {
//            return .rejected(reason: "fireRH_metadata_invalid")
//        }
//        let fireIssued = fireRhWindow.issued
//        let fireValid = fireRhWindow.valid
//        let fireExpires = fireRhWindow.expires
//
//        if fireExpires <= now {
//            return .rejected(reason: "fireRH_expired")
//        }
//
//        if fireValid > now {
//            return .rejected(reason: "fireRH_future_only")
//        }
//
//        guard case .accepted = fireRH.status else {
//            return .rejected(reason: "fireRH_rejected")
//        }

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

        if valid > now {
            return .rejected(reason: "\(product.rawValue)_future_only")
        }

        return .accepted
    }

    private func preflightMetadata(
        for product: GeoJSONProduct,
        decoded: GeoJSONFeatureCollection,
        now: Date
    ) async throws -> StagedProductWindowMetadata? {
        guard decoded.features.isEmpty == false else {
            return nil
        }

        let featureWindows: [StagedProductWindowMetadata] = try decoded.features.map { feature in
            let properties = feature.properties
            guard
                let issued = properties.ISSUE.asUTCDate(),
                let valid = properties.VALID.asUTCDate(),
                let expires = properties.EXPIRE.asUTCDate()
            else {
                throw StagedProductPreflightError(reason: "\(product.rawValue)_metadata_invalid")
            }
            guard issued <= expires, valid <= expires else {
                throw StagedProductPreflightError(reason: "\(product.rawValue)_window_invalid")
            }
            if expires <= now {
                throw StagedProductPreflightError(reason: "\(product.rawValue)_expired")
            }
            if valid > now {
                throw StagedProductPreflightError(reason: "\(product.rawValue)_future_only")
            }
            return StagedProductWindowMetadata(issued: issued, valid: valid, expires: expires)
        }

        guard let anchor = featureWindows.first else {
            return nil
        }
        guard featureWindows.dropFirst().allSatisfy({ $0 == anchor }) else {
            throw StagedProductPreflightError(reason: "\(product.rawValue)_mixed_window")
        }

        try await preflightParseRows(for: product, decoded: decoded)
        return anchor
    }

    private func preflightParseRows(for product: GeoJSONProduct, decoded: GeoJSONFeatureCollection) async throws {
        let data = try JSONEncoder().encode(decoded)
        switch product {
        case .categorical:
            try await stormRiskRepo.validateCategoricalPayload(data)
        case .hail:
            try await severeRiskRepo.validateSeverePayload(data, threat: .hail)
        case .wind:
            try await severeRiskRepo.validateSeverePayload(data, threat: .wind)
        case .tornado:
            try await severeRiskRepo.validateSeverePayload(data, threat: .tornado)
        case .fireRH:
            try await fireRiskRepo.validateFirePayload(data)
        }
    }

    private func logStagedMapBatchProducts(_ stagedProducts: [GeoJSONProduct: StagedSpcMapProduct]) {
        for product in Self.mapProducts {
            guard let staged = stagedProducts[product] else {
                logger.warning("spc_map_product_stage product=\(product.rawValue, privacy: .public) result=missing")
                continue
            }
            switch staged.status {
            case .accepted:
                logger.info(
                    "spc_map_product_stage product=\(product.rawValue, privacy: .public) result=accepted reason=none featureCount=\(staged.featureCount, privacy: .public) issue=\(Self.isoTimestamp(staged.issued), privacy: .public) valid=\(Self.isoTimestamp(staged.valid), privacy: .public) expire=\(Self.isoTimestamp(staged.expires), privacy: .public)"
                )
            case .rejected(let reason):
                logger.warning(
                    "spc_map_product_stage product=\(product.rawValue, privacy: .public) result=rejected reason=\(reason, privacy: .public) featureCount=\(staged.featureCount, privacy: .public) issue=\(Self.isoTimestamp(staged.issued), privacy: .public) valid=\(Self.isoTimestamp(staged.valid), privacy: .public) expire=\(Self.isoTimestamp(staged.expires), privacy: .public)"
                )
            }
        }
    }

    private static func isoTimestamp(_ date: Date?) -> String {
        guard let date else { return "none" }
        return date.ISO8601Format()
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
    let windowMetadata: StagedProductWindowMetadata?
}

private enum StagedSpcMapProductValidation: Sendable {
    case accepted
    case rejected(reason: String)
}

private enum StagedSpcMapBatchValidation: Sendable {
    case accepted(anchorIssued: Date, anchorValid: Date, anchorExpires: Date)
    case rejected(reason: String)
}

private struct StagedProductWindowMetadata: Sendable, Equatable {
    let issued: Date
    let valid: Date
    let expires: Date
}

private struct StagedProductPreflightError: Error {
    let reason: String
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
