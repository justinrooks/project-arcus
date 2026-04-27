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
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if isOffline {
                offlineContent
            } else {
                VStack(spacing: 4) {
                    Image(systemName: level.iconName)
                        .formatBadgeImage()
                    Text(level.message)
                        .formatMessageText()
                    Text(level.summary)
                        .formatSummaryText(for: colorScheme)
                }
                .badgeStyle(background: level.iconColor(for: colorScheme))
            }
        }
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
    }.background(.skyAwareBackground)
}
