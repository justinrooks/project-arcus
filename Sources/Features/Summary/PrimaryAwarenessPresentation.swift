//
//  PrimaryAwarenessPresentation.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import SwiftUI

enum SummaryAwarenessDestination: Equatable, Sendable {
    case alerts
    case map(MapLayer)
    case none

    var accessibilityHint: String? {
        switch self {
        case .alerts:
            return "Opens the alert center."
        case .map(let layer):
            if layer == .fire {
                return "Opens the fire risk map."
            }

            return "Opens the \(layer.title.lowercased()) map."
        case .none:
            return nil
        }
    }
}

struct SummaryAwarenessAccessibilityContract: Equatable, Sendable {
    let label: String
    let value: String
    let hint: String?
}

enum SummaryAwarenessPrimaryState: Equatable, Sendable {
    case alert(title: String, detail: String)
    case severe(SevereWeatherThreat)
    case storm(StormRiskLevel)
    case fire(FireRiskLevel)
    case loading(title: String, detail: String, symbolName: String)
    case quiet

    static func resolve(
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        fireRisk: FireRiskLevel?,
        alerts: [AlertDTO],
        todayContentState: TodayContentState,
        isStormRiskResolving: Bool,
        isSevereRiskResolving: Bool,
        isFireRiskResolving: Bool,
        isOffline: Bool
    ) -> SummaryAwarenessPrimaryState {
        if let alert = Self.activeAlert(from: alerts) {
            return .alert(title: alert.title, detail: alert.detail)
        }

        if let severeRisk, severeRisk != .allClear {
            return .severe(severeRisk)
        }

        if let stormRisk, stormRisk != .allClear {
            return .storm(stormRisk)
        }

        if let fireRisk, fireRisk != .clear, isMeaningfullyElevated(fireRisk) {
            return .fire(fireRisk)
        }

        if isOffline == false, todayContentState.showsResolvingSurface {
            if isSevereRiskResolving {
                return .loading(
                    title: "Severe Risk",
                    detail: "Getting severe risk…",
                    symbolName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
                )
            }

            if isStormRiskResolving {
                return .loading(
                    title: "Storm Risk",
                    detail: "Getting storm risk…",
                    symbolName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
                )
            }

            if isFireRiskResolving {
                return .loading(
                    title: "Fire Risk",
                    detail: "Getting fire risk…",
                    symbolName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
                )
            }

        }

        return .quiet
    }

    var source: SummaryAwarenessSource {
        switch self {
        case .alert:
            .alert
        case .severe:
            .severeRisk
        case .storm:
            .stormRisk
        case .fire:
            .fireRisk
        case .loading:
            .loading
        case .quiet:
            .synthesizedQuietState
        }
    }

    private static func isMeaningfullyElevated(_ level: FireRiskLevel) -> Bool {
        level != .clear
    }

    private static func activeAlert(from alerts: [AlertDTO]) -> (title: String, detail: String)? {
        let ordered = AlertPresentationOrdering.ordered(alerts, endDate: \.expires)

        guard let alert = ordered.first(where: { Self.isWarningOrWatch(title: $0.title) }) else {
            return nil
        }

        if Self.isWatch(title: alert.title) {
            return (
                title: alert.title.trimmingCharacters(in: .whitespacesAndNewlines),
                detail: Self.watchHeroDetail(expires: alert.expires)
            )
        }

        let detail = alert.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = alert.areaSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            title: alert.title.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.isEmpty ? fallback : detail
        )
    }

    private static func isWarningOrWatch(title: String) -> Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        return normalized.contains("warning") || normalized.contains("watch")
    }

    private static func isWatch(title: String) -> Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase.contains("watch")
    }

    static func watchHeroDetail(
        expires: Date?,
        now: Date = .now,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        guard let expires else {
            return "Watch currently in effect"
        }

        let calendar = Calendar(identifier: .gregorian)
        var localCalendar = calendar
        localCalendar.timeZone = timeZone

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.calendar = localCalendar
        formatter.dateFormat = localCalendar.isDate(expires, inSameDayAs: now)
            ? "h:mm a zzz"
            : "MMM d, h:mm a zzz"

        return "In effect until \(formatter.string(from: expires))"
    }

    var title: String {
        switch self {
        case let .alert(title, _):
            title
        case let .severe(threat):
            threat.message
        case let .storm(level):
            level.message
        case let .fire(level):
            level.status == "Clear" ? "No Fire Risk" : "\(level.status) Fire Risk"
        case let .loading(title, _, _):
            title
        case .quiet:
            "Quiet Weather"
        }
    }

    var detail: String {
        switch self {
        case let .alert(_, detail):
            detail
        case let .severe(threat):
            threat.dynamicSummary.isEmpty ? threat.summary : threat.dynamicSummary
        case let .storm(level):
            level.summary
        case let .fire(level):
            level.message
        case let .loading(_, detail, _):
            detail
        case .quiet:
            "No active severe threats nearby"
        }
    }

    var symbolName: String {
        switch self {
        case let .alert(title, _):
            styleForType(.watch, title).0
        case let .severe(threat):
            threat.iconName
        case let .storm(level):
            level.iconName
        case let .fire(level):
            level.symbol
        case let .loading(_, _, symbolName):
            symbolName
        case .quiet:
            "checkmark.seal.fill"
        }
    }

    func background(for colorScheme: ColorScheme) -> LinearGradient {
        switch self {
        case let .alert(title, _):
            return styleForType(.watch, title).1.tileGradient(for: colorScheme)
        case let .severe(threat):
            return threat.iconColor(for: colorScheme)
        case let .storm(level):
            return level.iconColor(for: colorScheme)
        case let .fire(level):
            return level.iconColor(for: colorScheme)
        case .loading:
            let top = colorScheme == .dark
                ? Color(red: 0.17, green: 0.22, blue: 0.30).opacity(0.92)
                : Color(red: 0.87, green: 0.91, blue: 0.96)
            let bottom = colorScheme == .dark
                ? Color(red: 0.10, green: 0.14, blue: 0.20).opacity(0.92)
                : Color(red: 0.82, green: 0.87, blue: 0.93)
            return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .quiet:
            return Color.riskAllClear.opacity(colorScheme == .dark ? 0.28 : 0.16)
                .tileGradient(for: colorScheme)
        }
    }

    var destination: SummaryAwarenessDestination {
        switch self {
        case .alert:
            .alerts
        case .severe(let threat):
            switch threat {
            case .allClear:
                .none
            case .wind:
                .map(.wind)
            case .hail:
                .map(.hail)
            case .tornado:
                .map(.tornado)
            }
        case .storm:
            .map(.categorical)
        case .fire:
            .map(.fire)
        case .loading, .quiet:
            .none
        }
    }

    var isQuiet: Bool {
        switch self {
        case .quiet:
            true
        case let .storm(level):
            level == .allClear
        case let .severe(threat):
            threat == .allClear
        case let .fire(level):
            level == .clear
        case .alert, .loading:
            false
        }
    }

    var accessibilityContract: SummaryAwarenessAccessibilityContract {
        SummaryAwarenessAccessibilityContract(
            label: accessibilityLabel,
            value: accessibilityValue,
            hint: destination.accessibilityHint
        )
    }

    private var accessibilityLabel: String {
        switch self {
        case .alert(let title, _):
            title
        case .severe:
            "Severe Risk"
        case .storm:
            "Storm Risk"
        case .fire:
            "Fire Risk"
        case .loading(let title, _, _):
            title
        case .quiet:
            "Quiet Weather"
        }
    }

    private var accessibilityValue: String {
        switch self {
        case let .alert(_, detail):
            detail
        case .severe, .storm, .fire:
            accessibilityCurrentValue(title: title, detail: detail)
        case let .loading(_, detail, _):
            detail
        case .quiet:
            "No active severe threats nearby"
        }
    }

    private func accessibilityCurrentValue(title: String, detail: String) -> String {
        detail.isEmpty ? title : "\(title). \(detail)"
    }
}

enum SummaryAwarenessSource: Equatable, Sendable {
    case alert
    case severeRisk
    case stormRisk
    case fireRisk
    case synthesizedQuietState
    case loading
}
