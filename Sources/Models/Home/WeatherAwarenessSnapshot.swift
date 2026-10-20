import Foundation

/// A derived value from one accepted Home record. Publication and storage belong to the next slice.
/// Contains no coordinates, geometry, alert instructions, or claim of the device's current location.
struct WeatherAwarenessSnapshot: Codable, Sendable, Equatable {
    struct AssessedLocation: Codable, Sendable, Equatable {
        /// Internal scope identity; never use this key as a spoken/display location label.
        let projectionKey: String
        let displayLabel: String?
        let assessedAt: Date
    }

    enum Source: String, Codable, Sendable {
        case nationalWeatherService
        case stormPredictionCenter
    }

    struct Risks: Codable, Sendable, Equatable {
        let source: Source
        let convectiveSourceToken: String?
        /// Home retains an aggregate acceptance time, not individual product issue/validity times.
        let assessedAt: Date?
        let storm: StormRiskLevel?
        let severe: SevereWeatherThreat?
        let fire: FireRiskLevel?
    }

    struct Event: Codable, Sendable, Equatable {
        let source: Source
        let id: String
        let title: String
        let issuedAt: Date
        let validStart: Date
        /// NWS terminal time is min(CAP expiration, event end); discussions use SPC validEnd.
        let validEnd: Date
    }

    let location: AssessedLocation?
    let risks: Risks
    /// A nil acceptance time means unavailable, even when the stored collection is empty.
    let alertsAssessedAt: Date?
    /// Canonical Home ordering: official warnings, watches/other NWS alerts, then discussions.
    let events: [Event]

    init(accepted record: HomeProjectionRecord) {
        let key = record.projectionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = record.placemarkSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        location = key.isEmpty ? nil : .init(
            projectionKey: record.projectionKey,
            displayLabel: label?.isEmpty == false ? label : nil,
            assessedAt: record.locationTimestamp
        )
        risks = .init(
            source: .stormPredictionCenter,
            convectiveSourceToken: record.convectiveSourceToken,
            assessedAt: record.lastSlowProductsLoadAt,
            storm: record.stormRisk, severe: record.severeRisk, fire: record.fireRisk
        )
        alertsAssessedAt = record.lastHotAlertsLoadAt
        events = AlertPresentationOrdering.ordered(record.activeAlerts).map {
            .init(source: .nationalWeatherService, id: $0.id, title: $0.title,
                  issuedAt: $0.issued, validStart: $0.validStart, validEnd: min($0.expires, $0.ends))
        } + AlertPresentationOrdering.ordered(record.activeMesos).map {
            .init(source: .stormPredictionCenter, id: String($0.number), title: $0.title,
                  issuedAt: $0.issued, validStart: $0.validStart, validEnd: $0.validEnd)
        }
    }
}
