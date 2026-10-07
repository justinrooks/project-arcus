//
//  LocalAlertsNoActiveRailView.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI

struct LocalAlertsNoActiveRailView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("No active alerts for your location")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("SkyAware will continue watching nearby watches, warnings, and discussions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardBackground(
            cornerRadius: SkyAwareRadius.card,
            shadowOpacity: 0.04,
            shadowRadius: 4,
            shadowY: 1
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("summary-local-alerts-no-active-rail")
    }
}
