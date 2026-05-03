import Foundation

struct WidgetSnapshot: Codable, Sendable, Equatable {
    static let unavailableMessage = "Open SkyAware to update local risk."

    let generatedAt: Date
    let stormRisk: WidgetRiskDisplayState
    let severeRisk: WidgetRiskDisplayState
    let selectedAlert: WidgetSelectedAlertRowDisplayState?
    let hiddenAlertCount: Int
    let freshness: WidgetFreshnessState
    let availability: WidgetAvailabilityState
    let locationSummary: String?
    let destination: WidgetSummaryDestination

    init(
        generatedAt: Date,
        stormRisk: WidgetRiskDisplayState,
        severeRisk: WidgetRiskDisplayState,
        selectedAlert: WidgetSelectedAlertRowDisplayState?,
        hiddenAlertCount: Int,
        freshness: WidgetFreshnessState,
        availability: WidgetAvailabilityState,
        locationSummary: String? = nil,
        destination: WidgetSummaryDestination = .summary
    ) {
        self.generatedAt = generatedAt
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.selectedAlert = selectedAlert
        self.hiddenAlertCount = max(0, hiddenAlertCount)
        self.freshness = freshness
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
            hiddenAlertCount: 0,
            freshness: WidgetFreshnessState(timestamp: timestamp, state: .unavailable),
            availability: .unavailable(message: unavailableMessage),
            destination: destination
        )
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
