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
    func getActiveMesos(at time: Date, for point: CLLocationCoordinate2D) async throws -> [MdDTO]
    func getFireRisk(for point: CLLocationCoordinate2D) async throws -> FireRiskLevel
}
