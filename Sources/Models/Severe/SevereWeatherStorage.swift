import Foundation

enum SevereWeatherThreatStorage {
    private enum Kind: String {
        case allClear
        case wind
        case hail
        case tornado
    }

    static func encode(_ threat: SevereWeatherThreat) -> (kindRawValue: String, probability: Double?) {
        switch threat {
        case .allClear:
            (Kind.allClear.rawValue, nil)
        case .wind(let probability):
            (Kind.wind.rawValue, probability)
        case .hail(let probability):
            (Kind.hail.rawValue, probability)
        case .tornado(let probability):
            (Kind.tornado.rawValue, probability)
        }
    }

    static func decode(kindRawValue: String, probability: Double?) -> SevereWeatherThreat? {
        switch Kind(rawValue: kindRawValue) {
        case .allClear:
            .allClear
        case .wind:
            probability.map(SevereWeatherThreat.wind(probability:))
        case .hail:
            probability.map(SevereWeatherThreat.hail(probability:))
        case .tornado:
            probability.map(SevereWeatherThreat.tornado(probability:))
        case nil:
            nil
        }
    }
}

enum ThreatProbabilityStorage {
    private enum Kind: String {
        case percent
        case significant
    }

    static func encode(_ probability: ThreatProbability) -> (kindRawValue: String, value: Double) {
        switch probability {
        case .percent(let value):
            (Kind.percent.rawValue, value)
        case .significant(let value):
            (Kind.significant.rawValue, Double(value))
        }
    }

    static func decode(kindRawValue: String, value: Double) -> ThreatProbability? {
        switch Kind(rawValue: kindRawValue) {
        case .percent:
            .percent(value)
        case .significant:
            Int(exactly: value).map(ThreatProbability.significant)
        case nil:
            nil
        }
    }
}
