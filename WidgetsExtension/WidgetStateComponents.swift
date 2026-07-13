import SwiftUI
import WidgetKit

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
