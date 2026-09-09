import SwiftUI
import WidgetKit

struct WidgetCombinedLargeView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var widgetFamily

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
                        semanticTint.opacity(combinedEmphasis.washStart),
                        semanticTint.opacity(combinedEmphasis.washEnd)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Primary signal glow, biased toward the upper trailing risk group.
                RadialGradient(
                    colors: [
                        semanticTint.opacity(combinedEmphasis.glowStart),
                        semanticTint.opacity(combinedEmphasis.glowMid),
                        semanticTint.opacity(0.0)
                    ],
                    center: UnitPoint(x: 0.82, y: 0.22),
                    startRadius: 12,
                    endRadius: colorScheme == .dark ? 280 : 230
                )

                // Storm-side warmth so the left risk group feels integrated.
                RadialGradient(
                    colors: [
                        stormTint.opacity(combinedEmphasis.bodyGlow),
                        stormTint.opacity(0.0)
                    ],
                    center: UnitPoint(x: 0.18, y: 0.18),
                    startRadius: 10,
                    endRadius: colorScheme == .dark ? 240 : 190
                )

                // Soft top highlight for the Apple-like surface depth.
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.050 : 0.15),
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
            Color(red: 0.910, green: 0.930, blue: 0.970),
            Color(red: 0.860, green: 0.890, blue: 0.940),
            Color(red: 0.800, green: 0.850, blue: 0.920)
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
        return Color(red: 0.25, green: 0.38, blue: 0.50)
    }

    private var stormTint: Color {
        guard snapshot.stormRisk.severity > 0 else {
            return Color(red: 0.25, green: 0.38, blue: 0.50)
        }
        return WidgetRiskVisualStyle.style(for: .storm, severity: snapshot.stormRisk.severity).tint
    }

    private var combinedEmphasis: WidgetSemanticEmphasis {
        guard widgetFamily == .systemMedium, snapshot.selectedAlert == nil else {
            return WidgetSemanticEmphasis(
                washStart: colorScheme == .dark ? 0.055 : 0.022,
                washEnd: colorScheme == .dark ? 0.16 : 0.052,
                glowStart: colorScheme == .dark ? 0.34 : 0.14,
                glowMid: colorScheme == .dark ? 0.17 : 0.065,
                bodyGlow: colorScheme == .dark ? 0.18 : 0.070
            )
        }

        let kind: WidgetRiskKind = snapshot.severeRisk.severity > 0 ? .severe : .storm
        let severity = kind == .severe ? snapshot.severeRisk.severity : snapshot.stormRisk.severity
        return WidgetSemanticEmphasis.style(for: kind, severity: severity, isDark: colorScheme == .dark)
    }
}

private struct WidgetCombinedLargeCard: View {
    let snapshot: WidgetSnapshot
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var widgetFamily

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

    private var isMediumFamily: Bool {
        widgetFamily == .systemMedium
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                decorativeGlowLayer(in: proxy.size)

                VStack(alignment: .leading, spacing: isMediumFamily ? 10 : 14) {
                    if isMediumFamily, let selectedAlert = snapshot.selectedAlert {
                        WidgetCombinedIntegratedAlertRow(
                            alert: selectedAlert,
                            hiddenAlertCount: snapshot.hiddenAlertCount
                        )
                        WidgetCombinedRiskPairRow(
                            stormState: snapshot.stormRisk,
                            severeState: snapshot.severeRisk
                        )
                    } else {
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
                    }

                    if !isMediumFamily {
                        Spacer(minLength: 0)
                    }

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
                .padding(.horizontal, isMediumFamily ? 14 : 16)
                .padding(.vertical, isMediumFamily ? 12 : 16)
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
                primary: stormState.label,
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

    private var severePrimaryLabel: String {
        severeState.label
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
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

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
                Text("+\(hiddenAlertCount) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
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
                .foregroundStyle(Color(red: 0.40, green: 0.75, blue: 0.40).opacity(0.72))
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("No local alerts")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                if stormSeverity > 0 {
                    Text("Storm risk remains elevated")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }

            Spacer(minLength: 0)
        }
    }
}
