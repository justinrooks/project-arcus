//
//  LocalAlertsNoActiveRailView.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI

struct LocalAlertsNoActiveRailView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var background: LinearGradient {
        let leadingOpacity = colorScheme == .dark ? 0.11 : 0.06
        let trailingOpacity = colorScheme == .dark ? 0.07 : 0.035

        return LinearGradient(
            colors: [
                Color.primary.opacity(leadingOpacity),
                Color.primary.opacity(trailingOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No active alerts for your location")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text("We'll continue watching nearby watches, warnings, and discussions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .railStyle(
            background: background,
            minHeight: 84,
            shadowOpacity: 0.10,
            shadowRadius: 6,
            shadowY: 3
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("summary-local-alerts-no-active-rail")
    }
}
