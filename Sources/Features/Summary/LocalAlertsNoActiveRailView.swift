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

                Text("SkyAware will continue monitoring for nearby watches, warnings, and mesoscale discussions.")
                    .font(.caption)
                    .todaySupportingText()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .todayCardBackground(cornerRadius: SkyAwareRadius.card)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("summary-local-alerts-no-active-rail")
    }
}
