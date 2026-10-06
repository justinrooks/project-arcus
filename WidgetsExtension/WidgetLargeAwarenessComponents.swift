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
            contextRow

            Text(awarenessHeading)
                .font(.title2.weight(.bold))
                .tracking(0.4)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.7)
                .padding(.top, 12)

            WidgetLargeAlertRailStack(
                alerts: activeAlerts,
                knownAlertCount: snapshot.knownActiveAlertCount
            )
                .padding(.top, 10)

            Spacer(minLength: 8)

            WidgetLargeRiskContextFooter(
                stormState: snapshot.stormRisk,
                severeState: snapshot.severeRisk,
                fireState: snapshot.fireRisk
            )
            .padding(.top, 10)
        }
        .padding(16)
    }

    private var contextRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("SkyAware")
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
            locationLabel
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
//            Image(systemName: "mappin")
//                .font(.caption2.weight(.semibold))
//                .foregroundStyle(.secondary)
//                .accessibilityHidden(true)
//            Text(location)
//                .font(.caption.weight(.medium))
//                .foregroundStyle(.secondary)
//                .lineLimit(1)
//                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
    }

    private var locationLabel: some View {
        Label(locationSummaryLine, systemImage: "mappin")
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.8)
    }

    private var atmosphericBackground: some View {
        ZStack {
            WidgetSurfaceStyle.baseColor(isDark: colorScheme == .dark)

            if let primaryAlertTint {
                LinearGradient(
                    colors: [primaryAlertTint.opacity(alertSurfaceEmphasis), .clear],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
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
        snapshot.knownActiveAlertCount
    }

    private var activeAlerts: [WidgetSelectedAlertRowDisplayState] {
        snapshot.activeAlerts.isEmpty ? [snapshot.selectedAlert].compactMap { $0 } : snapshot.activeAlerts
    }

    private var locationSummaryLine: String {
        let trimmed = snapshot.locationSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.flatMap { $0.isEmpty ? nil : $0 } ?? "Location unavailable"
    }


}

private struct WidgetLargeAlertRailStack: View {
    fileprivate static let rowMinimumHeight: CGFloat = 46
    fileprivate static let primaryRowMinimumHeight: CGFloat = 56
    private static let rowSpacing: CGFloat = 6

    let alerts: [WidgetSelectedAlertRowDisplayState]
    let knownAlertCount: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var visibleAlerts: [WidgetLargeAlertRailItem] {
        WidgetLargeAlertPresentation.visibleAlerts(
            from: alerts,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        ).enumerated().map { index, alert in
            WidgetLargeAlertRailItem(position: index, alert: alert)
        }
    }

    private var overflowCount: Int {
        WidgetLargeAlertPresentation.overflowCount(
            knownAlertCount: knownAlertCount,
            visibleAlertCount: visibleAlerts.count
        )
    }

    var body: some View {
        Group {
            if alerts.isEmpty {
                WidgetLargeQuietAwarenessState()
            } else {
                VStack(alignment: .leading, spacing: Self.rowSpacing) {
                    ForEach(visibleAlerts) { item in
                        WidgetLargeAlertRailRow(alert: item.alert, isPrimary: item.position == 0)
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
                    ForEach(visibleAlerts) { item in
                        WidgetLargeAlertRailRow(alert: item.alert)
                    }

                    if overflowCount > 0 {
                        Text("\(overflowCount) more active alerts")
                    }
                }
            }
        }
    }

    private var reservedStackHeight: CGFloat {
        let capacity = WidgetLargeAlertPresentation.visibleAlertCapacity(
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
        let secondaryCapacity = max(capacity - 1, 0)
        return Self.primaryRowMinimumHeight
            + (Self.rowMinimumHeight * CGFloat(secondaryCapacity))
            + (Self.rowSpacing * CGFloat(capacity - 1))
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
    let fireState: WidgetRiskDisplayState?
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
                    HStack(alignment: .top, spacing: 12) {
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
            value: stormState.label,
            accessibilityValue: stormState.label,
            tint: stormState == .placeholder
                ? .secondary
                : WidgetRiskVisualStyle.style(for: .storm, severity: stormState.severity).tint
        )

        WidgetLargeRiskContextColumn(
            title: "Severe Risk",
            value: severeState.label,
            accessibilityValue: severeState.label,
            tint: severeState == .placeholder
                ? .secondary
                : WidgetRiskVisualStyle.style(for: .severe, severity: severeState.severity).tint
        )

        WidgetLargeRiskContextColumn(
            title: "Fire Risk",
            value: fireState?.label ?? "--",
            accessibilityValue: fireState?.label ?? "unavailable",
            tint: fireState.map { WidgetFireRiskVisualStyle.style(for: $0.severity).tint } ?? .secondary
        )
    }
}

private struct WidgetLargeRiskContextColumn: View {
    let title: String
    let value: String
    let accessibilityValue: String
    let tint: Color
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: dynamicTypeSize.isAccessibilitySize ? 8 : 10) {
            Capsule()
                .fill(tint)
                .frame(width: 3)
                .accessibilityHidden(true)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibilityContent
                } else {
                    regularContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(accessibilityValue)")
    }

    private var regularContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
    }

    private var accessibilityContent: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)

            Spacer(minLength: 0)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.trailing)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
    }
}

private struct WidgetLargeAlertRailItem: Identifiable {
    let position: Int
    let alert: WidgetSelectedAlertRowDisplayState

    var id: Int { position }
}

private struct WidgetLargeAlertRailRow: View {
    let alert: WidgetSelectedAlertRowDisplayState
    var isPrimary = false
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

    private var rowSurfaceOpacity: Double {
        min(surfaceOpacity * (isPrimary ? 1.2 : 1), 0.22)
    }

    private var lifecycleFont: Font {
        isPrimary ? .caption : .caption2
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(style.tint.opacity(colorScheme == .dark ? 0.92 : 0.82))
                .frame(width: 3, height: 30)
                .accessibilityHidden(true)

            Image(systemName: style.icon)
                .font(isPrimary ? .subheadline.weight(.bold) : .caption.weight(.bold))
                .foregroundStyle(style.tint)
                .frame(width: isPrimary ? 20 : 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(isPrimary ? .headline.weight(.bold) : .subheadline.weight(.bold))
                    .lineLimit(isPrimary || dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(isPrimary ? 0.85 : 0.78)

                Text(lifecycleLine)
                    .font(lifecycleFont.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, isPrimary ? 8 : 6)
        .frame(
            minHeight: isPrimary
                ? WidgetLargeAlertRailStack.primaryRowMinimumHeight
                : WidgetLargeAlertRailStack.rowMinimumHeight
        )
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(style.tint.opacity(rowSurfaceOpacity))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}
