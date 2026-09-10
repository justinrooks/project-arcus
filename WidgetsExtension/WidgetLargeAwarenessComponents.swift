import SwiftUI
import WidgetKit

struct WidgetLargeAwarenessView: View {
    let snapshot: WidgetSnapshot

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if case let .unavailable(message) = snapshot.availability {
                WidgetUnavailableStateView(message: message)
                    .padding(16)
            } else {
                content
            }
        }
        .containerBackground(for: .widget) {
            atmosphericBackground
        }
        .accessibilityElement(children: .contain)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            metadata

            Text(awarenessHeading)
                .font(.title2.weight(.bold))
                .tracking(0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 14)

            // Reserved for the alert stack introduced in #530.
            Spacer(minLength: 0)

            // Reserved for the risk context footer introduced in #531.
            Color.clear
                .frame(height: 44)
        }
        .padding(16)
    }

    private var metadata: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label(locationSummaryLine, systemImage: "mappin")
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            WidgetFreshnessLineView(freshness: freshness)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private var atmosphericBackground: some View {
        ZStack {
            LinearGradient(
                colors: backgroundGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.30, green: 0.54, blue: 0.72).opacity(colorScheme == .dark ? 0.22 : 0.16),
                    .clear
                ],
                center: UnitPoint(x: 0.78, y: 0.12),
                startRadius: 12,
                endRadius: 260
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.16),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )

            LinearGradient(
                colors: [.clear, Color.black.opacity(colorScheme == .dark ? 0.20 : 0.04)],
                startPoint: .center,
                endPoint: .bottomTrailing
            )
        }
    }

    private var awarenessHeading: String {
        switch activeAlertCount {
        case 0:
            return "LOCAL AWARENESS"
        case 1:
            return "1 ACTIVE ALERT"
        default:
            return "\(activeAlertCount) ACTIVE ALERTS"
        }
    }

    private var activeAlertCount: Int {
        snapshot.activeAlerts.isEmpty ? (snapshot.selectedAlert == nil ? 0 : 1) : snapshot.activeAlerts.count
    }

    private var freshness: WidgetFreshnessState {
        snapshot.alertFreshness ?? snapshot.freshness
    }

    private var locationSummaryLine: String {
        let trimmed = snapshot.locationSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.flatMap { $0.isEmpty ? nil : $0 } ?? "Location unavailable"
    }

    private var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.055, green: 0.105, blue: 0.150),
                Color(red: 0.040, green: 0.075, blue: 0.120),
                Color(red: 0.025, green: 0.050, blue: 0.085)
            ]
        }

        return [
            Color(red: 0.835, green: 0.895, blue: 0.950),
            Color(red: 0.760, green: 0.835, blue: 0.910),
            Color(red: 0.685, green: 0.775, blue: 0.860)
        ]
    }
}
