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
        let emphasis = WidgetSemanticEmphasis.style(
            for: .storm,
            severity: snapshot.stormRisk.severity,
            isDark: colorScheme == .dark
        )
        let isQuiet = snapshot.stormRisk.severity == 0

        return ZStack {
            LinearGradient(
                colors: stormBaseColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Full-surface semantic wash. Keeps the whole widget warm without creating an inner panel.
            LinearGradient(
                colors: [
                    style.tint.opacity(emphasis.washStart),
                    style.tint.opacity(emphasis.washEnd)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Option A-style lower trailing glow behind the decorative icon.
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

            // Subtle warm body glow through the middle of the card.
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
                    Color.white.opacity(colorScheme == .dark ? 0.055 : 0.16),
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
            Color(red: 0.910, green: 0.930, blue: 0.970),
            Color(red: 0.860, green: 0.890, blue: 0.940),
            Color(red: 0.800, green: 0.850, blue: 0.920)
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

                    if freshness.state == .stale {
                        WidgetFreshnessLineView(freshness: freshness)
                            .padding(.top, 4)
                    }

                    Spacer(minLength: 10)

                    riskValueText
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
            .foregroundStyle(style.tint.opacity(state.severity == 0 ? 0.08 : (colorScheme == .dark ? 0.58 : 0.22)))
            .accessibilityHidden(true)
    }

    private var iconGlow: some View {
        Circle()
            .fill(style.tint.opacity(state.severity == 0 ? 0.06 : (colorScheme == .dark ? 0.34 : 0.12)))
            .frame(width: colorScheme == .dark ? 210 : 190, height: colorScheme == .dark ? 210 : 190)
            .blur(radius: colorScheme == .dark ? 58 : 50)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var riskValueText: some View {
        if let composition = composedRiskLabels {
            VStack(alignment: .leading, spacing: 0) {
                Text(composition.primary)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(composition.secondary)
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

    private var composedRiskLabels: (primary: String, secondary: String)? {
        switch state.label {
        case "No Severe Storm Risk":
            return ("No Severe", "Storm Risk")
        case "Marginal Risk":
            return ("Marginal", "Risk")
        case "Slight Risk":
            return ("Slight", "Risk")
        case "Enhanced Risk":
            return ("Enhanced", "Risk")
        case "Moderate Risk":
            return ("Moderate", "Risk")
        case "High Risk":
            return ("High", "Risk")
        default:
            return nil
        }
    }

    private var accessibilitySummary: String {
        "Storm Risk, \(state.label), \(WidgetFreshnessFormatter.line(for: freshness))"
    }

}
