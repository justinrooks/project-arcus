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
                WidgetStormRiskBadgeCard(state: snapshot.stormRisk)
            }
        }
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    private var backgroundGradient: some View {
        let style = WidgetRiskVisualStyle.style(for: .storm, severity: snapshot.stormRisk.severity)
        return ZStack {
            WidgetSurfaceStyle.baseColor(isDark: colorScheme == .dark)
            LinearGradient(
                colors: [
                    style.tint.opacity(WidgetSurfaceStyle.semanticWashOpacity(
                        severity: snapshot.stormRisk.severity,
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

private struct WidgetStormRiskBadgeCard: View {
    let state: WidgetRiskDisplayState

    private var style: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .storm, severity: state.severity)
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

                Text("Storm Risk")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            riskValueText
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
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
        "Storm Risk, \(state.label)"
    }

}
