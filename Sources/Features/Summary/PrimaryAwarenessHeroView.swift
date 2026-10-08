//
//  PrimaryAwarenessHeroView.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI

struct PrimaryAwarenessHeroView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .title2) private var iconColumnWidth: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var chevronClearance: CGFloat = 16
    private let heroColumnSpacing: CGFloat = 14

    let primary: SummaryAwarenessPrimaryState
    let action: SummaryAwarenessDestination
    var showsSemanticTint: Bool = true
    let onOpenMapLayer: (MapLayer) -> Void
    let onOpenAlerts: () -> Void

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    private var heroLayout: AnyLayout {
        adaptiveLayout.usesStackedHeroTiles
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: heroColumnSpacing))
    }

    var body: some View {
        let contract = primary.accessibilityContract

        if action == .none {
            heroContent
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(contract.label)
                .accessibilityValue(contract.value)
                .accessibilityIdentifier("summary-primary-awareness")
        } else {
            Button {
                handle(action: action)
            } label: {
                heroContent
                    .contentShape(RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous))
            }
            .buttonStyle(
                SkyAwarePressableButtonStyle(
                    cornerRadius: SkyAwareRadius.large,
                    pressedScale: 0.992,
                    pressedOverlayOpacity: 0.06
                )
            )
            .accessibilityLabel(contract.label)
            .accessibilityValue(contract.value)
            .accessibilityHintIfNeeded(contract.hint)
            .accessibilityIdentifier("summary-primary-awareness")
        }
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let timing = alertTiming {
                timingRow(timing)
            }

            heroLayout {
                Image(systemName: primary.symbolName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .padding(.leading, 11)
                    .frame(width: iconColumnWidth, alignment: .leading)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(primary.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(primary.detail)
                        .font(.subheadline)
                        .todaySupportingText()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.trailing, action == .none ? 0 : chevronClearance)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .trailing) {
                    if action != .none {
                        AwarenessNavigationChevron(accent: accentColor)
                    }
                }
            }

            if let instruction = alertInstruction {
                Rectangle()
                    .fill(.separator.opacity(0.55))
                    .frame(height: 0.5)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("GUIDANCE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    Text(instruction)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, adaptiveLayout.usesStackedHeroTiles ? 0 : iconColumnWidth + heroColumnSpacing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                .fill(colorScheme == .dark ? Color.cardBackground : TodaySurfaceStyle.content(for: colorScheme))
                .overlay {
                    if showsSemanticTint, primary.source != .loading {
                        AwarenessSemanticTint(accent: accentColor, isQuiet: primary.isQuiet, isHero: true)
                    }
                }
        }
        .overlay(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(accentColor)
                .frame(width: 4)
                .padding(.vertical, 16)
                .padding(.leading, 12)
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                .strokeBorder(
                    isAlert
                        ? accentColor.opacity(colorScheme == .dark ? 0.48 : 0.38)
                        : .primary.opacity(colorScheme == .dark ? 0.08 : (colorSchemeContrast == .increased ? 0.14 : 0.06)),
                    lineWidth: isAlert ? 1 : (colorScheme == .dark ? 0.7 : (colorSchemeContrast == .increased ? 1 : 0.5))
                )
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func timingRow(_ timing: String) -> some View {
        if adaptiveLayout.usesStackedHeroTiles {
            timingText(timing)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Spacer(minLength: 4)
                timingText(timing)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func timingText(_ timing: String) -> some View {
        Text(timing)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var isAlert: Bool {
        if case .alert = primary { return true }
        return false
    }

    private var alertTiming: String? {
        guard case let .alert(_, _, timing, _) = primary else { return nil }
        return timing
    }

    private var alertInstruction: String? {
        guard case let .alert(_, _, _, instruction) = primary else { return nil }
        return instruction
    }

    private var accentColor: Color {
        primary.accentColor
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

// Local to the four awareness surfaces; the opaque card fill remains underneath.
struct AwarenessSemanticTint: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.self) private var environment

    let accent: Color
    let isQuiet: Bool
    var isHero: Bool = false

    private var strength: Double {
        if isQuiet {
            return colorScheme == .dark ? (isHero ? 0.24 : 0.18) : (isHero ? 0.20 : 0.15)
        }
        return colorScheme == .dark ? (isHero ? 0.20 : 0.14) : (isHero ? 0.22 : 0.16)
    }

    private var tint: Color {
        guard isQuiet else { return accent }
        let resolved = accent.resolve(in: environment)
        // Resolved components are linear sRGB. Increase quiet-background chroma toward jade
        // without changing the semantic rail, icon, or navigation accent.
        return Color(
            .sRGBLinear,
            red: Double(resolved.red) * 0.10,
            green: Double(resolved.green),
            blue: Double(resolved.blue) * 1.05
        )
    }

    var body: some View {
        LinearGradient(
            stops: isQuiet ? [
                .init(color: tint.opacity(strength), location: 0),
                .init(color: tint.opacity(strength * 0.55), location: 0.24),
                .init(color: tint.opacity(strength * 0.32), location: 0.45),
                .init(color: tint.opacity(strength * 0.15), location: 0.65),
                .init(color: tint.opacity(strength * 0.055), location: 0.82),
                .init(color: tint.opacity(strength * 0.012), location: 0.94),
                .init(color: tint.opacity(0), location: 1)
            ] : [
                .init(color: tint.opacity(strength), location: 0),
                .init(color: tint.opacity(strength * 0.5), location: colorScheme == .dark ? 0.35 : 0.28),
                .init(color: tint.opacity(0), location: colorScheme == .dark ? 0.85 : 0.72)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct AwarenessNavigationChevron: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let accent: Color

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent.mix(
                with: colorScheme == .dark ? .white : .black,
                by: colorScheme == .dark
                    ? (colorSchemeContrast == .increased ? 0.18 : 0.08)
                    : (colorSchemeContrast == .increased ? 0.42 : 0.32)
            ))
            .fixedSize()
            .accessibilityHidden(true)
    }
}
