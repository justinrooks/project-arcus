import AppIntents
import Foundation

struct GetWeatherAwarenessIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Weather Awareness"
    static let description = IntentDescription(
        "Returns SkyAware’s latest accepted local weather awareness assessment."
    )
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let result = await WeatherAwarenessSnapshotStore.live.read()
        let response = WeatherAwarenessResponseFormatter.make(from: result)
        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}

@available(iOS 26.0, *)
extension GetWeatherAwarenessIntent {
    static var supportedModes: IntentModes { .background }
}

@available(*, deprecated)
extension GetWeatherAwarenessIntent {
    static var openAppWhenRun: Bool { false }
}

struct SkyAwareAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetWeatherAwarenessIntent(),
            phrases: [
                "\(.applicationName), is there any severe weather I should know about",
                "Get weather awareness from \(.applicationName)"
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
        let featuredEvent = warningOrWatch ?? assessment.events.first

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

        switch assessment.alertFreshness {
        case .current:
            if let featuredEvent, warningOrWatch == nil {
                sentences.append("Local \(eventLabel(for: featuredEvent)): \(featuredEvent.title).")
            }
            let remainingEvents = assessment.events.filter { $0.id != featuredEvent?.id }
            if let summary = eventCountSummary(remainingEvents) {
                sentences.append("Also, \(summary).")
            }
        case .stale:
            if let featuredEvent {
                sentences.append("The last accepted alert check included \(featuredEvent.title).")
            }
            if let summary = eventCountSummary(assessment.events) {
                sentences.append(
                    "The time-valid subset of the last accepted assessment is \(summary); " +
                        "current alert status is unverified."
                )
            }
        case .unavailable:
            break
        }

        return sentences.joined(separator: " ")
    }

    private static func eventLabel(for event: WeatherAwarenessSnapshot.Event) -> String {
        event.source == .nationalWeatherService ? "NWS alert" : "SPC mesoscale discussion"
    }

    private static func eventCountSummary(
        _ events: [WeatherAwarenessSnapshot.Event]
    ) -> String? {
        guard !events.isEmpty else { return nil }
        let nwsCount = events.filter { $0.source == .nationalWeatherService }.count
        let mesoCount = events.count - nwsCount
        let details = [
            nwsCount > 0 ? "\(nwsCount) NWS \(nwsCount == 1 ? "alert" : "alerts")" : nil,
            mesoCount > 0 ? "\(mesoCount) SPC mesoscale \(mesoCount == 1 ? "discussion" : "discussions")" : nil
        ].compactMap { $0 }.joined(separator: " and ")
        return "\(events.count) \(events.count == 1 ? "event" : "events") (\(details))"
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
