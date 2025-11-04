//
//  SpcProvider+SpcRiskQuerying.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/1/25.
//

import Foundation
import CoreLocation

// MARK: SpcRiskQuerying
extension SpcProvider: SpcRiskQuerying {
    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel {
        try await stormRiskRepo.active(for: point)
    }
    
    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat {
        try await severeRiskRepo.active(for: point)
    }
    
    func getActiveMesos(at time: Date, for point: CLLocationCoordinate2D) async throws -> [MdDTO] {
        try await mesoRepo.active(at: time, point: point)
    }
}
