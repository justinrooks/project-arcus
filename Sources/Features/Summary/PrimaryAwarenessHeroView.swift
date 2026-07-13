//
//  PrimaryAwarenessHeroView.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI

struct PrimaryAwarenessHeroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let primary: SummaryAwarenessPrimaryState
    let action: SummaryAwarenessDestination
    let onOpenMapLayer: (MapLayer) -> Void
    let onOpenAlerts: () -> Void

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        let contract = primary.accessibilityContract

        if action == .none {
            heroContent
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(contract.label)
                .accessibilityValue(contract.value)
        } else {
            Button {
                handle(action: action)
            } label: {
                heroContent
                    .contentShape(RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous))
                    .accessibilityHidden(true)
            }
            .buttonStyle(
                SkyAwarePressableButtonStyle(
                    cornerRadius: SkyAwareRadius.large,
                    pressedScale: 0.992,
                    pressedOverlayOpacity: 0.06
                )
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(contract.label)
            .accessibilityValue(contract.value)
            .accessibilityHintIfNeeded(contract.hint)
        }
    }

    private var heroContent: some View {
        let iconSize: CGFloat = adaptiveLayout.usesStackedHeroTiles ? 34 : 42
        let titleFont: Font = adaptiveLayout.usesStackedHeroTiles ? .headline.weight(.semibold) : .title3.weight(.semibold)
        let detailFont: Font = adaptiveLayout.usesStackedHeroTiles ? .subheadline : .subheadline

        return VStack(alignment: .leading, spacing: adaptiveLayout.usesStackedHeroTiles ? 10 : 12) {
            if adaptiveLayout.usesStackedHeroTiles {
                Image(systemName: primary.symbolName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(RiskBadgeVisualStyle.iconForeground(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: primary.symbolName)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(RiskBadgeVisualStyle.iconForeground(for: colorScheme))
                        .frame(width: 52, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(primary.title)
                            .font(titleFont)
                            .foregroundColor(RiskBadgeVisualStyle.messageForeground(for: colorScheme))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(primary.detail)
                            .font(detailFont)
                            .foregroundStyle(RiskBadgeVisualStyle.summaryForeground(for: colorScheme))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }

            if adaptiveLayout.usesStackedHeroTiles {
                VStack(alignment: .leading, spacing: 4) {
                    Text(primary.title)
                        .font(titleFont)
                        .foregroundColor(RiskBadgeVisualStyle.messageForeground(for: colorScheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(primary.detail)
                        .font(detailFont)
                        .foregroundStyle(RiskBadgeVisualStyle.summaryForeground(for: colorScheme))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                .fill(primary.background(for: colorScheme))
        )
        .overlay {
            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                .strokeBorder(.white.opacity(primary.isQuiet ? 0.10 : 0.16), lineWidth: 0.8)
                .allowsHitTesting(false)
        }
        .shadow(
            color: .black.opacity(primary.isQuiet ? 0.08 : 0.16),
            radius: primary.isQuiet ? 5 : 8,
            x: 0,
            y: primary.isQuiet ? 2 : 4
        )
        .animation(SkyAwareMotion.settle(reduceMotion), value: primary.title)
        .animation(SkyAwareMotion.settle(reduceMotion), value: primary.detail)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(primary.title)
        .accessibilityValue(primary.detail)
    }

    private func handle(action: SummaryAwarenessDestination) {
        switch action {
        case .alerts:
            onOpenAlerts()
        case .map(let layer):
            onOpenMapLayer(layer)
        case .none:
            break
        }
    }

}

private extension View {
    @ViewBuilder
    func accessibilityHintIfNeeded(_ hint: String?) -> some View {
        if let hint {
            accessibilityHint(hint)
        } else {
            self
        }
    }
}
