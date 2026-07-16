//
//  RiskChangeComposer.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/15/26.
//

import Foundation
import OSLog

struct RiskChangeComposer: NotificationComposing {
    private let logger = Logger.notificationsRiskChangeComposer

    func compose(_ event: NotificationEvent) -> (title: String, body: String, subtitle: String) {
        logger.debug("Building risk change notification")

        guard let change = event.payload["change"] as? RiskProfileChange else {
            return ("Your Risk Profile Changed", "", "Updated for your area")
        }

        let lines = RiskProfileChangeFormatting.transitionLines(for: change)

        return (
            "Your Risk Profile Changed",
            lines.joined(separator: "\n"),
            "Updated for \(RiskProfileChangeFormatting.sanitizedLocation(change.locationSummary))"
        )
    }

}

enum RiskProfileChangeFormatting {
    static func transitionLines(for change: RiskProfileChange) -> [String] {
        change.changedDimensions
            .sorted(by: dimensionSort)
            .map { formatTransition(for: $0, change: change) }
    }

    private static func dimensionSort(_ lhs: RiskProfileDimension, _ rhs: RiskProfileDimension) -> Bool {
        sortIndex(for: lhs) < sortIndex(for: rhs)
    }

    private static func sortIndex(for dimension: RiskProfileDimension) -> Int {
        switch dimension {
        case .storm:
            return 0
        case .severe:
            return 1
        case .fire:
            return 2
        }
    }

    private static func formatTransition(for dimension: RiskProfileDimension, change: RiskProfileChange) -> String {
        switch dimension {
        case .storm:
            return "Storm Risk: \(stormText(change.previous.stormRisk)) → \(stormText(change.current.stormRisk))"
        case .severe:
            return "Severe Risk: \(severeText(change.previous.severeRisk)) → \(severeText(change.current.severeRisk))"
        case .fire:
            return "Fire Risk: \(fireText(change.previous.fireRisk)) → \(fireText(change.current.fireRisk))"
        }
    }

    private static func stormText(_ level: StormRiskLevel) -> String {
        level.message
    }

    private static func fireText(_ level: FireRiskLevel) -> String {
        level.status
    }

    private static func severeText(_ threat: SevereWeatherThreat) -> String {
        switch threat {
        case .allClear:
            return "All Clear"
        case .wind(let probability):
            return "Wind \(percentText(probability))"
        case .hail(let probability):
            return "Hail \(percentText(probability))"
        case .tornado(let probability):
            return "Tornado \(percentText(probability))"
        }
    }

    private static func percentText(_ probability: Double) -> String {
        guard probability.isFinite else {
            return "0%"
        }

        let wholePercent = Int((probability * 100).rounded(.toNearestOrAwayFromZero))
        return "\(wholePercent)%"
    }

    static func sanitizedLocation(_ location: String?) -> String {
        let trimmed = location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.isEmpty == false, trimmed.localizedCaseInsensitiveCompare("unknown") != .orderedSame else {
            return "your area"
        }

        return trimmed
    }
}
