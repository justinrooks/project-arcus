//
//  SevereWeatherBadgeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/24/25.
//

import SwiftUI

struct SevereWeatherBadgeView: View {
    let threat: SevereWeatherThreat
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: threat.iconName)
                .formatBadgeImage()
            Text(threat.message)
                .formatMessageText()
            Text(threat.dynamicSummary != "" ? threat.dynamicSummary : threat.summary)
                .formatSummaryText(for: colorScheme)
        }
        .badgeStyle(background: threat.iconColor(for: colorScheme))
    }
}

#Preview {
    Group {
        HStack {
            SevereWeatherBadgeView(threat: .allClear)
            SevereWeatherBadgeView(threat: .wind(probability: 15))
        }
        HStack {
            SevereWeatherBadgeView(threat: .hail(probability: 2))
            SevereWeatherBadgeView(threat: .tornado(probability: 5))
                .preferredColorScheme(.dark)
        }
    }
}
