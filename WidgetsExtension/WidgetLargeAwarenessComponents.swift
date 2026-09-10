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

            WidgetLargeAlertRailStack(alerts: activeAlerts)
                .padding(.top, 12)

            Spacer(minLength: 8)

            WidgetLargeRiskContextFooter(
                stormState: snapshot.stormRisk,
                severeState: snapshot.severeRisk
            )
            .padding(.top, 8)
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
        activeAlerts.count
    }

    private var activeAlerts: [WidgetSelectedAlertRowDisplayState] {
        snapshot.activeAlerts.isEmpty ? [snapshot.selectedAlert].compactMap { $0 } : snapshot.activeAlerts
    }

    private var freshness: WidgetFreshnessState {
        guard let alertFreshness = snapshot.alertFreshness else {
            return snapshot.freshness
        }

        guard snapshot.freshness.state == .fresh else {
            return snapshot.freshness
        }

        guard alertFreshness.state == .fresh else {
            return alertFreshness
        }

        guard let riskTimestamp = snapshot.freshness.timestamp,
              let alertTimestamp = alertFreshness.timestamp
        else {
            return snapshot.freshness
        }

        return riskTimestamp <= alertTimestamp ? snapshot.freshness : alertFreshness
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

private struct WidgetLargeAlertRailStack: View {
    private static let visibleAlertCapacity = 3
    fileprivate static let rowMinimumHeight: CGFloat = 46
    private static let rowSpacing: CGFloat = 7

    let alerts: [WidgetSelectedAlertRowDisplayState]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var visibleAlerts: [WidgetLargeAlertRailItem] {
        alerts.prefix(visibleAlertCapacity).enumerated().map { index, alert in
            WidgetLargeAlertRailItem(position: index, alert: alert)
        }
    }

    private var overflowCount: Int {
        max(0, alerts.count - visibleAlerts.count)
    }

    var body: some View {
        Group {
            if alerts.isEmpty {
                WidgetLargeQuietAwarenessState()
            } else {
                VStack(alignment: .leading, spacing: Self.rowSpacing) {
                    ForEach(visibleAlerts) { item in
                        WidgetLargeAlertRailRow(alert: item.alert)
                    }

                    if overflowCount > 0 {
                        Text("+\(overflowCount) more active alerts")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.leading, 8)
                            .padding(.bottom, 8)
                            .accessibilityLabel("\(overflowCount) more active alerts")
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(minHeight: reservedStackHeight, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }

    private var reservedStackHeight: CGFloat {
        (Self.rowMinimumHeight * CGFloat(visibleAlertCapacity))
            + (Self.rowSpacing * CGFloat(visibleAlertCapacity - 1))
    }

    private var visibleAlertCapacity: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : Self.visibleAlertCapacity
    }
}

private struct WidgetLargeQuietAwarenessState: View {
    private let quietTint = Color(red: 0.40, green: 0.75, blue: 0.40)

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(quietTint)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)

            Text("No local alerts")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No local alerts")
    }
}

private struct WidgetLargeRiskContextFooter: View {
    let stormState: WidgetRiskDisplayState
    let severeState: WidgetRiskDisplayState

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            WidgetLargeRiskContextColumn(
                title: "Storm Risk",
                state: stormState,
                style: .style(for: .storm, severity: stormState.severity)
            )

            WidgetLargeRiskContextColumn(
                title: "Severe Risk",
                state: severeState,
                style: .style(for: .severe, severity: severeState.severity)
            )
        }
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
    }
}

private struct WidgetLargeRiskContextColumn: View {
    let title: String
    let state: WidgetRiskDisplayState
    let style: WidgetRiskVisualStyle

    private var accent: Color {
        state == .placeholder ? .secondary : style.tint
    }

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Capsule(style: .continuous)
                .fill(accent)
                .frame(width: 3, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(state.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(state.label)")
    }
}

private struct WidgetLargeAlertRailItem: Identifiable {
    let position: Int
    let alert: WidgetSelectedAlertRowDisplayState

    var id: Int { position }
}

private struct WidgetLargeAlertRailRow: View {
    let alert: WidgetSelectedAlertRowDisplayState

    private var style: WidgetAlertVisualStyle {
        WidgetAlertVisualStyle.style(for: alert)
    }

    private var lifecycleLine: String {
        guard let validEnd = alert.validEnd else {
            return alert.typeLabel
        }

        return "\(alert.typeLabel) · Ends \(validEnd.formatted(date: .omitted, time: .shortened))"
    }

    private var accessibilityLabel: String {
        "\(alert.title). \(lifecycleLine)."
    }

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Capsule(style: .continuous)
                .fill(style.tint)
                .frame(width: 3)
                .accessibilityHidden(true)

            Image(systemName: style.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(style.tint)
                .frame(width: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(lifecycleLine)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: WidgetLargeAlertRailStack.rowMinimumHeight)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.065))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}
