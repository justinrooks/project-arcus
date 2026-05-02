import SwiftUI
import WidgetKit

private enum WidgetSurfacePalette {
    static let darkBaseTop = Color(red: 0.11, green: 0.14, blue: 0.18)
    static let darkBaseBottom = Color(red: 0.08, green: 0.10, blue: 0.13)
    static let lightBaseTop = Color(red: 0.95, green: 0.97, blue: 1.00)
    static let lightBaseBottom = Color(red: 0.90, green: 0.94, blue: 0.99)
}

struct WidgetStormRiskSmallView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.colorScheme) private var colorScheme

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
        let style = WidgetRiskVisualStyle.style(for: .storm, severity: snapshot.stormRisk.severity)
        let baseColors = colorScheme == .dark
            ? [WidgetSurfacePalette.darkBaseTop, WidgetSurfacePalette.darkBaseBottom]
            : [WidgetSurfacePalette.lightBaseTop, WidgetSurfacePalette.lightBaseBottom]
        return LinearGradient(
            colors: [
                baseColors[0],
                baseColors[1],
                style.tint.opacity(colorScheme == .dark ? 0.16 : 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct WidgetSevereRiskSmallView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.colorScheme) private var colorScheme

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
        let style = WidgetRiskVisualStyle.style(for: .severe, severity: snapshot.severeRisk.severity)
        let baseColors = colorScheme == .dark
            ? [WidgetSurfacePalette.darkBaseTop, WidgetSurfacePalette.darkBaseBottom]
            : [WidgetSurfacePalette.lightBaseTop, WidgetSurfacePalette.lightBaseBottom]
        return LinearGradient(
            colors: [
                baseColors[0],
                baseColors[1],
                style.tint.opacity(colorScheme == .dark ? 0.14 : 0.07)
            ],
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

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Spacer(minLength: 0)

            Image(systemName: style.icon)
                .font(.system(size: 32, weight: .semibold))
                .frame(width: 54, height: 54)
                .background {
                    Circle()
                        .fill(style.chip)
                }
                .foregroundStyle(style.tint)
                .accessibilityHidden(true)

            Text(state.label)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            freshnessFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var freshnessFooter: some View {
        if freshness.state == .stale {
            WidgetStaleStateView(freshness: freshness, compact: true)
        }
    }
}

private struct WidgetSevereRiskBadgeCard: View {
    let state: WidgetRiskDisplayState
    let freshness: WidgetFreshnessState

    private var style: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .severe, severity: state.severity)
    }

    private var titleFont: Font {
        state.severity == 0 ? .subheadline.weight(.semibold) : .headline
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Spacer(minLength: 0)

            Image(systemName: style.icon)
                .font(.system(size: 32, weight: .semibold))
                .frame(width: 54, height: 54)
                .background {
                    Circle()
                        .fill(style.chip)
                }
                .foregroundStyle(style.tint)
                .accessibilityHidden(true)
            Text(state.label)
                .font(titleFont)
                .lineLimit(state.severity == 0 ? 2 : 1)
                .minimumScaleFactor(state.severity == 0 ? 1.0 : 0.7)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            freshnessFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var freshnessFooter: some View {
        if freshness.state == .stale {
            WidgetStaleStateView(freshness: freshness, compact: true)
        }
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
        .padding(.vertical, emphasized ? 14 : 8)
        .frame(maxWidth: .infinity, minHeight: emphasized ? 88 : nil, alignment: .center)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(backgroundStyle)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.24), lineWidth: 0.8)
                }
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        if emphasized {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        style.chip.opacity(colorScheme == .dark ? 0.70 : 0.46),
                        style.tint.opacity(colorScheme == .dark ? 0.26 : 0.14)
                    ],
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "location.slash")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 30, height: 30)
                    .background {
                        Circle()
                            .fill(Color.secondary.opacity(0.14))
                    }
                    .accessibilityHidden(true)
                Text("Risk Unavailable")
                    .font(.subheadline.weight(.semibold))
            }
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
    var compact: Bool = false

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
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 5 : 6)
        .background {
            Capsule(style: .continuous)
                .fill(Color.orange.opacity(compact ? 0.12 : 0.15))
        }
        .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
    }
}

struct WidgetCompactAlertRowView: View {
    let alert: WidgetSelectedAlertRowDisplayState
    let hiddenAlertCount: Int
    @Environment(\.colorScheme) private var colorScheme
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var style: WidgetAlertVisualStyle {
        WidgetAlertVisualStyle.style(for: alert)
    }

    private var subtitle: String {
        guard let validEnd = alert.validEnd else {
            guard let issuedAt = alert.issuedAt else {
                return alert.typeLabel
            }

            return "\(alert.typeLabel) • Issued \(Self.relativeFormatter.localizedString(for: issuedAt, relativeTo: .now))"
        }

        return "\(alert.typeLabel) • Ends \(Self.relativeFormatter.localizedString(for: validEnd, relativeTo: .now))"
    }

    private var accessibilitySubtitle: String {
        guard let validEnd = alert.validEnd else {
            guard let issuedAt = alert.issuedAt else {
                return alert.typeLabel
            }

            return "\(alert.typeLabel). Issued \(Self.relativeFormatter.localizedString(for: issuedAt, relativeTo: .now))"
        }

        return "\(alert.typeLabel). Ends \(Self.relativeFormatter.localizedString(for: validEnd, relativeTo: .now))"
    }

    private var accessibilityLabel: String {
        if hiddenAlertCount > 0 {
            return "\(alert.title). \(accessibilitySubtitle). Plus \(hiddenAlertCount) more alerts."
        }

        return "\(alert.title). \(accessibilitySubtitle)."
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: style.icon)
                .foregroundStyle(style.tint)
                .font(.headline.weight(.semibold))
                .frame(width: 40, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(style.tint.opacity(0.16))
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(subtitle)
                    .font(.caption.weight(.medium))
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
                            .fill(Color.secondary.opacity(0.16))
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.20), lineWidth: 0.8)
                }
        }
    }
}

struct WidgetNoAlertStateView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(Color(red: 0.40, green: 0.75, blue: 0.40))
                .font(.headline.weight(.semibold))
                .frame(width: 40, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.40, green: 0.75, blue: 0.40).opacity(0.16))
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("No active local alerts")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Your local area is clear right now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.20), lineWidth: 0.8)
                }
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
            return [WidgetSurfacePalette.darkBaseTop, WidgetSurfacePalette.darkBaseBottom]
        }

        return [WidgetSurfacePalette.lightBaseTop, WidgetSurfacePalette.lightBaseBottom]
    }
}

private struct WidgetCombinedLargeCard: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Local Alerts")
                    .font(.caption2.weight(.medium))
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
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }
}
