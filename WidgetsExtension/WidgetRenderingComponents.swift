import SwiftUI
import WidgetKit

struct WidgetStormRiskSmallView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        Group {
            if case let .unavailable(message) = snapshot.availability {
                WidgetUnavailableStateView(message: message)
                    .padding(14)
            } else {
                WidgetStormRiskBadgeCard(state: snapshot.stormRisk, freshness: snapshot.freshness)
            }
        }
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    private var backgroundGradient: LinearGradient {
        if case .available = snapshot.availability {
            let style = WidgetRiskVisualStyle.style(for: .storm, severity: snapshot.stormRisk.severity)
            return LinearGradient(
                colors: [style.chip.opacity(0.95), style.tint.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color(red: 0.11, green: 0.14, blue: 0.18), Color(red: 0.08, green: 0.10, blue: 0.13)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct WidgetSevereRiskSmallView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        Group {
            if case let .unavailable(message) = snapshot.availability {
                WidgetUnavailableStateView(message: message)
                    .padding(14)
            } else {
                WidgetSevereRiskBadgeCard(state: snapshot.severeRisk, freshness: snapshot.freshness)
            }
        }
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    private var backgroundGradient: LinearGradient {
        if case .available = snapshot.availability {
            let style = WidgetRiskVisualStyle.style(for: .severe, severity: snapshot.severeRisk.severity)
            return LinearGradient(
                colors: [style.chip.opacity(0.95), style.tint.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color(red: 0.11, green: 0.14, blue: 0.18), Color(red: 0.08, green: 0.10, blue: 0.13)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct WidgetStormRiskBadgeCard: View {
    let state: WidgetRiskDisplayState
    let freshness: WidgetFreshnessState

    private var style: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .storm, severity: state.severity)
    }

    private var summary: String {
        switch state.severity {
        case 0: return "No severe storms expected"
        case 1: return "Chance of thunderstorms"
        case 2: return "Low risk, but stronger storms possible"
        case 3: return "A few strong storms possible"
        case 4: return "Several severe storms possible"
        case 5: return "Widespread severe storms expected"
        default: return "Severe outbreak likely - stay alert"
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Spacer(minLength: 0)

            Image(systemName: style.icon)
                .font(.system(size: 32, weight: .semibold))
                .frame(height: 34)
                .foregroundStyle(.primary)
                .accessibilityHidden(true)

            Text(state.label)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            Text(WidgetFreshnessFormatter.line(for: freshness))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(freshness.state == .stale ? .orange : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

private struct WidgetSevereRiskBadgeCard: View {
    let state: WidgetRiskDisplayState
    let freshness: WidgetFreshnessState

    private var style: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .severe, severity: state.severity)
    }

    private var summary: String {
        switch state.severity {
        case 0: return "No severe threats expected"
        case 1: return "Damaging wind possible"
        case 2: return "1 in or larger hail possible"
        default: return "Tornadoes are possible"
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Spacer(minLength: 0)

            Image(systemName: style.icon)
                .font(.system(size: 32, weight: .semibold))
                .frame(height: 34)
                .foregroundStyle(.primary)
                .accessibilityHidden(true)

            Text(state.label)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            Text(WidgetFreshnessFormatter.line(for: freshness))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(freshness.state == .stale ? .orange : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

struct WidgetRiskBadgeView: View {
    let title: String
    let state: WidgetRiskDisplayState
    let kind: WidgetRiskKind
    var emphasized: Bool = false
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    @Environment(\.colorScheme) private var colorScheme

    private var style: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: kind, severity: state.severity)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: style.icon)
                .font(.caption.weight(.semibold))
                .frame(width: 24, height: 24)
                .background {
                    Circle().fill(style.chip)
                }
                .foregroundStyle(style.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(state.label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, emphasized ? 16 : 8)
        .frame(maxWidth: .infinity, minHeight: emphasized ? 96 : nil, alignment: .center)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundStyle)
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        if emphasized {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [style.chip.opacity(colorScheme == .dark ? 0.95 : 0.85), style.tint.opacity(colorScheme == .dark ? 0.68 : 0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        switch widgetRenderingMode {
        case .accented, .vibrant:
            return AnyShapeStyle(Color.primary.opacity(0.10))
        default:
            return AnyShapeStyle(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08))
        }
    }
}

struct WidgetFreshnessLineView: View {
    let freshness: WidgetFreshnessState

    var body: some View {
        Label(WidgetFreshnessFormatter.line(for: freshness), systemImage: freshness.state == .stale ? "clock.badge.exclamationmark" : "clock")
            .font(.caption2.weight(.medium))
            .foregroundStyle(freshness.state == .stale ? .orange : .secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

struct WidgetUnavailableStateView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Risk Unavailable", systemImage: "location.slash")
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WidgetStaleStateView: View {
    let freshness: WidgetFreshnessState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            Text(WidgetFreshnessFormatter.line(for: freshness))
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(Color.orange.opacity(0.15))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WidgetCompactAlertRowView: View {
    let alert: WidgetSelectedAlertRowDisplayState
    let hiddenAlertCount: Int
    @Environment(\.colorScheme) private var colorScheme

    private var style: WidgetAlertVisualStyle {
        WidgetAlertVisualStyle.style(for: alert)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: style.icon)
                .foregroundStyle(style.tint)
                .font(.caption.weight(.semibold))
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(alert.typeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if hiddenAlertCount > 0 {
                Text("+\(hiddenAlertCount) more")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background {
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.18))
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08))
        }
    }
}

struct WidgetNoAlertStateView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("No active local alerts")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08))
        }
    }
}


struct WidgetCombinedLargeView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if case let .unavailable(message) = snapshot.availability {
                WidgetUnavailableStateView(message: message)
                    .padding(12)
            } else {
                WidgetCombinedLargeCard(snapshot: snapshot)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: backgroundGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [Color(red: 0.11, green: 0.14, blue: 0.18), Color(red: 0.08, green: 0.10, blue: 0.13)]
        }

        return [Color(red: 0.95, green: 0.97, blue: 1.00), Color(red: 0.90, green: 0.94, blue: 0.99)]
    }
}

private struct WidgetCombinedLargeCard: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                WidgetRiskBadgeView(
                    title: WidgetRiskKind.storm.title,
                    state: snapshot.stormRisk,
                    kind: .storm,
                    emphasized: true
                )

                WidgetRiskBadgeView(
                    title: WidgetRiskKind.severe.title,
                    state: snapshot.severeRisk,
                    kind: .severe,
                    emphasized: true
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Local Alert")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let selectedAlert = snapshot.selectedAlert {
                    WidgetCompactAlertRowView(
                        alert: selectedAlert,
                        hiddenAlertCount: snapshot.hiddenAlertCount
                    )
                } else {
                    WidgetNoAlertStateView()
                }
            }

            Spacer(minLength: 0)

            if snapshot.freshness.state == .stale {
                WidgetStaleStateView(freshness: snapshot.freshness)
            } else {
                WidgetFreshnessLineView(freshness: snapshot.freshness)
            }
        }
        .padding(3)
    }
}
