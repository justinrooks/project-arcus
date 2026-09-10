import SwiftUI
import WidgetKit

struct WidgetSevereRiskSmallView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if case let .unavailable(message) = snapshot.availability {
                WidgetUnavailableStateView(message: message)
                    .padding(14)
            } else {
                WidgetSevereRiskBadgeCard(state: snapshot.severeRisk)
            }
        }
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    private var backgroundGradient: some View {
        let style = WidgetRiskVisualStyle.style(for: .severe, severity: snapshot.severeRisk.severity)
        let emphasis = WidgetSemanticEmphasis.style(
            for: .severe,
            severity: snapshot.severeRisk.severity,
            isDark: colorScheme == .dark
        )
        let isQuiet = snapshot.severeRisk.severity == 0

        return ZStack {
            LinearGradient(
                colors: severeBaseColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Full-surface semantic wash. Keeps the whole widget tinted without creating an inner panel.
            LinearGradient(
                colors: [
                    style.tint.opacity(emphasis.washStart),
                    style.tint.opacity(emphasis.washEnd)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Lower-trailing glow behind the decorative severe-risk icon.
            RadialGradient(
                colors: [
                    style.tint.opacity(emphasis.glowStart),
                    style.tint.opacity(emphasis.glowMid),
                    style.tint.opacity(0.0)
                ],
                center: UnitPoint(x: 0.86, y: 0.62),
                startRadius: 4,
                endRadius: isQuiet ? 88 : (colorScheme == .dark ? 118 : 104)
            )

            // Subtle body glow through the middle of the card.
            RadialGradient(
                colors: [
                    style.tint.opacity(emphasis.bodyGlow),
                    style.tint.opacity(0.0)
                ],
                center: UnitPoint(x: 0.58, y: 0.58),
                startRadius: 10,
                endRadius: colorScheme == .dark ? 190 : 150
            )

            // Soft top highlight to keep the surface Apple-like instead of flat.
            LinearGradient(
                colors: [
                    Color.white.opacity(
                        colorScheme == .dark ? 0.055 : (isQuiet ? 0.06 : 0.16)
                    ),
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

        if snapshot.severeRisk.severity == 0 {
            return [
                Color(red: 0.780, green: 0.840, blue: 0.930),
                Color(red: 0.720, green: 0.790, blue: 0.890),
                Color(red: 0.640, green: 0.730, blue: 0.850)
            ]
        }

        return [
            Color(red: 0.910, green: 0.930, blue: 0.970),
            Color(red: 0.860, green: 0.890, blue: 0.940),
            Color(red: 0.800, green: 0.850, blue: 0.920)
        ]
    }
}

private struct WidgetSevereRiskBadgeCard: View {
    let state: WidgetRiskDisplayState
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
                        .frame(maxWidth: .infinity, alignment: .leading)
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
            .foregroundStyle(
                style.tint.opacity(
                    state.severity == 0
                        ? (colorScheme == .dark ? 0.08 : 0.22)
                        : (colorScheme == .dark ? 0.88 : 0.22)
                )
            )
            .accessibilityHidden(true)
    }

    private var iconGlow: some View {
        Circle()
            .fill(style.tint.opacity(state.severity == 0 ? 0.05 : (colorScheme == .dark ? 0.20 : 0.07)))
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
            return "Severe Risk, no active threats"
        }

        if let subtitle {
            return "Severe Risk, \(state.label), \(subtitle)"
        }

        return "Severe Risk, \(state.label)"
    }
}
