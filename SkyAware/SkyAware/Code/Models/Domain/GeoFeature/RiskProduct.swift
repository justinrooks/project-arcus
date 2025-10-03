//
//  UnifiedRisk.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/27/25.
//

import Foundation
import SwiftData

// MARK: - Raw-backed enums (computed in model; stored as primitives)

enum RiskProduct: Int, Codable, Sendable {
    case categorical = 0
    case severe = 1
}

@Model
final class RiskFeature {
    // Identity
    var id: UUID
    @Attribute(.unique) var key: String

    // Product/category (stored raw for filtering)
    private var productRaw: Int  // RiskProduct
    // Categorical: StormRiskLevel; Severe: n/a
    private var riskLevelRaw: Int?  // StormRiskLevel.rawValue
    // Severe: ThreatType; Categorical: n/a
    private var threatTypeRaw: String?  // ThreatType.rawValue

    // Severe-only probability bits (filterable primitives)
    // DN: 2, 5, 10, 15, 30, 45, 60, etc.
    private var dn: Int?
    private var isSignificant: Bool?

    // Display hints (optional)
    var label: String?

    // Timing (filterable)
    var issued: Date
    var valid: Date
    var expires: Date

    // Geometry
    var polygons: [GeoPolygonEntity]
    
    // Raw Data
    var bytes: Data

    // ---- Computed API (nice enums for the rest of your code) ----
    var product: RiskProduct {
        get { RiskProduct(rawValue: productRaw)! }
        set { productRaw = newValue.rawValue }
    }

    var riskLevel: StormRiskLevel? {
        get { riskLevelRaw.flatMap(StormRiskLevel.init(rawValue:)) }
        set { riskLevelRaw = newValue?.rawValue }
    }

    var threatType: ThreatType? {
        get { threatTypeRaw.flatMap(ThreatType.init(rawValue:)) }
        set { threatTypeRaw = newValue?.rawValue }
    }

    var probability: ThreatProbability? {
        get {
            guard let dn else { return nil }
            if isSignificant == true { return .significant(dn) }
            return .percent(Double(dn) / 100.0)
        }
        set {
            switch newValue {
            case .percent(let pct)?:
                dn = Int((pct * 100).rounded())
                isSignificant = false
            case .significant(let val)?:
                dn = val
                isSignificant = true
            case nil:
                dn = nil
                isSignificant = nil
            }
        }
    }
    
    // Unified UI model projection (not persisted)
    var uiRisk: WeatherRisk {
        get {
            guard let product = RiskProduct(rawValue: productRaw) else { return .none }
            switch product {
            case .categorical:
                guard let raw = riskLevelRaw, let level = StormRiskLevel(rawValue: raw) else { return .none }
                return level == .allClear ? .none : .categorical(level: level)

            case .severe:
                guard
                    let tRaw = threatTypeRaw,
                    let type = SevereType(rawValue: tRaw),
                    let dn = dn
                else { return .none }
                // DN is an integer percent (2, 5, 10, …); keep your Severe UI using 0–100 scale.
                let p = Double(dn)
                return .severe(type: type, probability: p, isSignificant: isSignificant ?? false)
            }
        }
        set {
            switch newValue {
            case .none:
                productRaw = RiskProduct.categorical.rawValue
                riskLevelRaw = StormRiskLevel.allClear.rawValue
                threatTypeRaw = nil
                dn = nil
                isSignificant = nil

            case .categorical(let level):
                productRaw = RiskProduct.categorical.rawValue
                riskLevelRaw = level.rawValue
                threatTypeRaw = nil
                dn = nil
                isSignificant = nil

            case .severe(let type, let probability, let sig):
                productRaw = RiskProduct.severe.rawValue
                riskLevelRaw = nil
                threatTypeRaw = type.rawValue
                dn = Int(probability.rounded())          // probability in 0–100 scale → DN Int
                isSignificant = sig
            }
        }
    }

    // ---- Inits ----

    /// Designated init for categorical (StormRisk)
    init(categorical level: StormRiskLevel,
         issued: Date,
         valid: Date,
         expires: Date,
         polygons: [GeoPolygonEntity],
         data: Data)
    {
        self.id = UUID()
        self.productRaw = RiskProduct.categorical.rawValue
        self.riskLevelRaw = level.rawValue
        self.threatTypeRaw = nil
        self.dn = nil
        self.isSignificant = nil
        self.issued = issued
        self.valid = valid
        self.expires = expires
        self.polygons = polygons
        self.key = Self.makeCategoricalKey(level: level, issued: issued)
        self.bytes = data
    }

    /// Designated init for severe (tornado/hail/wind)
    init(severe type: ThreatType,
         dn: Int,
         isSignificant: Bool,
         issued: Date,
         valid: Date,
         expires: Date,
         polygons: [GeoPolygonEntity],
         data: Data,
         label: String? = nil)
    {
        self.id = UUID()
        self.productRaw = RiskProduct.severe.rawValue
        self.riskLevelRaw = nil
        self.threatTypeRaw = type.rawValue
        self.dn = dn
        self.isSignificant = isSignificant
        self.issued = issued
        self.valid = valid
        self.expires = expires
        self.polygons = polygons
        self.label = label
        self.key = Self.makeSevereKey(type: type, issued: issued, dn: dn, isSIG: isSignificant)
        self.bytes = data
    }

//    // Convenience inits from your DTOs
//    convenience init?(from dto: StormRiskDTO) {
//        self.init(categorical: dto.riskLevel,
//                  issued: dto.issued,
//                  valid: dto.valid,
//                  expires: dto.expires,
//                  polygons: dto.polygons)
//    }
//
//    convenience init?(from dto: SevereRiskDTO) {
//        let isSIG = (dto.label == "SIGN") || dto.isSignificant == true
//        self.init(severe: dto.type,
//                  dn: dto.dn,
//                  isSignificant: isSIG,
//                  issued: dto.issued,
//                  valid: dto.valid,
//                  expires: dto.expires,
//                  polygons: dto.polygons,
//                  label: dto.label)
//    }
    
    
}

// MARK: - Key builders (semantic, human-readable)
private extension RiskFeature {
    static func makeSevereKey(type: ThreatType, issued: Date, dn: Int, isSIG: Bool) -> String {
        let t = type.rawValue
        let ts = String(Int(issued.timeIntervalSince1970))
        return isSIG ? "\(t)_\(ts)_p\(String(format: "%02d", dn))sig"
                     : "\(t)_\(ts)_p\(String(format: "%02d", dn))"
    }

    static func makeCategoricalKey(level: StormRiskLevel, issued: Date) -> String {
        let ts = String(Int(issued.timeIntervalSince1970))
        return "cat_\(ts)_\(level.rawValue)"
    }
}
