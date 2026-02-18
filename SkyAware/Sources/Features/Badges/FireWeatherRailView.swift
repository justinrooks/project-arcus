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
    var label: String {
        switch level {
        case .clear: return "No"
        default: return level.status
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: level.symbol)
                .formatBadgeImage()
            VStack(alignment: .leading, spacing: 3) {
                Text("\(label) Fire Risk")
                    .formatMessageText()
                Text(level.message)
                    .formatSummaryText(for: colorScheme)
            }

//            Spacer(minLength: 10)
//
//            Text(level.status)
//                .font(.caption.weight(.semibold))
//                .padding(.horizontal, 10)
//                .padding(.vertical, 6)
//                .skyAwareChip(cornerRadius: 12, tint: level.tint.opacity(0.20))
        }
        .railStyle(background: level.iconColor(for: colorScheme))
//        .badgeStyle(background: level.iconColor(for: colorScheme))
//        .padding(14)
//        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
//        .skyAwareSurface(
//            cornerRadius: 22,
//            tint: level.iconColor(for: colorScheme),//level.tint.opacity(0.12),
//            shadowOpacity: 0.06,
//            shadowRadius: 6,
//            shadowY: 2
//        )
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
