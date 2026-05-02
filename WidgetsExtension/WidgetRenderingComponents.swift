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

    private var backgroundGradient: some View {
        let style = WidgetRiskVisualStyle.style(for: .storm, severity: snapshot.stormRisk.severity)
        return ZStack {
            LinearGradient(
                colors: stormBaseColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    style.tint.opacity(colorScheme == .dark ? 0.16 : 0.04),
                    style.tint.opacity(colorScheme == .dark ? 0.28 : 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var stormBaseColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.07, green: 0.11, blue: 0.17),
                Color(red: 0.04, green: 0.06, blue: 0.10)
            ]
        }

        return [
            Color(red: 0.97, green: 0.98, blue: 1.00),
            Color(red: 0.95, green: 0.96, blue: 0.99)
        ]
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

    private var backgroundGradient: some View {
        let style = WidgetRiskVisualStyle.style(for: .severe, severity: snapshot.severeRisk.severity)
        return ZStack {
            LinearGradient(
                colors: severeBaseColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    style.tint.opacity(colorScheme == .dark ? 0.14 : 0.035),
                    style.tint.opacity(colorScheme == .dark ? 0.24 : 0.065)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var severeBaseColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.07, green: 0.11, blue: 0.17),
                Color(red: 0.04, green: 0.06, blue: 0.10)
            ]
        }

        return [
            Color(red: 0.97, green: 0.98, blue: 1.00),
            Color(red: 0.95, green: 0.96, blue: 0.99)
        ]
    }
}

private struct WidgetStormRiskBadgeCard: View {
    let state: WidgetRiskDisplayState
    let freshness: WidgetFreshnessState
    @Environment(\.colorScheme) private var colorScheme

    private var style: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .storm, severity: state.severity)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                iconGlow
                    .position(x: proxy.size.width * 0.78, y: proxy.size.height * 0.62)

                decorativeIcon
                    .position(x: proxy.size.width * 0.74, y: proxy.size.height * 0.30)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Storm Risk")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 10)

                    riskValueText
                        .frame(maxWidth: proxy.size.width * 0.72, alignment: .leading)

                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var decorativeIcon: some View {
        Image(systemName: style.icon)
            .font(.system(size: colorScheme == .dark ? 62 : 56, weight: .regular))
            .foregroundStyle(style.tint.opacity(colorScheme == .dark ? 0.58 : 0.22))
            .accessibilityHidden(true)
    }

    private var iconGlow: some View {
        Circle()
            .fill(style.tint.opacity(colorScheme == .dark ? 0.34 : 0.12))
            .frame(width: colorScheme == .dark ? 210 : 190, height: colorScheme == .dark ? 210 : 190)
            .blur(radius: colorScheme == .dark ? 58 : 50)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var riskValueText: some View {
        if let level = splitRiskLevel(from: state.label) {
            VStack(alignment: .leading, spacing: 0) {
                Text(level)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("Risk")
                    .foregroundStyle(style.tint)
                    .lineLimit(1)
            }
            .font(.title2.weight(.bold))
            .minimumScaleFactor(0.82)
            .multilineTextAlignment(.leading)
        } else {
            Text(state.label)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
        }
    }

    private func splitRiskLevel(from label: String) -> String? {
        guard label.hasSuffix(" Risk") else { return nil }
        let level = label.dropLast(" Risk".count)
        let trimmed = level.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var accessibilitySummary: String {
        "Storm Risk, \(state.label), \(WidgetFreshnessFormatter.line(for: freshness))"
    }

}

private struct WidgetSevereRiskBadgeCard: View {
    let state: WidgetRiskDisplayState
    let freshness: WidgetFreshnessState
    @Environment(\.colorScheme) private var colorScheme

    private var style: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .severe, severity: state.severity)
    }

    private var subtitle: String? {
        guard state.severity > 0 else { return nil }
        return "Possible"
    }

    private var primaryLabel: String {
        guard state.severity == 0 else { return state.label }
        return "No Active"
    }

    private var secondaryLabel: String? {
        guard state.severity == 0 else { return subtitle }
        return "Threats"
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                iconGlow
                    .position(x: proxy.size.width * 0.78, y: proxy.size.height * 0.62)

                decorativeIcon
                    .position(x: proxy.size.width * 0.74, y: proxy.size.height * 0.30)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Severe Risk")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 10)

                    severeValueText
                        .frame(maxWidth: proxy.size.width * 0.72, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var decorativeIcon: some View {
        Image(systemName: style.icon)
            .font(.system(size: colorScheme == .dark ? 62 : 56, weight: .regular))
            .foregroundStyle(style.tint.opacity(colorScheme == .dark ? 0.58 : 0.22))
            .accessibilityHidden(true)
    }

    private var iconGlow: some View {
        Circle()
            .fill(style.tint.opacity(colorScheme == .dark ? 0.20 : 0.07))
            .frame(width: colorScheme == .dark ? 230 : 200, height: colorScheme == .dark ? 230 : 200)
            .blur(radius: colorScheme == .dark ? 72 : 58)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var severeValueText: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(primaryLabel)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(state.severity == 0 ? 0.72 : 0.78)

            if let secondaryLabel {
                Text(secondaryLabel)
                    .foregroundStyle(style.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .font(.title2.weight(.bold))
        .minimumScaleFactor(0.82)
        .multilineTextAlignment(.leading)
    }

    private var accessibilitySummary: String {
        if state.severity == 0 {
            return "Severe Risk, no active threats, \(WidgetFreshnessFormatter.line(for: freshness))"
        }

        if let subtitle {
            return "Severe Risk, \(state.label), \(subtitle), \(WidgetFreshnessFormatter.line(for: freshness))"
        }

        return "Severe Risk, \(state.label), \(WidgetFreshnessFormatter.line(for: freshness))"
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
