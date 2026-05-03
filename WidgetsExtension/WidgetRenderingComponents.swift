import SwiftUI
import WidgetKit

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

            // Full-surface semantic wash. Keeps the whole widget warm without creating an inner panel.
            LinearGradient(
                colors: [
                    style.tint.opacity(colorScheme == .dark ? 0.06 : 0.025),
                    style.tint.opacity(colorScheme == .dark ? 0.18 : 0.055)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Option A-style lower trailing glow behind the decorative icon.
            RadialGradient(
                colors: [
                    style.tint.opacity(colorScheme == .dark ? 0.44 : 0.18),
                    style.tint.opacity(colorScheme == .dark ? 0.22 : 0.085),
                    style.tint.opacity(0.0)
                ],
                center: UnitPoint(x: 0.86, y: 0.62),
                startRadius: 4,
                endRadius: colorScheme == .dark ? 118 : 104
            )

            // Subtle warm body glow through the middle of the card.
            RadialGradient(
                colors: [
                    style.tint.opacity(colorScheme == .dark ? 0.18 : 0.065),
                    style.tint.opacity(0.0)
                ],
                center: UnitPoint(x: 0.58, y: 0.58),
                startRadius: 10,
                endRadius: colorScheme == .dark ? 190 : 150
            )

            // Soft top highlight to keep the surface Apple-like instead of flat.
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.055 : 0.34),
                    Color.white.opacity(0.0)
                ],
                startPoint: .topLeading,
                endPoint: .center
            )

            // Bottom vignette like the selected rendering, but restrained.
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(colorScheme == .dark ? 0.22 : 0.035)
                ],
                startPoint: .center,
                endPoint: .bottomTrailing
            )
        }
    }

    private var stormBaseColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.065, green: 0.095, blue: 0.135),
                Color(red: 0.105, green: 0.075, blue: 0.060),
                Color(red: 0.030, green: 0.045, blue: 0.075)
            ]
        }

        return [
            Color(red: 0.985, green: 0.990, blue: 1.000),
            Color(red: 0.965, green: 0.975, blue: 0.995),
            Color(red: 0.940, green: 0.955, blue: 0.985)
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

            // Full-surface semantic wash. Keeps the whole widget tinted without creating an inner panel.
            LinearGradient(
                colors: [
                    style.tint.opacity(colorScheme == .dark ? 0.06 : 0.025),
                    style.tint.opacity(colorScheme == .dark ? 0.18 : 0.055)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Lower-trailing glow behind the decorative severe-risk icon.
            RadialGradient(
                colors: [
                    style.tint.opacity(colorScheme == .dark ? 0.40 : 0.16),
                    style.tint.opacity(colorScheme == .dark ? 0.20 : 0.075),
                    style.tint.opacity(0.0)
                ],
                center: UnitPoint(x: 0.86, y: 0.62),
                startRadius: 4,
                endRadius: colorScheme == .dark ? 118 : 104
            )

            // Subtle body glow through the middle of the card.
            RadialGradient(
                colors: [
                    style.tint.opacity(colorScheme == .dark ? 0.16 : 0.055),
                    style.tint.opacity(0.0)
                ],
                center: UnitPoint(x: 0.58, y: 0.58),
                startRadius: 10,
                endRadius: colorScheme == .dark ? 190 : 150
            )

            // Soft top highlight to keep the surface Apple-like instead of flat.
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.055 : 0.34),
                    Color.white.opacity(0.0)
                ],
                startPoint: .topLeading,
                endPoint: .center
            )

            // Bottom vignette, restrained.
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(colorScheme == .dark ? 0.22 : 0.035)
                ],
                startPoint: .center,
                endPoint: .bottomTrailing
            )
        }
    }

    private var severeBaseColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.065, green: 0.095, blue: 0.135),
                Color(red: 0.060, green: 0.075, blue: 0.105),
                Color(red: 0.030, green: 0.045, blue: 0.075)
            ]
        }

        return [
            Color(red: 0.985, green: 0.990, blue: 1.000),
            Color(red: 0.965, green: 0.975, blue: 0.995),
            Color(red: 0.940, green: 0.955, blue: 0.985)
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
            ZStack {
                LinearGradient(
                    colors: backgroundGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Full-surface semantic wash from the strongest current signal.
                LinearGradient(
                    colors: [
                        semanticTint.opacity(colorScheme == .dark ? 0.055 : 0.022),
                        semanticTint.opacity(colorScheme == .dark ? 0.16 : 0.052)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Primary signal glow, biased toward the upper trailing risk group.
                RadialGradient(
                    colors: [
                        semanticTint.opacity(colorScheme == .dark ? 0.34 : 0.14),
                        semanticTint.opacity(colorScheme == .dark ? 0.17 : 0.065),
                        semanticTint.opacity(0.0)
                    ],
                    center: UnitPoint(x: 0.82, y: 0.22),
                    startRadius: 12,
                    endRadius: colorScheme == .dark ? 280 : 230
                )

                // Storm-side warmth so the left risk group feels integrated.
                RadialGradient(
                    colors: [
                        stormTint.opacity(colorScheme == .dark ? 0.18 : 0.070),
                        stormTint.opacity(0.0)
                    ],
                    center: UnitPoint(x: 0.18, y: 0.18),
                    startRadius: 10,
                    endRadius: colorScheme == .dark ? 240 : 190
                )

                // Soft top highlight for the Apple-like surface depth.
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.050 : 0.30),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .center
                )

                // Bottom vignette to anchor the large surface.
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(colorScheme == .dark ? 0.24 : 0.040)
                    ],
                    startPoint: .center,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.065, green: 0.095, blue: 0.135),
                Color(red: 0.055, green: 0.060, blue: 0.095),
                Color(red: 0.030, green: 0.045, blue: 0.075)
            ]
        }

        return [
            Color(red: 0.985, green: 0.990, blue: 1.000),
            Color(red: 0.965, green: 0.975, blue: 0.995),
            Color(red: 0.940, green: 0.955, blue: 0.985)
        ]
    }

    private var semanticTint: Color {
        if let selectedAlert = snapshot.selectedAlert {
            return WidgetAlertVisualStyle.style(for: selectedAlert).tint
        }
        if snapshot.severeRisk.severity > 0 {
            return WidgetRiskVisualStyle.style(for: .severe, severity: snapshot.severeRisk.severity).tint
        }
        if snapshot.stormRisk.severity > 0 {
            return WidgetRiskVisualStyle.style(for: .storm, severity: snapshot.stormRisk.severity).tint
        }
        return Color(red: 0.40, green: 0.75, blue: 0.40)
    }

    private var stormTint: Color {
        WidgetRiskVisualStyle.style(for: .storm, severity: snapshot.stormRisk.severity).tint
    }
}

private struct WidgetCombinedLargeCard: View {
    let snapshot: WidgetSnapshot
    @Environment(\.colorScheme) private var colorScheme

    private var stormStyle: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .storm, severity: snapshot.stormRisk.severity)
    }

    private var severeStyle: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .severe, severity: snapshot.severeRisk.severity)
    }

    private var alertStyle: WidgetAlertVisualStyle? {
        guard let selectedAlert = snapshot.selectedAlert else { return nil }
        return WidgetAlertVisualStyle.style(for: selectedAlert)
    }

    private var locationSummaryLine: String {
        let trimmed = snapshot.locationSummary?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return "Location unavailable" }
        return trimmed
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                decorativeGlowLayer(in: proxy.size)

                VStack(alignment: .leading, spacing: 14) {
                    WidgetCombinedRiskPairRow(
                        stormState: snapshot.stormRisk,
                        severeState: snapshot.severeRisk
                    )

                    if let selectedAlert = snapshot.selectedAlert {
                        WidgetCombinedIntegratedAlertRow(
                            alert: selectedAlert,
                            hiddenAlertCount: snapshot.hiddenAlertCount
                        )
                    } else {
                        WidgetCombinedIntegratedNoAlertRow(stormSeverity: snapshot.stormRisk.severity)
                    }

                    Spacer(minLength: 0)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Label(locationSummaryLine, systemImage: "mappin.and.ellipse")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Spacer(minLength: 8)

                        WidgetFreshnessLineView(freshness: snapshot.freshness)
                            .font(.caption2.weight(snapshot.freshness.state == .stale ? .semibold : .medium))
                            .foregroundStyle(snapshot.freshness.state == .stale ? .orange : .secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private func decorativeGlowLayer(in size: CGSize) -> some View {
        let signalTint = alertStyle?.tint ?? severeStyle.tint
        Circle()
            .fill(signalTint.opacity(colorScheme == .dark ? 0.22 : 0.10))
            .frame(width: colorScheme == .dark ? 260 : 220, height: colorScheme == .dark ? 260 : 220)
            .blur(radius: colorScheme == .dark ? 72 : 56)
            .position(x: size.width * 0.78, y: size.height * 0.26)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

        Circle()
            .fill(stormStyle.tint.opacity(colorScheme == .dark ? 0.14 : 0.07))
            .frame(width: colorScheme == .dark ? 220 : 180, height: colorScheme == .dark ? 220 : 180)
            .blur(radius: colorScheme == .dark ? 68 : 52)
            .position(x: size.width * 0.20, y: size.height * 0.10)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var accessibilitySummary: String {
        var parts: [String] = []
        parts.append("Storm Risk \(snapshot.stormRisk.label)")
        if snapshot.severeRisk.severity == 0 {
            parts.append("Severe Risk no active threats")
        } else {
            parts.append("Severe Risk \(snapshot.severeRisk.label)")
        }

        if let selectedAlert = snapshot.selectedAlert {
            parts.append("Alert \(selectedAlert.title)")
            if snapshot.hiddenAlertCount > 0 {
                parts.append("Plus \(snapshot.hiddenAlertCount) more")
            }
        } else {
            parts.append("No local alerts")
        }

        parts.append(locationSummaryLine)

        parts.append(WidgetFreshnessFormatter.line(for: snapshot.freshness))
        return parts.joined(separator: ". ")
    }
}

private struct WidgetCombinedRiskPairRow: View {
    let stormState: WidgetRiskDisplayState
    let severeState: WidgetRiskDisplayState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            WidgetCombinedRiskSummaryGroup(
                title: "Storm Risk",
                primary: stormPrimaryLabel,
                accent: stormStyle.tint,
                icon: stormStyle.icon
            )

            Rectangle()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.14))
                .frame(width: 1, height: 46)
                .padding(.top, 2)
                .accessibilityHidden(true)

            WidgetCombinedRiskSummaryGroup(
                title: "Severe Risk",
                primary: severePrimaryLabel,
                secondary: severeSecondaryLabel,
                accent: severeStyle.tint,
                icon: severeStyle.icon
            )
        }
    }

    private var stormStyle: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .storm, severity: stormState.severity)
    }

    private var severeStyle: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .severe, severity: severeState.severity)
    }

    private var stormPrimaryLabel: String {
        guard stormState.label.hasSuffix(" Risk") else { return stormState.label }
        let level = stormState.label.dropLast(" Risk".count)
        let trimmed = level.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? stormState.label : String(trimmed)
    }

    private var severePrimaryLabel: String {
        severeState.severity == 0 ? "No Active" : severeState.label
    }

    private var severeSecondaryLabel: String? {
        nil
    }
}

private struct WidgetCombinedRiskSummaryGroup: View {
    let title: String
    let primary: String
    var secondary: String? = nil
    let accent: Color
    var icon: String? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(primary)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)

                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: colorScheme == .dark ? 25 : 23, weight: .regular))
                        .foregroundStyle(accent.opacity(colorScheme == .dark ? 0.58 : 0.22))
                        .lineLimit(1)
                        .accessibilityHidden(true)
                }
            }

            if let secondary {
                Text(secondary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WidgetCombinedIntegratedAlertRow: View {
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

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(style.tint.opacity(colorScheme == .dark ? 0.92 : 0.82))
                .frame(width: 3, height: 46)
                .accessibilityHidden(true)

            Image(systemName: style.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(style.tint)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)

            if hiddenAlertCount > 0 {
                Text("+\(hiddenAlertCount)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
    }
}

private struct WidgetCombinedIntegratedNoAlertRow: View {
    let stormSeverity: Int

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color.secondary.opacity(0.45))
                .frame(width: 3, height: 44)
                .accessibilityHidden(true)

            Image(systemName: "checkmark.shield")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(red: 0.40, green: 0.75, blue: 0.40))
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("No local alerts")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(stormSeverity > 0 ? "Storm risk remains elevated" : "Your area is clear right now")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
    }
}
