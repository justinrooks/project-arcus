import SwiftUI

struct LocationReliabilitySummaryRailView: View {
    @Environment(\.colorScheme) private var colorScheme

    let onOpen: () -> Void
    let onDismiss: () -> Void

    private var background: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.orange.opacity(0.52),
                    Color.red.opacity(0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color.orange.opacity(0.35),
                Color.red.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    Image(systemName: "location.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Always")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("Get more reliable background severe-weather alerts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(
                SkyAwarePressableButtonStyle(
                    cornerRadius: SkyAwareRadius.large,
                    pressedScale: 0.985,
                    pressedOverlayOpacity: 0.08
                )
            )
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .accessibilityIdentifier("summary-reliability-rail")
            .accessibilityHint("Opens location reliability details.")

            Button {
                onDismiss()
            } label: {
                Text("Not Now")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .skyAwareChip(cornerRadius: SkyAwareRadius.chipCompact, tint: .white.opacity(0.10))
            }
            .buttonStyle(
                SkyAwarePressableButtonStyle(
                    cornerRadius: SkyAwareRadius.chipCompact,
                    pressedScale: 0.985,
                    pressedOverlayOpacity: 0.08
                )
            )
            .frame(minWidth: 44, minHeight: 44, alignment: .center)
            .accessibilityIdentifier("summary-reliability-not-now")
            .accessibilityHint("Dismisses this reliability prompt for today.")
        }
        .railStyle(background: background)
    }
}
