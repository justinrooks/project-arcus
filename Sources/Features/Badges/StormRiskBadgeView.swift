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
            Image(systemName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
                .formatBadgeImage()
                .opacity(0.92)
            Text("Storm Risk")
                .formatMessageText()
            Text("Getting storm risk…")
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

    private var offlineContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Offline", systemImage: "wifi.slash")
                .sectionLabel()
            Text("SkyAware is showing saved local data. Storm risk will update when your connection returns.")
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
