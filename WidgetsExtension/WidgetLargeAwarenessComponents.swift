import SwiftUI
import WidgetKit

struct WidgetLargeAwarenessView: View {
    let snapshot: WidgetSnapshot

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.7)
                .padding(.top, 12)

            WidgetLargeAlertRailStack(alerts: activeAlerts)
                .padding(.top, 10)

            Spacer(minLength: 8)

            WidgetLargeRiskContextFooter(
                stormState: snapshot.stormRisk,
                severeState: snapshot.severeRisk
            )
            .padding(.top, 10)
        }
        .padding(16)
    }

    private var metadata: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 3) {
                    locationLabel
                    freshnessLabel
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    locationLabel

                    Spacer(minLength: 8)

                    freshnessLabel
                }
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private var locationLabel: some View {
        Label(locationSummaryLine, systemImage: "mappin")
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.8)
    }

    private var freshnessLabel: some View {
        WidgetFreshnessLineView(freshness: freshness)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.8)
    }

    private var atmosphericBackground: some View {
        ZStack {
            LinearGradient(
                colors: backgroundGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let primaryAlertTint {
                LinearGradient(
                    colors: [
                        primaryAlertTint.opacity(alertSurfaceEmphasis),
                        primaryAlertTint.opacity(0)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .center
                )
            }

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

    private var primaryAlertTint: Color? {
        activeAlerts.first.map { WidgetAlertVisualStyle.style(for: $0).tint }
    }

    private var alertSurfaceEmphasis: Double {
        guard let primaryAlert = activeAlerts.first else { return 0 }

        if primaryAlert.typeLabel.localizedLowercase == "warning" {
            switch primaryAlert.severity {
            case 5...:
                return colorScheme == .dark ? 0.15 : 0.065
            case 3...4:
                return colorScheme == .dark ? 0.12 : 0.050
            default:
                return colorScheme == .dark ? 0.10 : 0.040
            }
        }

        switch primaryAlert.severity {
        case 5...:
            return colorScheme == .dark ? 0.15 : 0.065
        case 3...4:
            return colorScheme == .dark ? 0.09 : 0.040
        default:
            return colorScheme == .dark ? 0.050 : 0.025
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
    private static let rowSpacing: CGFloat = 6

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
                            .padding(.bottom, 4)
                            .accessibilityLabel("\(overflowCount) more active alerts")
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(minHeight: reservedStackHeight, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityRepresentation {
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                if alerts.isEmpty {
                    WidgetLargeQuietAwarenessState()
                } else {
                    ForEach(alerts.indices, id: \.self) { index in
                        WidgetLargeAlertRailRow(alert: alerts[index])
                    }

                    if overflowCount > 0 {
                        Text("\(overflowCount) more active alerts")
                    }
                }
            }
        }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1)
                .accessibilityHidden(true)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        columns
                    }
                } else {
                    HStack(alignment: .bottom, spacing: 12) {
                        columns
                    }
                }
            }
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var columns: some View {
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
}

private struct WidgetLargeRiskContextColumn: View {
    let title: String
    let state: WidgetRiskDisplayState
    let style: WidgetRiskVisualStyle

    private var accent: Color {
        state == .placeholder ? .secondary : style.tint
    }

    private var icon: String {
        state == .placeholder ? "minus.circle" : style.icon
    }

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(accent)
                .frame(width: 3, height: 24)
                .padding(.top, 1)
                .accessibilityHidden(true)

            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent.opacity(0.72))
                .frame(width: 16)
                .padding(.top, 2)
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

    private var surfaceOpacity: Double {
        if alert.typeLabel.localizedLowercase == "warning" {
            switch alert.severity {
            case 5...:
                return colorScheme == .dark ? 0.18 : 0.11
            case 3...4:
                return colorScheme == .dark ? 0.15 : 0.090
            default:
                return colorScheme == .dark ? 0.12 : 0.075
            }
        }

        switch alert.severity {
        case 5...:
            return colorScheme == .dark ? 0.18 : 0.11
        case 3...4:
            return colorScheme == .dark ? 0.12 : 0.075
        default:
            return colorScheme == .dark ? 0.075 : 0.050
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(style.tint.opacity(colorScheme == .dark ? 0.92 : 0.82))
                .frame(width: 3, height: 30)
                .accessibilityHidden(true)

            Image(systemName: style.icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(style.tint)
                .frame(width: 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.78)

                Text(lifecycleLine)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: WidgetLargeAlertRailStack.rowMinimumHeight)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(style.tint.opacity(surfaceOpacity))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}
