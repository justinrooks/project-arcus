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

actor SpcProviderV1 {
    private let logger = Logger.spcProvider
    private let outlookRepo: ConvectiveOutlookRepo
    private let mesoRepo: MesoRepo
    private let watchRepo: WatchRepo
    private let stormRiskRepo: StormRiskRepo
    private let severeRiskRepo: SevereRiskRepo
    private let locationmanager: LocationManager
    
    init(outlookRepo: ConvectiveOutlookRepo,
         mesoRepo: MesoRepo,
         watchRepo: WatchRepo,
         stormRiskRepo: StormRiskRepo,
         severeRiskRepo: SevereRiskRepo,
         locationManager: LocationManager) {
        self.outlookRepo = outlookRepo
        self.mesoRepo = mesoRepo
        self.watchRepo = watchRepo
        self.stormRiskRepo = stormRiskRepo
        self.severeRiskRepo = severeRiskRepo
        self.locationmanager = locationManager
    }
    
    func sync() async {
        do {
            await syncTextProducts()
            
            try await stormRiskRepo.refreshStormRisk()
            try await severeRiskRepo.refreshHailRisk()
            try await severeRiskRepo.refreshWindRisk()
            try await severeRiskRepo.refreshTornadoRisk()
        } catch {
            logger.error("Error loading Spc feed: \(error.localizedDescription)")
        }
    }
    
    func syncTextProducts() async {
        do {
            try await outlookRepo.refreshConvectiveOutlooks()
            try await mesoRepo.refreshMesoscaleDiscussions()
            try await watchRepo.refreshWatches()
        } catch {
            logger.error("Error loading Spc feed: \(error.localizedDescription)")
        }
    }
    
    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel {
        try await stormRiskRepo.active(for: point)
    }
    
    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat {
        try await severeRiskRepo.active(for: point)
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
