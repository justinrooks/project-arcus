import AppIntents
import Foundation

struct GetWeatherAwarenessIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Weather Awareness"
    static let description = IntentDescription(
        "Returns SkyAware’s latest accepted local weather awareness assessment."
    )
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let result = await WeatherAwarenessSnapshotStore.live.read()
        let response = WeatherAwarenessResponseFormatter.make(from: result)
        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}

struct SkyAwareAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetWeatherAwarenessIntent(),
            phrases: [
                "Get weather awareness in \(.applicationName)",
                "Check my local weather awareness with \(.applicationName)"
            ],
            shortTitle: "Weather Awareness",
            systemImageName: "cloud.bolt.rain"
        )
    }
}

enum WeatherAwarenessResponseFormatter {
    static func make(from result: WeatherAwarenessResult) -> String {
        switch result {
        case .unavailable(let reason):
            return unavailableMessage(for: reason)
        case .assessment(let assessment):
            return assessmentMessage(assessment)
        }
    }

    private static func unavailableMessage(
        for reason: WeatherAwarenessResult.UnavailableReason
    ) -> String {
        switch reason {
        case .missingAssessedLocation:
            "SkyAware has no saved assessment location. No current location was checked."
        case .locationMismatch:
            "The saved weather assessment does not match the requested location. No current location was checked."
        case .noCache, .corruptCache, .readFailure:
            "SkyAware’s saved weather awareness assessment is unavailable."
        }
    }

    private static func assessmentMessage(
        _ assessment: WeatherAwarenessResult.Assessment
    ) -> String {
        let place = assessment.location.displayLabel ?? "a saved location"
        var sentences = ["Latest accepted assessment for \(place); current location was not checked."]
        let warningOrWatch = assessment.events.first {
            $0.source == .nationalWeatherService &&
                ($0.title.localizedCaseInsensitiveContains("warning") ||
                 $0.title.localizedCaseInsensitiveContains("watch"))
        }

        switch assessment.alertFreshness {
        case .current:
            if let warningOrWatch {
                sentences.append("Active official alert: \(warningOrWatch.title).")
            } else if assessment.hasCurrentQuietAlerts {
                sentences.append(
                    "The latest accepted alert check was at \(timestamp(assessment.alertsAssessedAt)); " +
                        "none of its alerts are still valid now."
                )
            }
        case .stale:
            sentences.append("The last accepted alert check at \(timestamp(assessment.alertsAssessedAt)) is stale.")
        case .unavailable:
            sentences.append("Local alert information is unavailable.")
        }

        switch assessment.riskFreshness {
        case .current:
            sentences.append(
                "Current risk assessment as of \(timestamp(assessment.risks.assessedAt)): " +
                    "\(riskSummary(assessment.risks))."
            )
        case .stale:
            sentences.append(
                "Risk assessment from \(timestamp(assessment.risks.assessedAt)) is stale: " +
                    "\(riskSummary(assessment.risks))."
            )
        case .unavailable:
            sentences.append("Risk information is unavailable.")
        }

        let secondaryEvent = assessment.events.first { $0.id != warningOrWatch?.id }
        if let secondaryEvent {
            let event = secondaryEvent
            let label = event.source == .nationalWeatherService ? "NWS alert" : "SPC mesoscale discussion"
            let state = assessment.alertFreshness == .current ? "Local \(label)" : "Last accepted \(label)"
            sentences.append("\(state): \(event.title).")
        }
        if let warningOrWatch, assessment.alertFreshness == .stale {
            sentences.append("The last accepted alert check included \(warningOrWatch.title).")
        }

        return sentences.joined(separator: " ")
    }

    private static func riskSummary(_ risks: WeatherAwarenessSnapshot.Risks) -> String {
        let storm = risks.storm?.summary ?? "unavailable"
        let severe = risks.severe?.summary ?? "unavailable"
        let fire = risks.fire?.message ?? "unavailable"
        return "storm: \(storm); severe weather: \(severe); fire weather: \(fire)"
    }

    private static func timestamp(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .shortened) ?? "an unknown time"
    }
}
