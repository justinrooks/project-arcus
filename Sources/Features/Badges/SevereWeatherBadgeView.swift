//
//  SevereWeatherBadgeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/24/25.
//

import SwiftUI

struct SevereWeatherBadgeView: View {
    let threat: SevereWeatherThreat?
    var isOffline: Bool = false
    var isResolving: Bool = false
    var showsResolvingPlaceholder: Bool = false

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Group {
            switch presentationState {
            case .resolving:
                resolvingContent
            case .current, .stale:
                if let threat {
                    resolvedContent(threat: threat)
                } else {
                    unavailableContent
                }
            case .unavailable, .confirmedEmpty:
                unavailableContent
            }
        }
    }

    private var presentationState: SummaryContentPresentationState {
        SummaryContentPresentationState.from(
            isOffline: isOffline,
            hasContent: threat != nil,
            isResolving: showsResolvingPlaceholder
        )
    }

    @ViewBuilder
    private func resolvedContent(threat: SevereWeatherThreat) -> some View {
        VStack(spacing: 4) {
            Image(systemName: threat.iconName)
                .formatBadgeImage()
                .contentTransition(.opacity)
            Text(threat.message)
                .formatMessageText()
                .contentTransition(.opacity)
            Text(threat.dynamicSummary != "" ? threat.dynamicSummary : threat.summary)
                .formatSummaryText(for: colorScheme)
                .monospacedDigit()
                .contentTransition(.opacity)
        }
        .badgeStyle(background: threat.iconColor(for: colorScheme))
        .animation(SkyAwareMotion.settle(reduceMotion), value: threat.message)
        .animation(SkyAwareMotion.settle(reduceMotion), value: threat.dynamicSummary)
        .overlay(alignment: .topTrailing) {
            if isOffline {
                SummaryAvailabilityBadge(state: .stale)
                    .padding(8)
            }
        }
    }

    private var resolvingContent: some View {
        VStack(spacing: 4) {
            Image(systemName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
                .formatBadgeImage()
                .opacity(0.92)
            Text("Severe Risk")
                .formatMessageText()
            Text("Getting severe risk…")
                .formatSummaryText(for: colorScheme)
        }
        .badgeStyle(background: resolvingBackground)
        .transition(.opacity)
    }

    private var resolvingBackground: LinearGradient {
        let top = colorScheme == .dark
            ? Color(red: 0.17, green: 0.22, blue: 0.30).opacity(0.93)
            : Color(red: 0.87, green: 0.91, blue: 0.96)
        let bottom = colorScheme == .dark
            ? Color(red: 0.10, green: 0.14, blue: 0.20).opacity(0.93)
            : Color(red: 0.82, green: 0.87, blue: 0.93)
        return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unavailable", systemImage: "exclamationmark.circle")
                .sectionLabel()
            Text("No saved severe risk data is available offline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minWidth: 130, idealWidth: 145, maxWidth: 145,
               minHeight: 150, idealHeight: 150, maxHeight: 160)
        .padding()
        .cardBackground(cornerRadius: SkyAwareRadius.large, shadowOpacity: 0.18, shadowRadius: 8, shadowY: 4, allowsGlass: false)
    }
}

#Preview {
    VStack {
        HStack {
            SevereWeatherBadgeView(threat: .allClear)
            SevereWeatherBadgeView(threat: .wind(probability: 0.15))
        }
        HStack {
            SevereWeatherBadgeView(threat: .hail(probability: 0.02))
            SevereWeatherBadgeView(threat: .tornado(probability: 0.05))
                .preferredColorScheme(.dark)
        }
        HStack {
            SevereWeatherBadgeView(threat: .allClear, isResolving: true, showsResolvingPlaceholder: true)
            SevereWeatherBadgeView(threat: .wind(probability: 0.15), isResolving: true)
        }
        HStack {
            SevereWeatherBadgeView(threat: .tornado(probability: 0.05), isOffline: true)
            SevereWeatherBadgeView(threat: nil, isOffline: true)
        }
    }
    .background(.skyAwareBackground)
}
