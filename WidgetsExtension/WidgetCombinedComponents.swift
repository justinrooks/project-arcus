import SwiftUI
import WidgetKit

struct WidgetCombinedMediumView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var stormStyle: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .storm, severity: snapshot.stormRisk.severity)
    }

    private var severeStyle: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .severe, severity: snapshot.severeRisk.severity)
    }

    private var alertStyle: WidgetAlertVisualStyle? {
        snapshot.selectedAlert.map(WidgetAlertVisualStyle.style(for:))
    }

    private var location: String {
        let value = snapshot.locationSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false ? value : nil) ?? "Location unavailable"
    }

    private var freshness: WidgetFreshnessState {
        snapshot.alertFreshness ?? snapshot.freshness
    }

    private var visibleFreshnessLine: String? {
        WidgetFreshnessFormatter.lineSuppressingStaleState(for: freshness)
    }

    private var isMaximumAccessibilitySize: Bool {
        dynamicTypeSize >= .accessibility3
    }

    var body: some View {
        Group {
            if case let .unavailable(message) = snapshot.availability {
                WidgetUnavailableStateView(message: message)
                    .padding(12)
            } else {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibleContent
                        .padding(12)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibilitySummary)
                } else {
                    content
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibilitySummary)
                }
            }
        }
        .containerBackground(for: .widget) {
            WidgetSurfaceStyle.baseColor(isDark: colorScheme == .dark)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 7) {
            contextRow
            primaryAwareness
                .frame(maxHeight: .infinity, alignment: .top)

            Rectangle()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.14))
                .frame(height: 1)
                .accessibilityHidden(true)

            HStack(alignment: .top, spacing: 9) {
                riskSummary(title: "Storm Risk", value: snapshot.stormRisk.label, tint: stormStyle.tint)
                riskSummary(title: "Severe Risk", value: snapshot.severeRisk.label, tint: severeStyle.tint)
                riskSummary(
                    title: "Fire Risk",
                    value: snapshot.fireRisk?.label ?? "--",
                    tint: snapshot.fireRisk.map { WidgetFireRiskVisualStyle.style(for: $0.severity).tint } ?? Color.secondary
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var contextRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("SkyAware")
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
            Text("·")
                .foregroundStyle(.tertiary)
            Text(location)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 2)
        }
    }

    private var accessibleContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.selectedAlert?.title ?? "No local alerts")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(isMaximumAccessibilitySize ? 3 : 2)
                .minimumScaleFactor(isMaximumAccessibilitySize ? 0.8 : 1)

            if !isMaximumAccessibilitySize {
                Text("Storm: \(snapshot.stormRisk.label) · Severe: \(snapshot.severeRisk.label) · Fire: \(snapshot.fireRisk?.label ?? "--")")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var primaryAwareness: some View {
        let title = snapshot.selectedAlert?.title ?? "No local alerts"
        let tint = alertStyle?.tint ?? (snapshot.stormRisk.severity > 0 ? stormStyle.tint : severeStyle.tint)
        let icon = alertStyle?.icon ?? (snapshot.stormRisk.severity > 0 ? stormStyle.icon : "checkmark.shield")

        return HStack(alignment: .center, spacing: 9) {
            Capsule()
                .fill(tint)
                .frame(width: 3)
                .accessibilityHidden(true)
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let subtitle = primarySubtitle {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if snapshot.hiddenAlertCount > 0 {
                Text("+\(snapshot.hiddenAlertCount) more")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var primarySubtitle: String? {
        if let alert = snapshot.selectedAlert {
            guard let issuedAt = alert.issuedAt else { return alert.typeLabel }
            if let end = alert.validEnd {
                return "\(alert.typeLabel) · Ends \(Self.relativeFormatter.localizedString(for: end, relativeTo: .now))"
            }
            return "\(alert.typeLabel) · Issued \(Self.relativeFormatter.localizedString(for: issuedAt, relativeTo: .now))"
        }
        return snapshot.stormRisk.severity > 0 ? "Storm risk remains elevated" : nil
    }

    private func riskSummary(title: String, value: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(tint)
                .frame(width: 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilitySummary: String {
        var parts = ["SkyAware", location]
        if let alert = snapshot.selectedAlert {
            parts.append("Alert \(alert.title)")
            if snapshot.hiddenAlertCount > 0 { parts.append("Plus \(snapshot.hiddenAlertCount) more alerts") }
        } else {
            parts.append("No local alerts")
            if let primarySubtitle { parts.append(primarySubtitle) }
        }
        parts.append("Storm Risk \(snapshot.stormRisk.label)")
        parts.append("Severe Risk \(snapshot.severeRisk.label)")
        parts.append("Fire Risk \(snapshot.fireRisk?.label ?? "unavailable")")
        if let visibleFreshnessLine { parts.append(visibleFreshnessLine) }
        return parts.joined(separator: ". ")
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
