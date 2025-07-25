//
//  StormRiskBadgeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/24/25.
//

import SwiftUI

struct StormRiskBadgeView: View {
    let level: StormRiskLevel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: level.iconName)
                .formatBadgeImage()
            Text(level.message)
                .formatMessageText()
            Text(level.summary)
                .formatSummaryText(for: colorScheme)
        }
        .badgeStyle(background: level.iconColor(for:colorScheme))
    }
}

#Preview {
    Group {
        HStack {
            StormRiskBadgeView(level: .allClear)
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
    }
}
