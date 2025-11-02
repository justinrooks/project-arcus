//
//  SpcRiskQuerying.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import Foundation
import CoreLocation

protocol SpcRiskQuerying: Sendable {
    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel
    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat
}
