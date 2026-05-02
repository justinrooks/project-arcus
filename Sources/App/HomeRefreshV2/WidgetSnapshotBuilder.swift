import Foundation

struct WidgetSnapshotBuilder {
    struct Input: Sendable {
        let generatedAt: Date
        let snapshotTimestamp: Date?
        let availability: WidgetAvailabilityState
        let stormRisk: StormRiskLevel?
        let severeRisk: SevereWeatherThreat?
        let watches: [WatchRowDTO]
        let mesos: [MdDTO]

        init(
            generatedAt: Date,
            snapshotTimestamp: Date?,
            availability: WidgetAvailabilityState,
            stormRisk: StormRiskLevel?,
            severeRisk: SevereWeatherThreat?,
            watches: [WatchRowDTO],
            mesos: [MdDTO]
        ) {
            self.generatedAt = generatedAt
            self.snapshotTimestamp = snapshotTimestamp
            self.availability = availability
            self.stormRisk = stormRisk
            self.severeRisk = severeRisk
            self.watches = watches
            self.mesos = mesos
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
        let activeAlerts = activeAlerts(watches: input.watches, mesos: input.mesos, now: now)
        let selectedAlert = selectHighestPriorityAlert(from: activeAlerts)

        return WidgetSnapshot(
            generatedAt: input.generatedAt,
            stormRisk: stormRiskDisplay(from: input.stormRisk),
            severeRisk: severeRiskDisplay(from: input.severeRisk),
            selectedAlert: selectedAlert?.displayState,
            hiddenAlertCount: max(0, activeAlerts.count - 1),
            freshness: .from(timestamp: timestamp, now: now),
            availability: .available,
            destination: .summary
        )
    }
}

private extension WidgetSnapshotBuilder {
    enum AlertKind: Sendable {
        case tornado
        case severeThunderstorm
        case flooding
        case mesoscaleDiscussion
        case watch

        var rank: Int {
            switch self {
            case .tornado: return 0
            case .severeThunderstorm: return 1
            case .flooding: return 2
            case .watch: return 3
            case .mesoscaleDiscussion: return 4
            }
        }

        var severity: Int {
            switch self {
            case .tornado: return 5
            case .severeThunderstorm: return 4
            case .flooding: return 3
            case .mesoscaleDiscussion: return 2
            case .watch: return 1
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
                typeLabel: typeLabel,
                severity: kind.severity,
                issuedAt: issuedAt,
                validEnd: validEnd
            )
        }

        private var typeLabel: String {
            switch kind {
            case .mesoscaleDiscussion:
                return "Mesoscale Discussion"
            case .watch:
                return "Watch"
            case .tornado, .severeThunderstorm, .flooding:
                return "Warning"
            }
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

    func activeAlerts(watches: [WatchRowDTO], mesos: [MdDTO], now: Date) -> [ActiveAlertCandidate] {
        let activeWatchCandidates = watches
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
            if $0.kind.rank != $1.kind.rank {
                return $0.kind.rank < $1.kind.rank
            }

            if $0.issuedAt != $1.issuedAt {
                return $0.issuedAt > $1.issuedAt
            }

            return $0.tieBreakerId < $1.tieBreakerId
        }
    }

    func classifyWatch(title: String) -> AlertKind {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.contains("tornado") {
            return .tornado
        }

        if normalized.contains("severe thunderstorm") {
            return .severeThunderstorm
        }

        if normalized.contains("flood") {
            return .flooding
        }

        return .watch
    }
}
