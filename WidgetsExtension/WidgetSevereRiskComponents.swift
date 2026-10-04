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
        return ZStack {
            WidgetSurfaceStyle.baseColor(isDark: colorScheme == .dark)
            LinearGradient(
                colors: [
                    style.tint.opacity(WidgetSurfaceStyle.semanticWashOpacity(
                        severity: snapshot.severeRisk.severity,
                        isDark: colorScheme == .dark
                    )),
                    .clear
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
    }

}

private struct WidgetSevereRiskBadgeCard: View {
    let state: WidgetRiskDisplayState

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
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .center, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(style.tint.opacity(0.78))
                    .frame(width: 3, height: 20)
                    .accessibilityHidden(true)

                Image(systemName: style.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(style.tint)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                Text("Severe Risk")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            severeValueText
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
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
