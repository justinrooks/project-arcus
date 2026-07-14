import SwiftUI
import WidgetKit

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
