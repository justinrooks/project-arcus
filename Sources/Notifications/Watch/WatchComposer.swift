//
//  WatchComposer.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import OSLog

private enum WatchNotificationEventKind: Sendable {
    case tornadoWarning
    case tornadoWatch
    case severeThunderstormWarning
    case severeThunderstormWatch
    case flashFloodWarning
    case blizzardWarning
    case winterStormWarning
    case fireWarning
    case fireWeatherWatch
    case extremeFireDanger
    case redFlagWarning
    case genericWarning
    case genericWatch
    case generic

    init(eventName: String) {
        let normalized = eventName.normalizedLowercased

        switch normalized {
        case let value where value.contains("tornado warning"):
            self = .tornadoWarning
        case let value where value.contains("tornado watch"):
            self = .tornadoWatch
        case let value where value.contains("severe thunderstorm warning"):
            self = .severeThunderstormWarning
        case let value where value.contains("severe thunderstorm watch"):
            self = .severeThunderstormWatch
        case let value where value.contains("flash flood warning"):
            self = .flashFloodWarning
        case let value where value.contains("blizzard warning"):
            self = .blizzardWarning
        case let value where value.contains("winter storm warning"):
            self = .winterStormWarning
        case let value where value.contains("fire weather watch"):
            self = .fireWeatherWatch
        case let value where value.contains("extreme fire danger"):
            self = .extremeFireDanger
        case let value where value.contains("red flag warning"):
            self = .redFlagWarning
        case let value where value.contains("fire") && value.contains("warning"):
            self = .fireWarning
        case let value where value.contains("warning"):
            self = .genericWarning
        case let value where value.contains("watch"):
            self = .genericWatch
        default:
            self = .generic
        }
    }
}

struct WatchComposer: NotificationComposing {
    private let logger = Logger.notificationsWatchComposer

    func compose(_ event: NotificationEvent) -> (title: String, body: String, subtitle: String) {
        logger.debug("Building watch notification")

        let title = deriveEventName(payload: event.payload)
        let eventKind = WatchNotificationEventKind(eventName: title)
        let body = newAction(for: eventKind)

        return (
            title,
            body,
            "For your area"
        )
    }

    private func deriveEventName(payload: [String: Sendable]) -> String {
        let candidates = [
            payload["title"] as? String,
            payload["headline"] as? String
        ]

        for candidate in candidates {
            guard let trimmed = trimmedNonEmpty(candidate) else { continue }
            return trimmed
        }

        return "Weather Alert"
    }

    private func newAction(for eventKind: WatchNotificationEventKind) -> String {
        switch eventKind {
        case .tornadoWarning:
            return "Tornado danger in your area."
        case .tornadoWatch:
            return "Conditions are favorable for tornadoes in your area."
        case .severeThunderstormWarning:
            return "Damaging winds or large hail possible in your area."
        case .severeThunderstormWatch:
            return "Conditions are favorable for severe storms in your area."
        case .flashFloodWarning:
            return "Flash flooding expected in your area."
        case .blizzardWarning:
            return "Blizzard conditions expected in your area."
        case .winterStormWarning:
            return "Dangerous winter weather expected in your area."
        case .fireWarning, .redFlagWarning:
            return "Critical fire weather conditions in your area."
        case .fireWeatherWatch:
            return "Critical fire weather conditions may develop in your area."
        case .extremeFireDanger:
            return "Extreme fire danger in your area today."
        case .genericWarning:
            return "Weather alert for your area."
        case .genericWatch:
            return "Weather conditions may become hazardous in your area."
        case .generic:
            return "Weather conditions indicated for your area."
        }
    }

    private func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }

        return trimmed
    }
}
