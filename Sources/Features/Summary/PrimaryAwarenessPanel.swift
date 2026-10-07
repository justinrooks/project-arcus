//
//  PrimaryAwarenessPanel.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import SwiftUI

struct PrimaryAwarenessPanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.severeIntensity) private var severeIntensity

    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let alerts: [AlertDTO]
    let todayContentState: TodayContentState
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
            todayContentState: todayContentState,
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

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    stormRow
                    severeRow
                }
                VStack(spacing: 10) {
                    stormRow
                    severeRow
                }
            }
            VStack(spacing: 10) {
                fireRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Label("Today's Awareness", systemImage: "checkmark.shield").symbolVariant(.fill)
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
            title: stormCardValue,
            detail: stormDetail,
            symbolName: stormSymbolName,
            background: stormBackground,
            category: "Storm Risk",
            accent: stormAccent,
            categorySymbolName: stormSymbolName,
            isQuiet: stormIsQuiet,
            presentationMode: stormIsQuiet ? .subdued : .normal,
            action: {
                onOpenMapLayer(.categorical)
            }
        )
        .summaryResolving(stormResolving, todayContentState: todayContentState, style: .subtle)
        .accessibilityHint("Opens the storm risk map.")
    }

    private var severeRow: some View {
        riskRow(
            title: severeCardValue,
            detail: severeDetail,
            symbolName: severeSymbolName,
            background: severeBackground,
            category: "Severe Risk",
            accent: severeAccent,
            isQuiet: severeIsQuiet,
            intensity: severeIntensity?.displayed(for: severeRisk, contentState: todayContentState),
            presentationMode: severeIsQuiet ? .subdued : .normal,
            action: {
                onOpenMapLayer(severeMapLayer)
            }
        )
        .summaryResolving(severeResolving, todayContentState: todayContentState, style: .subtle)
        .accessibilityHint("Opens the highlighted severe threat map.")
    }

    private var fireRow: some View {
        riskRow(
            title: fireValue,
            detail: fireDetail,
            symbolName: fireSymbolName,
            background: neutralSupportBackground,
            category: "Fire Risk",
            accent: fireAccent,
            categorySymbolName: fireSymbolName,
            isQuiet: fireIsQuiet,
            presentationMode: fireIsQuiet ? .subdued : .normal,
            action: {
                onOpenMapLayer(.fire)
            }
        )
        .summaryResolving(fireResolving, todayContentState: todayContentState, style: .subtle)
        .accessibilityHint("Opens the fire risk map.")
    }

    @ViewBuilder
    private func riskRow(
        title: String,
        detail: String,
        symbolName: String,
        background: LinearGradient,
        category: String? = nil,
        accent: Color? = nil,
        categorySymbolName: String? = nil,
        isQuiet: Bool,
        intensity: SevereIntensityPresentation? = nil,
        presentationMode: SupportingRiskRowPresentationMode = .normal,
        action: @escaping () -> Void,
        showsChevron: Bool = false
    ) -> some View {
        Button(action: action) {
            AwarenessSupportRow(
                title: title,
                detail: detail,
                symbolName: symbolName,
                background: background,
                category: category,
                accent: accent,
                categorySymbolName: categorySymbolName,
                intensity: intensity,
                isQuiet: isQuiet,
                presentationMode: presentationMode,
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
            todayContentState: todayContentState,
            showsOfflineToken: showsOfflineToken
        )
    }

    private var severeResolving: Bool {
        SummaryView.showsRiskResolvingPlaceholder(
            hasRiskValue: severeRisk != nil,
            todayContentState: todayContentState,
            showsOfflineToken: showsOfflineToken
        )
    }

    private var fireResolving: Bool {
        SummaryView.showsRiskResolvingPlaceholder(
            hasRiskValue: fireRisk != nil,
            todayContentState: todayContentState,
            showsOfflineToken: showsOfflineToken
        )
    }

    private var stormCardValue: String {
        if stormUnavailable { return "Unavailable" }
        if stormRisk == nil, stormResolving { return "Getting risk…" }
        return (stormRisk ?? .allClear).message
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

    private var stormAccent: Color {
        guard !stormUnavailable, let stormRisk else { return .secondary }
        return switch stormRisk {
        case .allClear: Color.riskAllClear
        case .thunderstorm: Color.riskThunderstorm
        case .marginal: Color.riskMarginal
        case .slight: Color.riskSlight
        case .enhanced: Color.riskEnhanced
        case .moderate: Color.riskModerate
        case .high: Color.riskHigh
        }
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

    private var severeCardValue: String {
        if severeUnavailable { return "Unavailable" }
        if severeRisk == nil, severeResolving { return "Getting risk…" }
        return (severeRisk ?? .allClear).message
    }

    private var severeDetail: String {
        if primaryState.source == .severeRisk,
           severeIntensity?.displayed(for: severeRisk, contentState: todayContentState) != nil {
            return severeRisk?.dynamicSummary ?? ""
        }
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

    private var severeAccent: Color {
        guard !severeUnavailable, let severeRisk else { return .secondary }
        return switch severeRisk {
        case .allClear: Color.riskAllClear
        case .wind: Color.windTeal
        case .hail: Color.hailBlue
        case .tornado: Color.tornadoRed
        }
    }

    private var fireValue: String {
        if fireUnavailable { return "Unavailable" }
        if fireRisk == nil, fireResolving { return "Getting risk…" }
        guard let fireRisk else { return "Unavailable" }
        return fireRisk == .clear ? "None" : fireRisk.status
    }

    private var fireSymbolName: String {
        if fireUnavailable { return "exclamationmark.circle" }
        if fireRisk == nil, fireResolving {
            return "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
        }
        return fireRisk?.symbol ?? "checkmark.seal.fill"
    }

    private var fireDetail: String {
        if fireUnavailable {
            return showsOfflineToken
                ? "No saved fire risk data is available offline."
                : "Fire risk data is unavailable."
        }

        if fireRisk == nil, fireResolving {
            return "Getting fire risk…"
        }

        if fireRisk != nil {
            return firePresentation.detail
        }

        return "No elevated fire weather risk"
    }

    private var fireIsQuiet: Bool {
        !fireUnavailable && !fireResolving && fireRisk == .clear
    }

    private var fireAccent: Color {
        guard !fireUnavailable, let fireRisk else { return .secondary }
        return fireRisk == .clear ? .riskAllClear : fireRisk.tint
    }

    private var firePresentation: SupportingRiskRowDisplayModel {
        guard let fireRisk else {
            return SupportingRiskRowDisplayModel(
                title: "No Fire Risk",
                detail: "No elevated fire weather risk",
                presentationMode: .subdued
            )
        }

        return SupportingRiskRowDisplayModel.fire(
            level: fireRisk,
            primarySource: primaryState.source
        )
    }

    private var stormUnavailable: Bool {
        showsOfflineToken && stormRisk == nil && stormResolving == false
    }

    private var severeUnavailable: Bool {
        showsOfflineToken && severeRisk == nil && severeResolving == false
    }

    private var fireUnavailable: Bool {
        fireRisk == nil && fireResolving == false
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
