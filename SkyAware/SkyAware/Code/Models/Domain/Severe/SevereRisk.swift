//
//  SevereRisk.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import SwiftData

enum ThreatType: String, CaseIterable, Codable, Sendable {
    case wind
    case hail
    case tornado
    case unknown
    
    var displayName: String {
        rawValue.capitalized
    }
}

enum ThreatProbability: Equatable, Hashable, Codable {
    case percent(Double)   // e.g., 2, 5, 15, 30
    case significant(Int)    // SIGN
    
    var description: String {
        switch self {
        case .percent(let value): return "\(value * 100)%"
        case .significant(let value): return "\(value)% Significant Risk"
        }
    }
    
    var intValue: Int {
        switch self {
        case .percent(let value): return Int(value * 100)
        case .significant(let value): return value
        }
    }
    
    var decimalValue: Double {
        switch self {
        case .percent(let value): return value
        case .significant(let value): return Double(value) / 100.0
        }
    }
}

@Model
final class SevereRisk {
    var id: UUID
    @Attribute(.unique) var key: String
    var type: ThreatType
    var probability: ThreatProbability
    var threatLevel: SevereWeatherThreat
    var issued: Date
    var valid: Date
    var expires: Date
    var polygons: [GeoPolygonEntity]
    
    convenience init?(from dto: SevereRiskDTO) {
        self.init(type: dto.type,
                  probability: dto.probability,
                  threatLevel: dto.threatLevel,
                  issued: dto.issued,
                  valid: dto.valid,
                  expires: dto.expires,
                  dn: dto.dn,
                  polygons: dto.polygons,
                  label: dto.label
        )
    }
    
    init(type: ThreatType, probability: ThreatProbability, threatLevel: SevereWeatherThreat, issued: Date, valid: Date, expires: Date, dn: Int, polygons: [GeoPolygonEntity], label: String) {
        self.id = UUID()
        
        if(label == "SIGN") {
            self.key = "\(type.rawValue)_\(issued.timeIntervalSince1970)_p\(dn)_SIGN"
        } else {
            self.key = "\(type.rawValue)_\(issued.timeIntervalSince1970)_p\(dn)"
        }
        
        self.type = type
        self.probability = probability
        self.threatLevel = threatLevel
        self.issued = issued
        self.valid = valid
        self.expires = expires
        self.polygons = polygons
    }
}
