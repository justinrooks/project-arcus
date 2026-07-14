import SwiftUI
import WidgetKit

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
