//
//  StormRiskBadgeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/24/25.
//

import SwiftUI

struct StormRiskBadgeView: View {
    let level: StormRiskLevel
    var isOffline: Bool = false
    var isResolving: Bool = false
    var showsResolvingPlaceholder: Bool = false

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Group {
            if isOffline {
                offlineContent
            } else if showsResolvingPlaceholder {
                resolvingContent
            } else {
                resolvedContent
            }
        }
    }

    private var resolvedContent: some View {
        VStack(spacing: 4) {
            Image(systemName: level.iconName)
                .formatBadgeImage()
                .contentTransition(.opacity)
            Text(level.message)
                .formatMessageText()
                .contentTransition(.opacity)
            Text(level.summary)
                .formatSummaryText(for: colorScheme)
                .contentTransition(.opacity)
        }
        .badgeStyle(background: level.iconColor(for: colorScheme))
        .animation(SkyAwareMotion.settle(reduceMotion), value: level.message)
        .animation(SkyAwareMotion.settle(reduceMotion), value: level.summary)
    }

    private var resolvingContent: some View {
        VStack(spacing: 4) {
            Image(systemName: "bolt.badge.clock")
                .formatBadgeImage()
                .opacity(0.92)
            Text("Storm Risk")
                .formatMessageText()
            Text(isResolving ? "Refining local risk…" : "Resolving local risk…")
                .formatSummaryText(for: colorScheme)
        }
        .badgeStyle(background: resolvingBackground)
        .transition(.opacity)
        .animation(SkyAwareMotion.settle(reduceMotion), value: isResolving)
    }

    private var resolvingBackground: LinearGradient {
        let top = colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.52)
        let bottom = colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.30)
        return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var offlineContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Offline", systemImage: "wifi.slash")
                .sectionLabel()
            Text("Storm risk is unavailable while the server is offline.")
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
            StormRiskBadgeView(level: .allClear)
            StormRiskBadgeView(level: .thunderstorm)
        }
        HStack {
            StormRiskBadgeView(level: .marginal)
        }
        HStack {
            StormRiskBadgeView(level: .slight)
            StormRiskBadgeView(level: .enhanced)
        }
        HStack {
            StormRiskBadgeView(level: .moderate)
            StormRiskBadgeView(level: .high)
                .preferredColorScheme(.dark)
        }
        HStack {
            StormRiskBadgeView(level: .allClear, isResolving: true, showsResolvingPlaceholder: true)
            StormRiskBadgeView(level: .moderate, isResolving: true)
        }
    }.background(.skyAwareBackground)
}
