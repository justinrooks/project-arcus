//
//  SpcProviderV1.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import OSLog
import SwiftData
import CoreLocation

actor SpcProvider {
    private let logger = Logger.spcProvider
    private let outlookRepo: ConvectiveOutlookRepo
    private let mesoRepo: MesoRepo
    private let watchRepo: WatchRepo
    private let stormRiskRepo: StormRiskRepo
    private let severeRiskRepo: SevereRiskRepo
    private let client: SpcClient
    
    // Convective freshness Stream
    private var latestConvective: Date?
    private var convectiveContinuations: [UUID: AsyncStream<Date>.Continuation] = [:]
    
    init(outlookRepo: ConvectiveOutlookRepo,
         mesoRepo: MesoRepo,
         watchRepo: WatchRepo,
         stormRiskRepo: StormRiskRepo,
         severeRiskRepo: SevereRiskRepo,
         client: SpcClient) {
        self.outlookRepo = outlookRepo
        self.mesoRepo = mesoRepo
        self.watchRepo = watchRepo
        self.stormRiskRepo = stormRiskRepo
        self.severeRiskRepo = severeRiskRepo
        self.client = client
    }
    
    // MARK: SpcSyncing
    func sync() async {
        do {
            await syncTextProducts()
            
            try await stormRiskRepo.refreshStormRisk(using: client)
            try await severeRiskRepo.refreshHailRisk(using: client)
            try await severeRiskRepo.refreshWindRisk(using: client)
            try await severeRiskRepo.refreshTornadoRisk(using: client)
        } catch {
            logger.error("Error loading Spc feed: \(error.localizedDescription)")
        }
    }
    
    func syncTextProducts() async {
        do {
            try await outlookRepo.refreshConvectiveOutlooks(using: client)
            
            // After refresh, fetch the latest and publish (keeps it simple and reactive)
            if let d = try? await latestIssue(for: .convective) {
                logger.info("Convective outlook published: \(d)")
                publishConvectiveIssue(d)
            }
            
            try await mesoRepo.refreshMesoscaleDiscussions(using: client)
            try await watchRepo.refreshWatches(using: client)
        } catch {
            logger.error("Error loading Spc feed: \(error.localizedDescription)")
        }
    }
    
    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO? {
        try await outlookRepo.current()
    }
    
    // MARK: SpcRiskQuerying
    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel {
        try await stormRiskRepo.active(for: point)
    }
    
    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat {
        try await severeRiskRepo.active(for: point)
    }
    
    // MARK: SpcMapData
    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        try await severeRiskRepo.getSevereRiskShapes()
    }
    
    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        try await stormRiskRepo.getLatestMapData()
    }
    
    func getMesoMapData() async throws -> [MdDTO] {
        try await mesoRepo.getLatestMapData()
    }
    
    
    // MARK: SpcFreshnessPublishing
    // 1) Layer-scope: “what’s the latest ISSUE among what we’re showing?”
    func latestIssue(for product: GeoJSONProduct) async throws -> Date? {
        return nil
    }
    
    func latestIssue(for product: RssProduct) async throws -> Date? {
        try await outlookRepo.current()?.published
    }

    // 2) Location-scope: “what’s the ISSUE of the feature that applies here?”
    func latestIssue(for product: GeoJSONProduct, at coord: CLLocationCoordinate2D) async throws -> Date? {
        return nil
    }
    
    func latestIssue(for product: RssProduct, at coord: CLLocationCoordinate2D) async throws -> Date? {
        return nil
    }
    
    // MARK: - Convective Freshness (seed + stream)
//    func latestConvectiveIssue() async -> Date? { latestConvective }

    func convectiveIssueUpdates() async -> AsyncStream<Date> {
//        AsyncStream<Date>(bufferingPolicy: .bufferingNewest(1)) { continuation in
        AsyncStream<Date> { continuation in
            // Seed with cached value if we have one
            if let latestConvective { continuation.yield(latestConvective) }
            // Store continuation so we can yield future updates
            let id = UUID()
            convectiveContinuations[id] = continuation
            continuation.onTermination = { @Sendable _ in
                Task { [weak self] in
                    await self?.removeConvectiveContinuation(id: id)
                }
            }
        }
    }

    // MARK: SpcCleanup
    func cleanup(daysToKeep: Int = 3) async {
        do {
            try await outlookRepo.purge()
            try await mesoRepo.purge()
            try await watchRepo.purge()
            
            // Clean up the geojson
            try await stormRiskRepo.purge()
            try await severeRiskRepo.purge()
        } catch {
            logger.error("Error cleaning up old Spc feed data: \(error.localizedDescription)")
        }
    }
    
    
    // MARK: Private methods
    private func publishConvectiveIssue(_ date: Date) {
        latestConvective = date
        for c in convectiveContinuations.values { c.yield(date) }
    }

    private func removeConvectiveContinuation(id: UUID) {
        convectiveContinuations[id] = nil
    }
}
