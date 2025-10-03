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

protocol SpcService: Sendable {
    func sync() async -> Void
    func syncTextProducts() async -> Void
    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel
    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat
    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO?
    
    func cleanup(daysToKeep: Int) async -> Void
    
    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO]
    
    func getStormRiskMapData() async throws -> [StormRiskDTO]
    func getMesoMapData() async throws -> [MdDTO]
}

actor SpcProvider: SpcService {
    private let logger = Logger.spcProvider
    private let outlookRepo: ConvectiveOutlookRepo
    private let mesoRepo: MesoRepo
    private let watchRepo: WatchRepo
    private let stormRiskRepo: StormRiskRepo
    private let severeRiskRepo: SevereRiskRepo
    private let locationmanager: LocationManager
    private let client: SpcClient
    
    init(outlookRepo: ConvectiveOutlookRepo,
         mesoRepo: MesoRepo,
         watchRepo: WatchRepo,
         stormRiskRepo: StormRiskRepo,
         severeRiskRepo: SevereRiskRepo,
         locationManager: LocationManager,
         client: SpcClient) {
        self.outlookRepo = outlookRepo
        self.mesoRepo = mesoRepo
        self.watchRepo = watchRepo
        self.stormRiskRepo = stormRiskRepo
        self.severeRiskRepo = severeRiskRepo
        self.locationmanager = locationManager
        self.client = client
    }
    
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
            try await mesoRepo.refreshMesoscaleDiscussions(using: client)
            try await watchRepo.refreshWatches(using: client)
        } catch {
            logger.error("Error loading Spc feed: \(error.localizedDescription)")
        }
    }
    
    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO? {
        try await outlookRepo.current()
    }
    
    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel {
        try await stormRiskRepo.active(for: point)
    }
    
    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat {
        try await severeRiskRepo.active(for: point)
    }
    
    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        try await severeRiskRepo.getSevereRiskShapes()
    }
    
    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        try await stormRiskRepo.getLatestMapData()
    }
    
    func getMesoMapData() async throws -> [MdDTO] {
        try await mesoRepo.getLatestMapData()
    }
    
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
}
