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
