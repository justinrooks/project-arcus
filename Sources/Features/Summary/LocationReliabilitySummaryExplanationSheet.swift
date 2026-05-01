import SwiftUI

struct LocationReliabilitySummaryExplanationSheet: View {
    let reliability: LocationReliabilityState
    let onEnableAlways: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Label("More Reliable Alerts", systemImage: "bell.badge.waveform.fill")
                    .sectionLabel()

                Text("SkyAware can send more reliable severe-weather alerts when it can refresh your location in the background.")
                    .font(.body)
                    .foregroundStyle(.primary)

                Text("Background alerts work best when your location is always shared.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                statusRow

                Spacer(minLength: 8)

                Button(action: onEnableAlways) {
                    Text("Enable Always")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: SkyAwareRadius.chip)
                                .fill(Color.skyAwareAccent)
                        )
                }
                .accessibilityIdentifier("summary-reliability-enable-always")

                Button("Not Now", action: onNotNow)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("summary-reliability-sheet-not-now")
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.skyAwareBackground))
            .navigationTitle("Enable Always")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            statusPill(title: "Current", value: reliability.settingsAuthorizationText)
            statusPill(title: "Recommended", value: reliability.recommendedAuthorizationText)
        }
        .accessibilityIdentifier("summary-reliability-status-row")
    }

    private func statusPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .cardBackground(
            cornerRadius: SkyAwareRadius.chip,
            shadowOpacity: 0.05,
            shadowRadius: 4,
            shadowY: 2,
            allowsGlass: false
        )
    }
}

private extension LocationReliabilityState {
    var recommendedAuthorizationText: String {
        switch recommendedAuthorization {
        case .always:
            return "Always"
        case .whileUsing:
            return "While Using"
        case .denied:
            return "Off"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Set"
        }
    }
}

#Preview {
    LocationReliabilitySummaryExplanationSheet(
        reliability: .init(authorization: .whileUsing, accuracy: .precise),
        onEnableAlways: {},
        onNotNow: {}
    )
}
