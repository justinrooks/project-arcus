//
//  FireRisk.swift
//  SkyAware
//
//  Created by Justin Rooks on 2/16/26.
//

import Foundation
import SwiftData

extension FireRisk {
    nonisolated var riskLevelDescription: String {
        switch riskLevel {
        case 5: return "Elevated"
        case 8: return "Critical"
        case 10: return "Extreme"
        default: return "Unknown"
        }
    }
}

@Model
final class FireRisk {
    var id: UUID
    @Attribute(.unique) var key: String
    var product: String
    var issued: Date
    var valid: Date
    var expires: Date
    var riskLevel: Int
    var label: String
    var stroke: String?
    var fill: String?
    var polygons: [GeoPolygonEntity]
    
    convenience init?(from dto: FireRiskDTO) {
        self.init(product: dto.product,
                  issued: dto.issued,
                  expires: dto.expires,
                  valid: dto.valid,
                  riskLevel: dto.riskLevel,
                  label: dto.label,
                  stroke: dto.stroke,
                  fill: dto.fill,
                  polygons: dto.polygons
        )
    }
    
    init(product: String, issued: Date, expires: Date, valid: Date, riskLevel: Int, label: String, stroke: String?, fill: String?, polygons: [GeoPolygonEntity]) {
        id = UUID()
        self.key = "\(product)_\(issued.timeIntervalSince1970)"
        self.product = product
        self.issued = issued
        self.valid = valid
        self.expires = expires
        self.riskLevel = riskLevel
        self.label = label
        self.stroke = stroke
        self.fill = fill
        self.polygons = polygons
    }
}
