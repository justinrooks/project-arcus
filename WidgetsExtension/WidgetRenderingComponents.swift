import SwiftUI
import WidgetKit

struct WidgetRiskBadgeView: View {
    let title: String
    let state: WidgetRiskDisplayState
    let kind: WidgetRiskKind
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

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
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundColor)
        }
    }

    private var backgroundColor: Color {
        switch widgetRenderingMode {
        case .accented, .vibrant:
            return Color.primary.opacity(0.10)
        default:
            return Color.black.opacity(0.09)
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
        VStack(alignment: .leading, spacing: 8) {
            Label("Risk Unavailable", systemImage: "location.slash")
                .font(.subheadline.weight(.semibold))
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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(Color.orange.opacity(0.15))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WidgetCompactAlertRowView: View {
    let alert: WidgetSelectedAlertRowDisplayState
    let hiddenAlertCount: Int

    private var style: WidgetAlertVisualStyle {
        WidgetAlertVisualStyle.style(for: alert)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: style.icon)
                .foregroundStyle(style.tint)
                .font(.caption.weight(.semibold))
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(alert.typeLabel)
                    .font(.caption2)
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
                            .fill(Color.secondary.opacity(0.18))
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.10))
        }
    }
}

struct WidgetNoAlertStateView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("No active local alerts")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.10))
        }
    }
}
