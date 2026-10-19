import Foundation

/// These are accepted feed contracts, not independently inferred product generations.
struct MapAcceptedUpdateScope: OptionSet, Sendable {
    let rawValue: Int

    static let convective = Self(rawValue: 1 << 0)
    static let fire = Self(rawValue: 1 << 1)
    static let day2Categorical = Self(rawValue: 1 << 2)
    static let day3Categorical = Self(rawValue: 1 << 3)
    static let day2Hazards = Self(rawValue: 1 << 4)
    static let warnings = Self(rawValue: 1 << 5)
    static let meso = Self(rawValue: 1 << 6)
    static let all: Self = [.convective, .fire, .day2Categorical, .day3Categorical, .day2Hazards, .warnings, .meso]

    static func acceptedFeed(_ feedID: String) -> Self {
        switch feedID {
        case "spc.map.convective": .convective
        case "spc.map.fire": .fire
        case "spc.map.categorical.day2": .day2Categorical
        case "spc.map.categorical.day3": .day3Categorical
        case "spc.map.hazards.day2": .day2Hazards
        case "arcus.alert", "arcus.alerts": .warnings
        default: feedID.hasPrefix("home.hot.") ? [.meso, .warnings] : []
        }
    }

    func affects(day: SPCForecastDay, layer: MapLayer) -> Bool {
        if day == .day2 {
            return contains(layer == .categorical ? .day2Categorical : .day2Hazards)
        }
        if day == .day3 { return layer == .categorical && contains(.day3Categorical) }
        return contains(.warnings) || affectsCurrentThematic(layer)
    }

    func affectsCurrentThematic(_ layer: MapLayer) -> Bool {
        switch layer {
        case .categorical, .wind, .hail, .tornado: contains(.convective)
        case .meso: contains(.meso)
        case .fire: contains(.fire)
        }
    }
}
