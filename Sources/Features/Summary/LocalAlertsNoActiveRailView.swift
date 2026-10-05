//
//  LocalAlertsNoActiveRailView.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI

struct LocalAlertsNoActiveRailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No active alerts for your location")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("We'll continue watching nearby watches, warnings, and discussions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("summary-local-alerts-no-active-rail")
    }
}
