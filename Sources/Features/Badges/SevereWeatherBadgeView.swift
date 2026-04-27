//
//  SevereWeatherBadgeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/24/25.
//

import SwiftUI

struct SevereWeatherBadgeView: View {
    let threat: SevereWeatherThreat
    var isOffline: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if isOffline {
                offlineContent
            } else {
                VStack(spacing: 4) {
                    Image(systemName: threat.iconName)
                        .formatBadgeImage()
                    Text(threat.message)
                        .formatMessageText()
                    Text(threat.dynamicSummary != "" ? threat.dynamicSummary : threat.summary)
                        .formatSummaryText(for: colorScheme)
                        .monospacedDigit()
                }
                .badgeStyle(background: threat.iconColor(for: colorScheme))
            }
        }
    }

    private var offlineContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Offline", systemImage: "wifi.slash")
                .sectionLabel()
            Text("Severe threat details are unavailable while the server is offline.")
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
    }
    .background(.skyAwareBackground)
}
