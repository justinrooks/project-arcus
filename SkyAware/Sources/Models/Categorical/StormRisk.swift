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
    var valid: Date
    var expires: Date
    var stroke: String?
    var fill: String?
    var polygons: [GeoPolygonEntity]
    
    convenience init?(from dto: StormRiskDTO) {
        self.init(riskLevel: dto.riskLevel,
                  issued: dto.issued,
                  expires: dto.expires,
                  valid: dto.valid,
                  stroke: dto.stroke,
                  fill: dto.fill,
                  polygons: dto.polygons
        )
    }
    
    init(riskLevel: StormRiskLevel, issued: Date, expires: Date, valid: Date, stroke: String?, fill: String?, polygons: [GeoPolygonEntity]) {
        id = UUID()
        self.key = "\(riskLevel.rawValue)_\(issued.timeIntervalSince1970)"
        self.riskLevel = riskLevel
        self.issued = issued
        self.valid = valid
        self.expires = expires
        self.polygons = polygons
        self.stroke = stroke
        self.fill = fill
    }
}
