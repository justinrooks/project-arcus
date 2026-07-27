//
//  StormSetupAlertEligibility.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

enum StormSetupAlertEligibility {
    private static let qualifyingEventTitles: Set<String> = [
        "severe thunderstorm watch",
        "severe thunderstorm warning",
        "tornado watch",
        "tornado warning"
    ]

    static func hasQualifyingAlert(in alerts: [AlertDTO], now: Date) -> Bool {
        alerts.contains { qualifies($0, now: now) }
    }

    static func qualifies(_ alert: AlertDTO, now: Date) -> Bool {
        let normalizedTitle = alert.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return qualifyingEventTitles.contains(normalizedTitle)
            && alert.issued <= now
            && alert.ends > now
    }
}
