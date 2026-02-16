//
//  FireRHDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 2/16/26.
//

import Foundation

struct FireRiskDTO: Sendable, Identifiable {
    let id: UUID
    let product: String
    let issued: Date
    let valid: Date
    let expires: Date
    let riskLevel: Int
    let riskLevelDescription: String
    let label: String
    let polygons: [GeoPolygonEntity]
    
    init(id: UUID = UUID(), product: String, issued: Date, expires: Date, valid: Date, riskLevel: Int, riskLevelDescription: String, label: String, polygons: [GeoPolygonEntity]) {
        self.id = id
        self.product = product
        self.issued = issued
        self.valid = valid
        self.expires = expires
        self.riskLevel = riskLevel
        self.riskLevelDescription = riskLevelDescription
        self.label = label
        self.polygons = polygons
    }
}
