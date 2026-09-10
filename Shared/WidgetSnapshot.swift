import Foundation

struct WidgetSnapshot: Codable, Sendable, Equatable {
    static let unavailableMessage = "Open SkyAware to update local risk."

    let generatedAt: Date
    let stormRisk: WidgetRiskDisplayState
    let severeRisk: WidgetRiskDisplayState
    let selectedAlert: WidgetSelectedAlertRowDisplayState?
    let activeAlerts: [WidgetSelectedAlertRowDisplayState]
    let hiddenAlertCount: Int
    let freshness: WidgetFreshnessState
    let alertFreshness: WidgetFreshnessState?
    let availability: WidgetAvailabilityState
    let locationSummary: String?
    let destination: WidgetSummaryDestination

    var knownActiveAlertCount: Int {
        max(
            activeAlerts.count,
            selectedAlert == nil ? 0 : max(0, hiddenAlertCount) + 1
        )
    }

    init(
        generatedAt: Date,
        stormRisk: WidgetRiskDisplayState,
        severeRisk: WidgetRiskDisplayState,
        selectedAlert: WidgetSelectedAlertRowDisplayState?,
        activeAlerts: [WidgetSelectedAlertRowDisplayState] = [],
        hiddenAlertCount: Int,
        freshness: WidgetFreshnessState,
        alertFreshness: WidgetFreshnessState? = nil,
        availability: WidgetAvailabilityState,
        locationSummary: String? = nil,
        destination: WidgetSummaryDestination = .summary
    ) {
        self.generatedAt = generatedAt
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.selectedAlert = selectedAlert
        self.activeAlerts = activeAlerts
        self.hiddenAlertCount = max(0, hiddenAlertCount)
        self.freshness = freshness
        self.alertFreshness = alertFreshness
        self.availability = availability
        self.locationSummary = locationSummary
        self.destination = destination
    }

    static func unavailable(
        generatedAt: Date,
        timestamp: Date? = nil,
        destination: WidgetSummaryDestination = .summary
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: generatedAt,
            stormRisk: .placeholder,
            severeRisk: .placeholder,
            selectedAlert: nil,
            activeAlerts: [],
            hiddenAlertCount: 0,
            freshness: WidgetFreshnessState(timestamp: timestamp, state: .unavailable),
            alertFreshness: timestamp.map { WidgetFreshnessState(timestamp: $0, state: .unavailable) },
            availability: .unavailable(message: unavailableMessage),
            destination: destination
        )
    }

    func normalizedForWidgetPresentation(at now: Date) -> WidgetSnapshot {
        guard case .available = availability else {
            return self
        }

        let normalizedFreshness: WidgetFreshnessState
        if let timestamp = freshness.timestamp {
            normalizedFreshness = .from(
                timestamp: timestamp,
                now: now,
                staleAfter: WidgetFreshnessPolicy.riskStaleAfter
            )
        } else {
            normalizedFreshness = freshness
        }

        let normalizedAlertFreshness = alertFreshness.map { freshness in
            guard let timestamp = freshness.timestamp else { return freshness }
            return .from(
                timestamp: timestamp,
                now: now,
                staleAfter: WidgetFreshnessPolicy.alertStaleAfter
            )
        }

        let normalizedActiveAlerts = activeAlerts.filter { alert in
            guard let validEnd = alert.validEnd else { return true }
            return validEnd > now
        }
        let activeSelectedAlert: WidgetSelectedAlertRowDisplayState?
        let activeHiddenAlertCount: Int
        if activeAlerts.isEmpty {
            if let selectedAlert, let validEnd = selectedAlert.validEnd, validEnd <= now {
                activeSelectedAlert = nil
                activeHiddenAlertCount = 0
            } else {
                activeSelectedAlert = selectedAlert
                activeHiddenAlertCount = hiddenAlertCount
            }
        } else {
            activeSelectedAlert = normalizedActiveAlerts.first
            activeHiddenAlertCount = normalizedActiveAlerts.isEmpty
                ? 0
                : max(0, hiddenAlertCount - (activeAlerts.count - normalizedActiveAlerts.count))
        }

        return WidgetSnapshot(
            generatedAt: generatedAt,
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            selectedAlert: activeSelectedAlert,
            activeAlerts: normalizedActiveAlerts,
            hiddenAlertCount: activeHiddenAlertCount,
            freshness: normalizedFreshness,
            alertFreshness: normalizedAlertFreshness,
            availability: availability,
            locationSummary: locationSummary,
            destination: destination
        )
    }
}

enum WidgetLargeAlertPresentation {
    static let regularVisibleAlertCapacity = 3
    static let accessibilityVisibleAlertCapacity = 1

    static func visibleAlertCapacity(isAccessibilitySize: Bool) -> Int {
        isAccessibilitySize ? accessibilityVisibleAlertCapacity : regularVisibleAlertCapacity
    }

    static func visibleAlerts(
        from alerts: [WidgetSelectedAlertRowDisplayState],
        isAccessibilitySize: Bool
    ) -> [WidgetSelectedAlertRowDisplayState] {
        Array(alerts.prefix(visibleAlertCapacity(isAccessibilitySize: isAccessibilitySize)))
    }

    static func overflowCount(knownAlertCount: Int, visibleAlertCount: Int) -> Int {
        max(0, knownAlertCount - visibleAlertCount)
    }
}

struct WidgetSnapshotRelevance: Equatable, Sendable {
    let score: Float
    let duration: TimeInterval
}

enum WidgetSnapshotRelevancePolicy {
    private static let maximumDuration: TimeInterval = 15 * 60
    private static let warningScore: Float = 100
    private static let watchScore: Float = 75
    private static let mesoscaleScore: Float = 50

    enum Surface: Sendable {
        case stormRisk
        case severeRisk
        case combined
    }

    static func relevance(for snapshot: WidgetSnapshot, now: Date) -> WidgetSnapshotRelevance? {
        relevance(for: snapshot, surface: .combined, now: now)
    }

    static func relevance(
        for snapshot: WidgetSnapshot,
        surface: Surface,
        now: Date
    ) -> WidgetSnapshotRelevance? {
        guard case .available = snapshot.availability else { return nil }

        switch surface {
        case .stormRisk:
            return riskRelevance(
                score: stormRiskScore(snapshot.stormRisk),
                freshness: snapshot.freshness,
                staleAfter: WidgetFreshnessPolicy.riskStaleAfter,
                now: now
            )
        case .severeRisk:
            return riskRelevance(
                score: severeRiskScore(snapshot.severeRisk),
                freshness: snapshot.freshness,
                staleAfter: WidgetFreshnessPolicy.riskStaleAfter,
                now: now
            )
        case .combined:
            return combinedRelevance(for: snapshot, now: now)
        }
    }

    private static func selectedAlertScore(_ alert: WidgetSelectedAlertRowDisplayState?) -> Float? {
        guard let alert else { return nil }
        let type = alert.typeLabel.localizedLowercase
        if type.contains("warning") { return warningScore }
        if type.contains("watch") { return watchScore }
        if type.contains("mesoscale") { return mesoscaleScore }
        return nil
    }

    private static func stormRiskScore(_ risk: WidgetRiskDisplayState) -> Float? {
        risk.severity > 0 ? 10 + (Float(risk.severity) * 5) : nil
    }

    private static func severeRiskScore(_ risk: WidgetRiskDisplayState) -> Float? {
        risk.severity > 0 ? 10 + (Float(risk.severity) * 10) : nil
    }

    private static func riskRelevance(
        score: Float?,
        freshness: WidgetFreshnessState,
        staleAfter: TimeInterval,
        now: Date
    ) -> WidgetSnapshotRelevance? {
        guard let score, isFresh(freshness, staleAfter: staleAfter, now: now) else { return nil }
        let duration = freshnessDuration(freshness, staleAfter: staleAfter, now: now)
        return duration > 0 ? WidgetSnapshotRelevance(score: score, duration: duration) : nil
    }

    private static func combinedRelevance(for snapshot: WidgetSnapshot, now: Date) -> WidgetSnapshotRelevance? {
        let alertFreshness = snapshot.alertFreshness ?? snapshot.freshness
        let alertRelevance: WidgetSnapshotRelevance? = {
            guard let score = selectedAlertScore(snapshot.selectedAlert),
                  isFresh(alertFreshness, staleAfter: WidgetFreshnessPolicy.alertStaleAfter, now: now),
                  let duration = selectedAlertDuration(snapshot.selectedAlert, now: now)
            else { return nil }
            let boundedDuration = min(
                freshnessDuration(alertFreshness, staleAfter: WidgetFreshnessPolicy.alertStaleAfter, now: now),
                duration
            )
            return boundedDuration > 0 ? WidgetSnapshotRelevance(score: score, duration: boundedDuration) : nil
        }()
        let storm = riskRelevance(
            score: stormRiskScore(snapshot.stormRisk),
            freshness: snapshot.freshness,
            staleAfter: WidgetFreshnessPolicy.riskStaleAfter,
            now: now
        )
        let severe = riskRelevance(
            score: severeRiskScore(snapshot.severeRisk),
            freshness: snapshot.freshness,
            staleAfter: WidgetFreshnessPolicy.riskStaleAfter,
            now: now
        )
        return [alertRelevance, storm, severe].compactMap { $0 }.max { $0.score < $1.score }
    }

    private static func isFresh(
        _ freshness: WidgetFreshnessState,
        staleAfter: TimeInterval,
        now: Date
    ) -> Bool {
        freshness.state == .fresh && !freshness.isStale(at: now, staleAfter: staleAfter)
    }

    private static func freshnessDuration(
        _ freshness: WidgetFreshnessState,
        staleAfter: TimeInterval,
        now: Date
    ) -> TimeInterval {
        guard let timestamp = freshness.timestamp else { return maximumDuration }
        return min(maximumDuration, staleAfter - now.timeIntervalSince(timestamp))
    }

    private static func selectedAlertDuration(
        _ alert: WidgetSelectedAlertRowDisplayState?,
        now: Date
    ) -> TimeInterval? {
        guard let validEnd = alert?.validEnd else { return nil }
        return validEnd.timeIntervalSince(now)
    }
}

struct WidgetRiskDisplayState: Codable, Sendable, Equatable {
    let label: String
    let severity: Int

    static let placeholder = WidgetRiskDisplayState(label: "--", severity: 0)
}

struct WidgetSelectedAlertRowDisplayState: Codable, Sendable, Equatable {
    let title: String
    let typeLabel: String
    let severity: Int
    let issuedAt: Date?
    let validEnd: Date?

    init(
        title: String,
        typeLabel: String,
        severity: Int,
        issuedAt: Date?,
        validEnd: Date? = nil
    ) {
        self.title = title
        self.typeLabel = typeLabel
        self.severity = severity
        self.issuedAt = issuedAt
        self.validEnd = validEnd
    }
}

struct WidgetFreshnessState: Codable, Sendable, Equatable {
    enum State: String, Codable, Sendable {
        case fresh
        case stale
        case unavailable
    }

    static let staleThreshold: TimeInterval = 30 * 60

    let timestamp: Date?
    let state: State

    static func from(
        timestamp: Date,
        now: Date,
        staleAfter: TimeInterval = staleThreshold
    ) -> WidgetFreshnessState {
        let isStale = now.timeIntervalSince(timestamp) >= staleAfter
        return WidgetFreshnessState(timestamp: timestamp, state: isStale ? .stale : .fresh)
    }

    func isStale(at now: Date, staleAfter: TimeInterval = staleThreshold) -> Bool {
        guard let timestamp else {
            return false
        }

        return now.timeIntervalSince(timestamp) >= staleAfter
    }
}

enum WidgetFreshnessPolicy {
    static let alertStaleAfter: TimeInterval = 30 * 60
    static let riskStaleAfter: TimeInterval = 8 * 60 * 60
}

extension WidgetSnapshot {
    private enum CodingKeys: String, CodingKey {
        case generatedAt, stormRisk, severeRisk, selectedAlert, activeAlerts, hiddenAlertCount
        case freshness, alertFreshness, availability, locationSummary, destination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let selectedAlert = try container.decodeIfPresent(
            WidgetSelectedAlertRowDisplayState.self,
            forKey: .selectedAlert
        )
        self.init(
            generatedAt: try container.decode(Date.self, forKey: .generatedAt),
            stormRisk: try container.decode(WidgetRiskDisplayState.self, forKey: .stormRisk),
            severeRisk: try container.decode(WidgetRiskDisplayState.self, forKey: .severeRisk),
            selectedAlert: selectedAlert,
            activeAlerts: try container.decodeIfPresent(
                [WidgetSelectedAlertRowDisplayState].self,
                forKey: .activeAlerts
            ) ?? selectedAlert.map { [$0] } ?? [],
            hiddenAlertCount: try container.decode(Int.self, forKey: .hiddenAlertCount),
            freshness: try container.decode(WidgetFreshnessState.self, forKey: .freshness),
            alertFreshness: try container.decodeIfPresent(WidgetFreshnessState.self, forKey: .alertFreshness),
            availability: try container.decode(WidgetAvailabilityState.self, forKey: .availability),
            locationSummary: try container.decodeIfPresent(String.self, forKey: .locationSummary),
            destination: try container.decode(WidgetSummaryDestination.self, forKey: .destination)
        )
    }
}

enum WidgetAvailabilityState: Codable, Sendable, Equatable {
    case available
    case unavailable(message: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case message
    }

    private enum Kind: String, Codable {
        case available
        case unavailable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .available:
            self = .available
        case .unavailable:
            let message = try container.decode(String.self, forKey: .message)
            self = .unavailable(message: message)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .available:
            try container.encode(Kind.available, forKey: .kind)
        case .unavailable(let message):
            try container.encode(Kind.unavailable, forKey: .kind)
            try container.encode(message, forKey: .message)
        }
    }
}

enum WidgetSummaryDestination: String, Codable, Sendable, Equatable {
    case summary
}
