//
//  StormRiskDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/17/25.
//

import Foundation

struct StormRiskDTO: Sendable, Identifiable {
    let id: UUID
    let riskLevel: StormRiskLevel
    let issued: Date
    let valid: Date
    let expires: Date
    let stroke: String?
    let fill: String?
    let polygons: [GeoPolygonEntity]
    
    init(id: UUID = UUID(), riskLevel: StormRiskLevel, issued: Date, expires: Date, valid: Date, stroke: String?, fill: String?, polygons: [GeoPolygonEntity]) {
        self.id = id
        self.riskLevel = riskLevel
        self.issued = issued
        self.valid = valid
        self.expires = expires
        self.polygons = polygons
        self.stroke = stroke
        self.fill = fill
    }
}
