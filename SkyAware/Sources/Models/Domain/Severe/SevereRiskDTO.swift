//
//  SevereRiskDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation

struct SevereRiskDTO: Sendable, Identifiable {
    let id: UUID
    let type: ThreatType
    let probability: ThreatProbability
    let threatLevel: SevereWeatherThreat
    let issued: Date
    let valid: Date
    let expires: Date
    let dn: Int
    let label: String
    let polygons: [GeoPolygonEntity]
    
    init(id: UUID = UUID(), type: ThreatType, probability: ThreatProbability, threatLevel: SevereWeatherThreat, issued: Date, valid: Date, expires: Date, dn: Int, polygons: [GeoPolygonEntity], label: String) {
        self.id = id
        self.type = type
        self.probability = probability
        self.threatLevel = threatLevel
        self.issued = issued
        self.valid = valid
        self.expires = expires
        self.dn = dn
        self.polygons = polygons
        self.label = label
    }
}
