import Foundation

struct WidgetSnapshotBuilder {
    struct Input: Sendable {
        let generatedAt: Date
        let snapshotTimestamp: Date?
        let availability: WidgetAvailabilityState
        let stormRisk: StormRiskLevel?
        let severeRisk: SevereWeatherThreat?
        let alerts: [AlertDTO]
        let mesos: [MdDTO]
        let locationSummary: String?

        init(
            generatedAt: Date,
            snapshotTimestamp: Date?,
            availability: WidgetAvailabilityState,
            stormRisk: StormRiskLevel?,
            severeRisk: SevereWeatherThreat?,
            alerts: [AlertDTO],
            mesos: [MdDTO],
            locationSummary: String? = nil
        ) {
            self.generatedAt = generatedAt
            self.snapshotTimestamp = snapshotTimestamp
            self.availability = availability
            self.stormRisk = stormRisk
            self.severeRisk = severeRisk
            self.alerts = alerts
            self.mesos = mesos
            self.locationSummary = locationSummary
        }
    }

    func build(from input: Input, now: Date = .now) -> WidgetSnapshot {
        if case .unavailable = input.availability {
            return WidgetSnapshot.unavailable(
                generatedAt: input.generatedAt,
                timestamp: input.snapshotTimestamp,
                destination: .summary
            )
        }

        let timestamp = input.snapshotTimestamp ?? input.generatedAt
        let activeAlerts = activeAlerts(alerts: input.alerts, mesos: input.mesos, now: now)
        let selectedAlert = selectHighestPriorityAlert(from: activeAlerts)

        return WidgetSnapshot(
            generatedAt: input.generatedAt,
            stormRisk: stormRiskDisplay(from: input.stormRisk),
            severeRisk: severeRiskDisplay(from: input.severeRisk),
            selectedAlert: selectedAlert?.displayState,
            hiddenAlertCount: max(0, activeAlerts.count - 1),
            freshness: .from(timestamp: timestamp, now: now),
            availability: .available,
            locationSummary: input.locationSummary,
            destination: .summary
        )
    }
}

private extension WidgetSnapshotBuilder {
    enum AlertHazard: Sendable {
        case tornado
        case severeThunderstorm
        case flooding
        case other

        var rank: Int {
            switch self {
            case .tornado: return 0
            case .severeThunderstorm: return 1
            case .flooding: return 2
            case .other: return 3
            }
        }

        var severity: Int {
            switch self {
            case .tornado: return 5
            case .severeThunderstorm: return 4
            case .flooding: return 3
            case .other: return 1
            }
        }
    }

    enum AlertKind: Sendable {
        case warning(AlertHazard)
        case watch(AlertHazard)
        case mesoscaleDiscussion

        var classRank: Int {
            switch self {
            case .warning: return 0
            case .watch: return 1
            case .mesoscaleDiscussion: return 2
            }
        }

        var hazardRank: Int {
            switch self {
            case let .warning(hazard), let .watch(hazard): return hazard.rank
            case .mesoscaleDiscussion: return 0
            }
        }

        var severity: Int {
            switch self {
            case let .warning(hazard): return hazard.severity
            case .watch: return 1
            case .mesoscaleDiscussion: return 2
            }
        }

        var typeLabel: String {
            switch self {
            case .warning: return "Warning"
            case .watch: return "Watch"
            case .mesoscaleDiscussion: return "Mesoscale Discussion"
            }
        }
    }

    struct ActiveAlertCandidate: Sendable {
        let title: String
        let issuedAt: Date
        let validEnd: Date
        let kind: AlertKind
        let tieBreakerId: String

        var displayState: WidgetSelectedAlertRowDisplayState {
            WidgetSelectedAlertRowDisplayState(
                title: title,
                typeLabel: kind.typeLabel,
                severity: kind.severity,
                issuedAt: issuedAt,
                validEnd: validEnd
            )
        }
    }

    func stormRiskDisplay(from level: StormRiskLevel?) -> WidgetRiskDisplayState {
        guard let level else {
            return .placeholder
        }

        return WidgetRiskDisplayState(label: level.message, severity: level.rawValue)
    }

    func severeRiskDisplay(from threat: SevereWeatherThreat?) -> WidgetRiskDisplayState {
        guard let threat else {
            return .placeholder
        }

        return WidgetRiskDisplayState(label: threat.message, severity: threat.priority)
    }

    func activeAlerts(alerts: [AlertDTO], mesos: [MdDTO], now: Date) -> [ActiveAlertCandidate] {
        let activeWatchCandidates = alerts
            .filter { $0.validEnd > now }
            .map { watch in
                ActiveAlertCandidate(
                    title: watch.title,
                    issuedAt: watch.issued,
                    validEnd: watch.validEnd,
                    kind: classifyWatch(title: watch.title),
                    tieBreakerId: watch.id
                )
            }

        let activeMesoCandidates = mesos
            .filter { $0.validEnd > now }
            .map { meso in
                ActiveAlertCandidate(
                    title: "Meso \(meso.number.formatted(.number.grouping(.never)))",
                    issuedAt: meso.issued,
                    validEnd: meso.validEnd,
                    kind: .mesoscaleDiscussion,
                    tieBreakerId: "\(meso.number)"
                )
            }

        return activeWatchCandidates + activeMesoCandidates
    }

    func selectHighestPriorityAlert(from candidates: [ActiveAlertCandidate]) -> ActiveAlertCandidate? {
        candidates.min {
            if $0.kind.classRank != $1.kind.classRank {
                return $0.kind.classRank < $1.kind.classRank
            }

            if $0.kind.hazardRank != $1.kind.hazardRank {
                return $0.kind.hazardRank < $1.kind.hazardRank
            }

            if $0.issuedAt != $1.issuedAt {
                return $0.issuedAt > $1.issuedAt
            }

            return $0.tieBreakerId < $1.tieBreakerId
        }
    }

    func classifyWatch(title: String) -> AlertKind {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hazard: AlertHazard

        if normalized.contains("tornado") {
            hazard = .tornado
        } else if normalized.contains("severe thunderstorm") {
            hazard = .severeThunderstorm
        } else if normalized.contains("flood") {
            hazard = .flooding
        } else {
            hazard = .other
        }

        return normalized.contains("warning") ? .warning(hazard) : .watch(hazard)
    }
}
