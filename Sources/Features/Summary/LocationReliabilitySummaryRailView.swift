import SwiftUI

struct LocationReliabilitySummaryRailView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Group {
            if usesAccessibilityLayout {
                accessibilityContent
            } else {
                compactContent
            }
        }
        .padding(14)
        .todayCardBackground(
            cornerRadius: SkyAwareRadius.card,
            darkShadowOpacity: 0.04,
            darkShadowRadius: 4,
            darkShadowY: 1
        )
    }

    private var compactContent: some View {
        HStack(spacing: 10) {
            openButton
            dismissButton
        }
    }

    private var accessibilityContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            openButton

            HStack {
                Spacer(minLength: 0)
                dismissButton
            }
        }
    }

    private var openButton: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "location.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Always")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(usesAccessibilityLayout ? nil : 1)
                    Text("Get more reliable background severe-weather alerts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(usesAccessibilityLayout ? nil : 2)
                }
                .fixedSize(horizontal: false, vertical: usesAccessibilityLayout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityIdentifier("summary-reliability-rail")
        .accessibilityHint("Opens location reliability details.")
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Text("Not Now")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44, alignment: .center)
        .accessibilityIdentifier("summary-reliability-not-now")
        .accessibilityHint("Dismisses this reliability prompt for today.")
    }

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }
}
