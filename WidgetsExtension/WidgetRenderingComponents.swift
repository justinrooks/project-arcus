import SwiftUI
import WidgetKit

struct WidgetSmallRiskAwareness: View {
    let title: String
    let state: WidgetRiskDisplayState
    let kind: WidgetRiskKind
    let supportingSummary: String?
    var isUnavailable: Bool = false
    private var style: WidgetRiskVisualStyle {
        if isUnavailable {
            return WidgetRiskVisualStyle(icon: "location.slash", tint: .secondary, chip: .clear)
        }
        return WidgetRiskVisualStyle.style(for: kind, severity: state.severity)
    }

    private var primaryLabel: String {
        isUnavailable ? "Risk Unavailable" : state.label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SkyAware")
                .font(.caption.weight(.bold))
                .dynamicTypeSize(...DynamicTypeSize.large)
                .foregroundStyle(.primary)

            HStack(alignment: .top, spacing: 12) {
                Capsule()
                    .fill(style.tint)
                    .frame(width: 4)
                    .accessibilityHidden(true)

                ViewThatFits(in: .vertical) {
                    awareness(showsSummary: true)
                    awareness(showsSummary: false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.vertical, 5)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func awareness(showsSummary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: style.icon)
                .font(.largeTitle.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.large)
                .foregroundStyle(style.tint)
                .frame(width: 36, height: 38, alignment: .topLeading)
                .padding(.bottom, 10)
                .accessibilityHidden(true)

            WidgetRiskWordWrapLayout {
                ForEach(primaryLabel.split(separator: " "), id: \.self) { word in
                    Text(String(word))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .font(.headline.weight(.bold))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .foregroundStyle(.primary)

            if showsSummary, let supportingSummary {
                Text(supportingSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilitySummary: String {
        var parts = [title, primaryLabel]
        if let supportingSummary { parts.append(supportingSummary) }
        return parts.joined(separator: ". ")
    }
}

// Keep weather terms intact and wrap the primary state only between complete words.
private struct WidgetRiskWordWrapLayout: Layout {
    private func arrangement(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width.isFinite ? width : nil, height: nil))
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight
                lineHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + 5
            lineHeight = max(lineHeight, size.height)
        }
        return (CGSize(width: usedWidth, height: y + lineHeight), origins)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let origins = arrangement(width: bounds.width, subviews: subviews).origins
        for (subview, origin) in zip(subviews, origins) {
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: ProposedViewSize(
                    width: min(bounds.width, subview.sizeThatFits(.unspecified).width),
                    height: nil
                )
            )
        }
    }
}

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
