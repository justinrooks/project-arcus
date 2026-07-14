//
//  PrimaryAwarenessPanel.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import SwiftUI

#Preview("Primary Awareness Panel") {
    ScrollView {
        VStack(spacing: 18) {
            PrimaryAwarenessPanelPreviewCard(
                title: "Watch Primary - Light",
                stormRisk: .allClear,
                severeRisk: .allClear,
                fireRisk: .clear,
                alerts: [AlertDTO(from: Watch.sampleWatches[0])],
                colorScheme: .light
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Watch Primary - Dark",
                stormRisk: .allClear,
                severeRisk: .allClear,
                fireRisk: .clear,
                alerts: [AlertDTO(from: Watch.sampleWatches[1])],
                colorScheme: .dark
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Tornado Primary - Light",
                stormRisk: .slight,
                severeRisk: .tornado(probability: 0.10),
                fireRisk: .clear,
                colorScheme: .light
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Tornado Primary - Dark",
                stormRisk: .slight,
                severeRisk: .tornado(probability: 0.10),
                fireRisk: .clear,
                colorScheme: .dark
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Cached Refreshing Risk",
                stormRisk: .moderate,
                severeRisk: .allClear,
                fireRisk: .clear,
                todayContentState: .cachedRefreshing,
                colorScheme: .light
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Quiet Weather - Light",
                stormRisk: .allClear,
                severeRisk: .allClear,
                fireRisk: .clear,
                alerts: [],
                colorScheme: .light
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Quiet Weather - Dark",
                stormRisk: .allClear,
                severeRisk: .allClear,
                fireRisk: .clear,
                alerts: [],
                colorScheme: .dark
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Large Dynamic Type",
                stormRisk: .allClear,
                severeRisk: .allClear,
                fireRisk: .clear,
                alerts: [AlertDTO(from: Watch.sampleWatches[0])],
                colorScheme: .light,
                dynamicTypeSize: .accessibility3
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Supporting Rows Light",
                stormRisk: .thunderstorm,
                severeRisk: .tornado(probability: 0.10),
                fireRisk: .clear,
                colorScheme: .light
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Supporting Rows Dark",
                stormRisk: .thunderstorm,
                severeRisk: .tornado(probability: 0.10),
                fireRisk: .clear,
                colorScheme: .dark
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "No Fire Risk - Light",
                stormRisk: .allClear,
                severeRisk: .allClear,
                fireRisk: .clear,
                colorScheme: .light
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "No Fire Risk - Dark",
                stormRisk: .allClear,
                severeRisk: .allClear,
                fireRisk: .clear,
                colorScheme: .dark
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Elevated Fire - Light",
                stormRisk: .moderate,
                severeRisk: .allClear,
                fireRisk: .elevated,
                colorScheme: .light
            )

            PrimaryAwarenessPanelPreviewCard(
                title: "Elevated Fire - Dark",
                stormRisk: .moderate,
                severeRisk: .allClear,
                fireRisk: .critical,
                colorScheme: .dark
            )
            
            PrimaryAwarenessPanelPreviewCard(
                title: "Extreme Fire - Dark",
                stormRisk: .allClear,
                severeRisk: .allClear,
                fireRisk: .extreme,
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
    var alerts: [AlertDTO] = []
    var todayContentState: TodayContentState = .current
    var colorScheme: ColorScheme? = nil
    var dynamicTypeSize: DynamicTypeSize? = nil

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
                alerts: alerts,
                todayContentState: todayContentState,
                resolutionState: resolutionState,
                showsOfflineToken: false,
                onOpenMapLayer: { _ in },
                onOpenAlerts: { }
            )
        }
        .preferredColorScheme(colorScheme)
        .dynamicTypeSize(dynamicTypeSize ?? .large)
    }
}
