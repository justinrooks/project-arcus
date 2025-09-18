//
//  StormRiskDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/17/25.
//

import Foundation

final class StormRiskDTO: Sendable, Identifiable {
    let id: UUID
    let riskLevel: StormRiskLevel
    let issued: Date
    let validUntil: Date
    let polygons: [GeoPolygonEntity]
    
    init(id: UUID = UUID(), riskLevel: StormRiskLevel, issued: Date, validUntil: Date, polygons: [GeoPolygonEntity]) {
        self.id = id
        self.riskLevel = riskLevel
        self.issued = issued
        self.validUntil = validUntil
        self.polygons = polygons
    }
}
