import Foundation

/// Read outcomes for the future store boundary. Undecodable bytes must map to `.corruptCache`.
enum WeatherAwarenessResult: Sendable, Equatable {
    enum UnavailableReason: String, Codable, Sendable {
        case noCache
        case corruptCache
        case missingAssessedLocation
        case locationMismatch
    }

    enum Freshness: String, Sendable {
        case current
        case stale
        case unavailable

        fileprivate static func assess(_ timestamp: Date?, now: Date, maximumAge: TimeInterval) -> Self {
            guard let timestamp, timestamp <= now else { return .unavailable }
            return now.timeIntervalSince(timestamp) < maximumAge ? .current : .stale
        }
    }

    struct Assessment: Sendable, Equatable {
        let location: WeatherAwarenessSnapshot.AssessedLocation
        /// Missing individual values remain unavailable; quiet values are never synthesized.
        let risks: WeatherAwarenessSnapshot.Risks
        let riskFreshness: Freshness
        let alertsAssessedAt: Date?
        let alertFreshness: Freshness
        /// Time-valid events from the last accepted assessment, possibly stale.
        let events: [WeatherAwarenessSnapshot.Event]

        /// This is the only state that supports a current no-active-local-alerts statement.
        var hasCurrentQuietAlerts: Bool { alertFreshness == .current && events.isEmpty }
    }

    case unavailable(UnavailableReason)
    case assessment(Assessment)

    // Independent of widgets; match the established system-facing freshness windows.
    static let riskMaximumAge: TimeInterval = 8 * 60 * 60
    static let alertMaximumAge: TimeInterval = 30 * 60

    /// Pure read-time normalization. Never substitute invocation/file-write time for acceptance time.
    /// The optional expected key checks an already-known scope; it does not resolve current location.
    static func select(
        _ snapshot: WeatherAwarenessSnapshot?,
        expectedProjectionKey: String? = nil,
        now: Date
    ) -> Self {
        guard let snapshot else { return .unavailable(.noCache) }
        guard let location = snapshot.location,
              !location.projectionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .unavailable(.missingAssessedLocation)
        }
        if let expectedProjectionKey, expectedProjectionKey != location.projectionKey {
            return .unavailable(.locationMismatch)
        }
        let risks = snapshot.risks
        let hasRisk = risks.storm != nil || risks.severe != nil || risks.fire != nil
        let riskFreshness: Freshness = hasRisk
            ? .assess(risks.assessedAt, now: now, maximumAge: riskMaximumAge) : .unavailable
        let alertFreshness = Freshness.assess(
            snapshot.alertsAssessedAt, now: now, maximumAge: alertMaximumAge
        )
        return .assessment(.init(
            location: location,
            risks: risks,
            riskFreshness: riskFreshness,
            alertsAssessedAt: snapshot.alertsAssessedAt,
            alertFreshness: alertFreshness,
            events: alertFreshness == .unavailable ? [] : snapshot.events.filter {
                $0.issuedAt <= now && $0.validStart <= now && now < $0.validEnd
            }
        ))
    }
}
