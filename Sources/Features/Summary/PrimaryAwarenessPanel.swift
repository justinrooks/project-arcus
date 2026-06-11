//
//  PrimaryAwarenessPanel.swift
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

        if isOffline == false {
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

        let detail = alert.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = alert.areaSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            title: alert.title,
            detail: detail.isEmpty ? fallback : detail
        )
    }

    private static func isWarningOrWatch(title: String) -> Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        return normalized.contains("warning") || normalized.contains("watch")
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
}

enum SummaryAwarenessSource: Equatable, Sendable {
    case alert
    case severeRisk
    case stormRisk
    case fireRisk
    case synthesizedQuietState
    case loading
}

enum SupportingRiskRowPresentationMode: Equatable, Sendable {
    case normal
    case supplemental
}

struct SupportingRiskRowDisplayModel: Equatable, Sendable {
    let title: String
    let detail: String
    let presentationMode: SupportingRiskRowPresentationMode

    static func severe(
        threat: SevereWeatherThreat,
        primarySource: SummaryAwarenessSource
    ) -> SupportingRiskRowDisplayModel {
        if primarySource == .severeRisk {
            return SupportingRiskRowDisplayModel(
                title: "Severe Risk",
                detail: supplementalSevereDetail(for: threat),
                presentationMode: .supplemental
            )
        }

        return SupportingRiskRowDisplayModel(
            title: threat.message,
            detail: threat.dynamicSummary.isEmpty ? threat.summary : threat.dynamicSummary,
            presentationMode: .normal
        )
    }

    static func storm(
        level: StormRiskLevel,
        primarySource: SummaryAwarenessSource
    ) -> SupportingRiskRowDisplayModel {
        if primarySource == .stormRisk {
            return SupportingRiskRowDisplayModel(
                title: "Storm Risk",
                detail: supplementalStormDetail(for: level),
                presentationMode: .supplemental
            )
        }

        return SupportingRiskRowDisplayModel(
            title: level.message,
            detail: level.summary,
            presentationMode: .normal
        )
    }

    static func fire(
        level: FireRiskLevel,
        primarySource: SummaryAwarenessSource
    ) -> SupportingRiskRowDisplayModel {
        if primarySource == .fireRisk {
            return SupportingRiskRowDisplayModel(
                title: "Fire Risk",
                detail: supplementalFireDetail(for: level),
                presentationMode: .supplemental
            )
        }

        return SupportingRiskRowDisplayModel(
            title: level.status == "Clear" ? "No Fire Risk" : "\(level.status) Fire Risk",
            detail: level.message,
            presentationMode: .normal
        )
    }

    private static func supplementalSevereDetail(for threat: SevereWeatherThreat) -> String {
        switch threat {
        case .allClear:
            return "No active severe threat"
        case .wind:
            return "Wind is the main severe signal"
        case .hail:
            return "Hail is the main severe signal"
        case .tornado:
            return "Tornado is the main severe signal"
        }
    }

    private static func supplementalStormDetail(for level: StormRiskLevel) -> String {
        switch level {
        case .allClear:
            return "No severe storms expected"
        case .thunderstorm:
            return "Thunderstorms possible"
        case .marginal:
            return "Low-end severe setup"
        case .slight:
            return "Elevated storm environment"
        case .enhanced:
            return "Severe storms possible today"
        case .moderate, .high:
            return "Primary outlook signal"
        }
    }

    private static func supplementalFireDetail(for level: FireRiskLevel) -> String {
        switch level {
        case .clear:
            return "No elevated fire weather risk"
        case .elevated:
            return "Wind and dry air are the drivers"
        case .critical:
            return "Rapid spread potential remains elevated"
        case .extreme:
            return "Very dry, windy conditions support fast spread"
        }
    }
}

struct PrimaryAwarenessPanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let alerts: [AlertDTO]
    let readinessState: SummaryReadinessState
    let resolutionState: SummaryResolutionState
    let showsOfflineToken: Bool
    let onOpenMapLayer: (MapLayer) -> Void
    let onOpenAlerts: () -> Void

    private var primaryState: SummaryAwarenessPrimaryState {
        SummaryAwarenessPrimaryState.resolve(
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            fireRisk: fireRisk,
            alerts: alerts,
            isStormRiskResolving: resolutionState.isResolving(.stormRisk),
            isSevereRiskResolving: resolutionState.isResolving(.severeRisk),
            isFireRiskResolving: resolutionState.isResolving(.fireRisk),
            isOffline: showsOfflineToken
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            PrimaryAwarenessHeroView(
                primary: primaryState,
                action: primaryState.destination,
                onOpenMapLayer: onOpenMapLayer,
                onOpenAlerts: onOpenAlerts
            )

            VStack(spacing: 10) {
                stormRow
                severeRow
                fireRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Label("Today's Awareness", systemImage: "checkmark.shield")
                .sectionLabel()

            Spacer(minLength: 12)

            if showsOfflineToken {
                SummaryAvailabilityBadge(state: .stale)
            }
        }
        .animation(SkyAwareMotion.message(reduceMotion), value: showsOfflineToken)
    }

    private var stormRow: some View {
        riskRow(
            title: stormTitle,
            detail: stormDetail,
            symbolName: stormSymbolName,
            background: stormBackground,
            isQuiet: stormIsQuiet,
            action: {
                onOpenMapLayer(.categorical)
            }
        )
        .summaryResolving(stormResolving, style: .subtle)
        .accessibilityHint("Opens the storm risk map.")
    }

    private var severeRow: some View {
        riskRow(
            title: severeTitle,
            detail: severeDetail,
            symbolName: severeSymbolName,
            background: severeBackground,
            isQuiet: severeIsQuiet,
            action: {
                onOpenMapLayer(severeMapLayer)
            }
        )
        .summaryResolving(severeResolving, style: .subtle)
        .accessibilityHint("Opens the highlighted severe threat map.")
    }

    private var fireRow: some View {
        riskRow(
            title: fireTitle,
            detail: fireDetail,
            symbolName: fireSymbolName,
            background: fireBackground,
            isQuiet: fireIsQuiet,
            action: {
                onOpenMapLayer(.fire)
            },
            showsChevron: true
        )
        .summaryResolving(fireResolving, style: .subtle)
        .accessibilityHint("Opens the fire risk map.")
    }

    @ViewBuilder
    private func riskRow(
        title: String,
        detail: String,
        symbolName: String,
        background: LinearGradient,
        isQuiet: Bool,
        action: @escaping () -> Void,
        showsChevron: Bool = false
    ) -> some View {
        Button(action: action) {
            AwarenessSupportRow(
                title: title,
                detail: detail,
                symbolName: symbolName,
                background: background,
                isQuiet: isQuiet,
                showsChevron: showsChevron
            )
        }
        .buttonStyle(
            SkyAwarePressableButtonStyle(
                cornerRadius: SkyAwareRadius.large,
                pressedScale: 0.992,
                pressedOverlayOpacity: 0.06
            )
        )
    }

    private var stormResolving: Bool {
        SummaryView.showsRiskResolvingPlaceholder(
            hasRiskValue: stormRisk != nil,
            readinessState: readinessState,
            isSectionResolving: resolutionState.isResolving(.stormRisk),
            showsOfflineToken: showsOfflineToken
        )
    }

    private var severeResolving: Bool {
        SummaryView.showsRiskResolvingPlaceholder(
            hasRiskValue: severeRisk != nil,
            readinessState: readinessState,
            isSectionResolving: resolutionState.isResolving(.severeRisk),
            showsOfflineToken: showsOfflineToken
        )
    }

    private var fireResolving: Bool {
        SummaryView.showsRiskResolvingPlaceholder(
            hasRiskValue: fireRisk != nil,
            readinessState: readinessState,
            isSectionResolving: resolutionState.isResolving(.fireRisk),
            showsOfflineToken: showsOfflineToken
        )
    }

    private var stormTitle: String {
        if stormUnavailable {
            return "Unavailable"
        }

        if stormRisk == nil, stormResolving {
            return "Storm Risk"
        }

        guard let stormRisk else {
            return "Storm Risk"
        }

        return SupportingRiskRowDisplayModel.storm(
            level: stormRisk,
            primarySource: primaryState.source
        ).title
    }

    private var stormDetail: String {
        if stormUnavailable {
            return "No saved storm risk data is available offline."
        }

        if stormRisk == nil, stormResolving {
            return "Getting storm risk…"
        }

        if let stormRisk {
            return SupportingRiskRowDisplayModel.storm(
                level: stormRisk,
                primarySource: primaryState.source
            ).detail
        }

        return "No severe storms expected"
    }

    private var stormSymbolName: String {
        if stormUnavailable {
            return "exclamationmark.circle"
        }

        if stormRisk == nil, stormResolving {
            return "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
        }

        return stormRisk?.iconName ?? "checkmark.seal.fill"
    }

    private var stormIsQuiet: Bool {
        stormUnavailable ? true : (stormRisk == nil ? stormResolving == false : stormRisk == .allClear)
    }

    private var stormBackground: LinearGradient {
        if stormUnavailable {
            return neutralSupportBackground
        }

        return stormRisk?.iconColor(for: colorScheme) ?? Color.riskAllClear.tileGradient(for: colorScheme)
    }

    private var severeMapLayer: MapLayer {
        switch severeRisk ?? .allClear {
        case .allClear:
            .categorical
        case .wind:
            .wind
        case .hail:
            .hail
        case .tornado:
            .tornado
        }
    }

    private var severeTitle: String {
        if severeUnavailable {
            return "Unavailable"
        }

        if severeRisk == nil, severeResolving {
            return "Severe Risk"
        }

        guard let severeRisk else {
            return "Severe Risk"
        }

        return SupportingRiskRowDisplayModel.severe(
            threat: severeRisk,
            primarySource: primaryState.source
        ).title
    }

    private var severeDetail: String {
        if severeUnavailable {
            return "No saved severe risk data is available offline."
        }

        if severeRisk == nil, severeResolving {
            return "Getting severe risk…"
        }

        if let severeRisk {
            return SupportingRiskRowDisplayModel.severe(
                threat: severeRisk,
                primarySource: primaryState.source
            ).detail
        }

        return "No active severe threats"
    }

    private var severeSymbolName: String {
        if severeUnavailable {
            return "exclamationmark.circle"
        }

        if severeRisk == nil, severeResolving {
            return "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
        }

        return severeRisk?.iconName ?? "checkmark.seal.fill"
    }

    private var severeIsQuiet: Bool {
        severeUnavailable ? true : (severeRisk == nil ? severeResolving == false : severeRisk == .allClear)
    }

    private var severeBackground: LinearGradient {
        if severeUnavailable {
            return neutralSupportBackground
        }

        return severeRisk?.iconColor(for: colorScheme) ?? Color.riskAllClear.tileGradient(for: colorScheme)
    }

    private var fireTitle: String {
        if fireUnavailable {
            return "Unavailable"
        }

        if fireRisk == nil, fireResolving {
            return "Fire Risk"
        }

        guard let fireRisk else {
            return "No Fire Risk"
        }

        return SupportingRiskRowDisplayModel.fire(
            level: fireRisk,
            primarySource: primaryState.source
        ).title
    }

    private var fireDetail: String {
        if fireUnavailable {
            return "No saved fire risk data is available offline."
        }

        if fireRisk == nil, fireResolving {
            return "Getting fire risk…"
        }

        if let fireRisk {
            return SupportingRiskRowDisplayModel.fire(
                level: fireRisk,
                primarySource: primaryState.source
            ).detail
        }

        return "No elevated fire weather risk"
    }

    private var fireSymbolName: String {
        if fireUnavailable {
            return "exclamationmark.circle"
        }

        if fireRisk == nil, fireResolving {
            return "flame"
        }

        return fireRisk?.symbol ?? "checkmark.seal.fill"
    }

    private var fireIsQuiet: Bool {
        fireUnavailable ? true : (fireRisk == nil ? fireResolving == false : fireRisk == .clear)
    }

    private var fireBackground: LinearGradient {
        if fireUnavailable {
            return neutralSupportBackground
        }

        return fireRisk?.iconColor(for: colorScheme) ?? Color.riskAllClear.tileGradient(for: colorScheme)
    }

    private var stormUnavailable: Bool {
        showsOfflineToken && stormRisk == nil && stormResolving == false
    }

    private var severeUnavailable: Bool {
        showsOfflineToken && severeRisk == nil && severeResolving == false
    }

    private var fireUnavailable: Bool {
        showsOfflineToken && fireRisk == nil && fireResolving == false
    }

    private var neutralSupportBackground: LinearGradient {
        let top = colorScheme == .dark
            ? Color(red: 0.16, green: 0.20, blue: 0.27).opacity(0.88)
            : Color(red: 0.86, green: 0.90, blue: 0.95)
        let bottom = colorScheme == .dark
            ? Color(red: 0.10, green: 0.13, blue: 0.18).opacity(0.88)
            : Color(red: 0.81, green: 0.86, blue: 0.92)
        return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct PrimaryAwarenessHeroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let primary: SummaryAwarenessPrimaryState
    let action: SummaryAwarenessDestination
    let onOpenMapLayer: (MapLayer) -> Void
    let onOpenAlerts: () -> Void

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        if action == .none {
            heroContent
        } else {
            Button {
                handle(action: action)
            } label: {
                heroContent
                    .contentShape(RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous))
            }
            .buttonStyle(
                SkyAwarePressableButtonStyle(
                    cornerRadius: SkyAwareRadius.large,
                    pressedScale: 0.992,
                    pressedOverlayOpacity: 0.06
                )
            )
            .accessibilityHint(accessibilityHint(for: action))
        }
    }

    private var heroContent: some View {
        let iconSize: CGFloat = adaptiveLayout.usesStackedHeroTiles ? 34 : 42
        let titleFont: Font = adaptiveLayout.usesStackedHeroTiles ? .title3.weight(.semibold) : .title2.weight(.semibold)
        let detailFont: Font = adaptiveLayout.usesStackedHeroTiles ? .subheadline : .headline

        return VStack(alignment: .leading, spacing: adaptiveLayout.usesStackedHeroTiles ? 10 : 12) {
            if adaptiveLayout.usesStackedHeroTiles {
                Image(systemName: primary.symbolName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(RiskBadgeVisualStyle.iconForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: primary.symbolName)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(RiskBadgeVisualStyle.iconForeground)
                        .frame(width: 52, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(primary.title)
                            .font(titleFont)
                            .foregroundColor(RiskBadgeVisualStyle.messageForeground)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(primary.detail)
                            .font(detailFont)
                            .foregroundStyle(RiskBadgeVisualStyle.summaryForeground(for: colorScheme))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }

            if adaptiveLayout.usesStackedHeroTiles {
                VStack(alignment: .leading, spacing: 4) {
                    Text(primary.title)
                        .font(titleFont)
                        .foregroundColor(RiskBadgeVisualStyle.messageForeground)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(primary.detail)
                        .font(detailFont)
                        .foregroundStyle(RiskBadgeVisualStyle.summaryForeground(for: colorScheme))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                .fill(primary.background(for: colorScheme))
        )
        .overlay {
            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                .strokeBorder(.white.opacity(primary.isQuiet ? 0.10 : 0.16), lineWidth: 0.8)
                .allowsHitTesting(false)
        }
        .shadow(
            color: .black.opacity(primary.isQuiet ? 0.08 : 0.16),
            radius: primary.isQuiet ? 5 : 8,
            x: 0,
            y: primary.isQuiet ? 2 : 4
        )
        .animation(SkyAwareMotion.settle(reduceMotion), value: primary.title)
        .animation(SkyAwareMotion.settle(reduceMotion), value: primary.detail)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(primary.title)
        .accessibilityValue(primary.detail)
    }

    private func handle(action: SummaryAwarenessDestination) {
        switch action {
        case .alerts:
            onOpenAlerts()
        case .map(let layer):
            onOpenMapLayer(layer)
        case .none:
            break
        }
    }

    private func accessibilityHint(for action: SummaryAwarenessDestination) -> String {
        switch action {
        case .alerts:
            "Opens the alert center."
        case .map(let layer):
            "Opens the \(layer.title.lowercased()) map."
        case .none:
            ""
        }
    }
}

private struct AwarenessSupportRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let detail: String
    let symbolName: String
    let background: LinearGradient
    var isQuiet: Bool = false
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.title3.weight(.semibold))
                .foregroundColor(RiskBadgeVisualStyle.iconForeground)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(RiskBadgeVisualStyle.messageForeground)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(RiskBadgeVisualStyle.summaryForeground(for: colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                .fill(background)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                .strokeBorder(.white.opacity(isQuiet ? 0.08 : 0.12), lineWidth: 0.8)
                .allowsHitTesting(false)
        }
        .shadow(
            color: .black.opacity(isQuiet ? 0.06 : 0.10),
            radius: 5,
            x: 0,
            y: 2
        )
        .opacity(isQuiet ? 0.96 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
    }
}

#Preview("Primary Awareness Panel") {
    ScrollView {
        VStack(spacing: 18) {
            PrimaryAwarenessPanelPreviewCard(
                title: "Thunderstorms Light",
                stormRisk: .thunderstorm,
                severeRisk: .allClear,
                fireRisk: .clear
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Thunderstorms Dark",
                stormRisk: .thunderstorm,
                severeRisk: .allClear,
                fireRisk: .clear,
                colorScheme: .dark
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Tornado Light",
                stormRisk: .slight,
                severeRisk: .tornado(probability: 0.10),
                fireRisk: .clear
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Tornado Dark",
                stormRisk: .slight,
                severeRisk: .tornado(probability: 0.10),
                fireRisk: .clear,
                colorScheme: .dark
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Moderate Storm Light",
                stormRisk: .moderate,
                severeRisk: .allClear,
                fireRisk: .clear
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "High Storm Dark",
                stormRisk: .high,
                severeRisk: .allClear,
                fireRisk: .clear,
                colorScheme: .dark
            )
        }
        .padding()
    }
    .background(.skyAwareBackground)
}

private struct PrimaryAwarenessPanelPreviewCard: View {
    let title: String
    let stormRisk: StormRiskLevel
    let severeRisk: SevereWeatherThreat
    let fireRisk: FireRiskLevel
    var colorScheme: ColorScheme? = nil

    private var resolutionState: SummaryResolutionState { SummaryResolutionState() }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            PrimaryAwarenessPanel(
                stormRisk: stormRisk,
                severeRisk: severeRisk,
                fireRisk: fireRisk,
                alerts: [],
                readinessState: .ready,
                resolutionState: resolutionState,
                showsOfflineToken: false,
                onOpenMapLayer: { _ in },
                onOpenAlerts: { }
            )
        }
        .preferredColorScheme(colorScheme)
    }
}
