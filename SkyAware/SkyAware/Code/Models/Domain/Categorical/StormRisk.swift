//
//  StormRisk.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/17/25.
//

import Foundation
import SwiftData

@Model
final class StormRisk {
    var id: UUID
    @Attribute(.unique) var key: String
    var riskLevel: StormRiskLevel
    var issued: Date
    var validUntil: Date
    var polygons: [GeoPolygonEntity]
    
    convenience init?(from dto: StormRiskDTO) {
        self.init(riskLevel: dto.riskLevel,
                  issued: dto.issued,
                  validUntil: dto.validUntil,
                  polygons: dto.polygons
        )
    }
    
    init(riskLevel: StormRiskLevel, issued: Date, validUntil: Date, polygons: [GeoPolygonEntity]) {
        id = UUID()
        self.key = "\(riskLevel.rawValue)_\(issued.timeIntervalSince1970)"
        self.riskLevel = riskLevel
        self.issued = issued
        self.validUntil = validUntil
        self.polygons = polygons
    }
}
