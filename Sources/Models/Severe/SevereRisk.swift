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
        case .percent(let value): return "\(Int(value * 100))%"
        case .significant(let value): return "\(value)% Significant"
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
    var probabilityKindRawValue: String
    var probabilityValue: Double
    var threatKindRawValue: String
    var threatProbability: Double?
    var issued: Date
    var valid: Date
    var expires: Date
    var label: String?
    var stroke: String?
    var fill: String?
    var polygons: [GeoPolygonEntity]
    
    convenience init?(from dto: SevereRiskDTO) {
        self.init(type: dto.type,
                  probability: dto.probability,
                  threatLevel: dto.threatLevel,
                  issued: dto.issued,
                  valid: dto.valid,
                  expires: dto.expires,
                  dn: dto.dn,
                  stroke: dto.stroke,
                  fill: dto.fill,
                  polygons: dto.polygons,
                  label: dto.label
        )
    }
    
    init(type: ThreatType, probability: ThreatProbability, threatLevel: SevereWeatherThreat, issued: Date, valid: Date, expires: Date, dn: Int, stroke: String?, fill: String?, polygons: [GeoPolygonEntity], label: String) {
        self.id = UUID()
        let baseKey = "\(type.rawValue)_\(issued.timeIntervalSince1970)_p\(dn)"
        if let keySuffix = Self.keySuffix(for: label) {
            self.key = "\(baseKey)_\(keySuffix)"
        } else {
            self.key = baseKey
        }
        
        self.type = type
        let probabilityStorage = ThreatProbabilityStorage.encode(probability)
        probabilityKindRawValue = probabilityStorage.kindRawValue
        probabilityValue = probabilityStorage.value
        let threatStorage = SevereWeatherThreatStorage.encode(threatLevel)
        threatKindRawValue = threatStorage.kindRawValue
        threatProbability = threatStorage.probability
        self.issued = issued
        self.valid = valid
        self.expires = expires
        self.label = label
        self.stroke = stroke
        self.fill = fill
        self.polygons = polygons
    }

    private static func keySuffix(for label: String) -> String? {
        let normalized = label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !normalized.isEmpty else { return nil }

        if normalized == "SIGN" {
            return normalized
        }

        if normalized.hasPrefix("CIG"),
           let level = Int(normalized.dropFirst(3)),
           (1...3).contains(level) {
            return "CIG\(level)"
        }

        return nil
    }
}

extension SevereRisk {
    var probability: ThreatProbability {
        get {
            ThreatProbabilityStorage.decode(
                kindRawValue: probabilityKindRawValue,
                value: probabilityValue
            ) ?? .percent(0)
        }
        set {
            let storage = ThreatProbabilityStorage.encode(newValue)
            probabilityKindRawValue = storage.kindRawValue
            probabilityValue = storage.value
        }
    }

    var threatLevel: SevereWeatherThreat {
        get {
            SevereWeatherThreatStorage.decode(
                kindRawValue: threatKindRawValue,
                probability: threatProbability
            ) ?? .allClear
        }
        set {
            let storage = SevereWeatherThreatStorage.encode(newValue)
            threatKindRawValue = storage.kindRawValue
            threatProbability = storage.probability
        }
    }
}
