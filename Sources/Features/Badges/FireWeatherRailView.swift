//
//  FireWeatherRailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 2/17/26.
//

import SwiftUI

struct FireWeatherRailView: View {
    @Environment(\.colorScheme) var colorScheme
    let level: FireRiskLevel
    var isOffline: Bool = false
    var label: String {
        switch level {
        case .clear: return "No"
        default: return level.status
        }
    }

    var body: some View {
        Group {
            if isOffline {
                offlineContent
            } else {
                HStack(spacing: 12) {
                    Image(systemName: level.symbol)
                        .formatBadgeImage()
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(label) Fire Risk")
                            .formatMessageText()
                        Text(level.message)
                            .formatSummaryText(for: colorScheme)
                    }
                }
                .railStyle(background: level.iconColor(for: colorScheme))
            }
        }
    }

    private var offlineContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Offline", systemImage: "wifi.slash")
                .sectionLabel()
            Text("Fire risk is unavailable while the server is offline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding([.leading, .trailing], 15)
        .cardBackground(cornerRadius: SkyAwareRadius.large, shadowOpacity: 0.18, shadowRadius: 8, shadowY: 4, allowsGlass: false)
    }
}

#Preview {
    VStack {
        FireWeatherRailView(level: .clear)
        FireWeatherRailView(level: .elevated)
        FireWeatherRailView(level: .critical)
        FireWeatherRailView(level: .extreme)
    }
}

//    private var fireRiskState: FireRiskLevel {
//        let watchTitles = watches.map { $0.title.localizedLowercase }
//
//        if watchTitles.contains(where: { $0.contains("red flag warning") || $0.contains("extreme fire") }) {
//            return .critical
//        }
//
//        if watchTitles.contains(where: { $0.contains("fire weather watch") || $0.contains("red flag") }) {
//            return .elevated
//        }
//
//        return .clear
//    }
