//
//  SevereRiskDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation

final class SevereRiskDTO: Sendable, Identifiable {
    let id: UUID
    let type: ThreatType
    let probability: ThreatProbability
    let threatLevel: SevereWeatherThreat
    let issued: Date
    let validUntil: Date
    let polygons: [GeoPolygonEntity]
    
    init(id: UUID = UUID(), type: ThreatType, probability: ThreatProbability, threatLevel: SevereWeatherThreat, issued: Date, validUntil: Date, polygons: [GeoPolygonEntity]) {
        self.id = id
        self.type = type
        self.probability = probability
        self.threatLevel = threatLevel
        self.issued = issued
        self.validUntil = validUntil
        self.polygons = polygons
    }
}
