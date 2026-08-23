//
//  SevereWeatherThreat.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/24/25.
//

import SwiftUI

enum SevereWeatherThreat: Comparable, Codable {
    case allClear
    case wind(probability: Double)
    case hail(probability: Double)
    case tornado(probability: Double)

    private enum CodingKeys: String, CodingKey {
        case kind
        case probability
    }

    private enum Kind: String, Codable {
        case allClear
        case wind
        case hail
        case tornado
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case allClear
        case wind
        case hail
        case tornado
    }

    private enum LegacyProbabilityCodingKeys: String, CodingKey {
        case probability
    }

    /// The synthesized encoding for an enum with associated values writes nil for its inactive cases.
    /// SwiftData's custom encoder rejects that operation, so persist exactly one case and its value instead.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .allClear:
            try container.encode(Kind.allClear, forKey: .kind)
        case .wind(let probability):
            try container.encode(Kind.wind, forKey: .kind)
            try container.encode(probability, forKey: .probability)
        case .hail(let probability):
            try container.encode(Kind.hail, forKey: .kind)
            try container.encode(probability, forKey: .probability)
        case .tornado(let probability):
            try container.encode(Kind.tornado, forKey: .kind)
            try container.encode(probability, forKey: .probability)
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.kind) {
            let kind = try container.decode(Kind.self, forKey: .kind)

            switch kind {
            case .allClear:
                self = .allClear
            case .wind:
                self = .wind(probability: try container.decode(Double.self, forKey: .probability))
            case .hail:
                self = .hail(probability: try container.decode(Double.self, forKey: .probability))
            case .tornado:
                self = .tornado(probability: try container.decode(Double.self, forKey: .probability))
            }
            return
        }

        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        if legacyContainer.contains(.allClear) {
            self = .allClear
        } else if legacyContainer.contains(.wind) {
            self = .wind(probability: try Self.legacyProbability(for: .wind, in: legacyContainer))
        } else if legacyContainer.contains(.hail) {
            self = .hail(probability: try Self.legacyProbability(for: .hail, in: legacyContainer))
        } else if legacyContainer.contains(.tornado) {
            self = .tornado(probability: try Self.legacyProbability(for: .tornado, in: legacyContainer))
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown severe weather threat encoding.")
            )
        }
    }

    private static func legacyProbability(
        for key: LegacyCodingKeys,
        in container: KeyedDecodingContainer<LegacyCodingKeys>
    ) throws -> Double {
        let values = try container.nestedContainer(keyedBy: LegacyProbabilityCodingKeys.self, forKey: key)
        return try values.decode(Double.self, forKey: .probability)
    }
    
    var probability: Double {
        switch self {
        case .allClear:
            return 0.0
        case .wind(let p), .hail(let p), .tornado(let p):
            return p
        }
    }
    
    var priority: Int {
        switch self {
        case .tornado: return 3
        case .hail: return 2
        case .wind: return 1
        case .allClear: return 0
        }
    }
    
    static func < (lhs: SevereWeatherThreat, rhs: SevereWeatherThreat) -> Bool {
        lhs.priority < rhs.priority
    }
    
    var id: Self { self }
    
    var iconName: String {
        switch self {
        case .allClear: return "checkmark.seal.fill"
        case .wind: return "wind"
        case .hail: return "cloud.hail.fill"
        case .tornado: return "tornado"
        }
    }
    
    func iconColor(for colorScheme: ColorScheme) -> LinearGradient {
        switch self {
        case .allClear: return Color.riskAllClear.tileGradient(for: colorScheme)
        case .wind: return Color.windTeal.tileGradient(for: colorScheme)
        case .hail: return Color.hailBlue.tileGradient(for: colorScheme)
        case .tornado: return Color.tornadoRed.tileGradient(for: colorScheme)
        }
    }
    
    var message: String {
        switch self {
        case .allClear: return "No Active Threats"
        case .wind: return "Wind"
        case .hail: return "Hail"
        case .tornado: return "Tornado"
        }
    }
    
    var summary: String {
        switch self {
        case .allClear: return "No severe threats expected"
        case .wind: return "Damaging wind possible"
        case .hail: return "1 in or larger hail possible"
        case .tornado: return "Tornados are possible"
        }
    }
    
    var dynamicSummary: String {
        switch self {
        case .tornado: return "\(String(format: "%.0f%%", self.probability * 100)) chance of tornadoes"
        case .hail: return "\(String(format: "%.0f%%", self.probability * 100)) chance of large hail"
        case .wind: return "\(String(format: "%.0f%%", self.probability * 100)) chance of damaging winds"
        case .allClear: return ""
        }
    }
}

extension SevereWeatherThreat {
    func with(probability newValue: Double) -> SevereWeatherThreat {
        switch self {
        case .allClear:
            return .allClear
        case .wind:
            return .wind(probability: newValue)
        case .hail:
            return .hail(probability: newValue)
        case .tornado:
            return .tornado(probability: newValue)
        }
    }
}
