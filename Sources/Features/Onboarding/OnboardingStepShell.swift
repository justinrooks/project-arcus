//
//  OnboardingStepShell.swift
//  SkyAware
//
//  Created by Codex on 6/11/26.
//

import SwiftUI

struct OnboardingStepShell<Content: View, Footer: View>: View {
    private let footerBottomClearance: CGFloat = 20
    private let content: Content
    private let footer: Footer

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                content
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, footerBottomClearance)
                .background(Color(.skyAwareBackground))
        }
        .background(Color(.skyAwareBackground).ignoresSafeArea())
    }
}

struct OnboardingStepHeading: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    var symbolSize: CGFloat = 48

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(Color.skyAwareAccent)
                .accessibilityHidden(true)

            Text(title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct OnboardingPrimaryActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(RoundedRectangle(cornerRadius: SkyAwareRadius.chip, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: SkyAwareRadius.chip, style: .continuous)
                    .fill(
                        isEnabled
                            ? Color.skyAwareAccent.opacity(configuration.isPressed ? 0.82 : 1)
                            : Color.secondary.opacity(0.18)
                    )
            }
            .foregroundStyle(isEnabled ? Color.white : Color.secondary)
    }
}

struct OnboardingSecondaryActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(isEnabled
                ? Color.skyAwareAccent.opacity(configuration.isPressed ? 0.7 : 1)
                : Color.secondary
            )
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
    }
}

struct OnboardingStepProgress: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(step.progressTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                ForEach(1...OnboardingStep.requiredStageCount, id: \.self) { stage in
                    Capsule()
                        .fill(stage <= step.requiredStage ? Color.skyAwareAccent : Color.secondary.opacity(0.2))
                        .frame(height: 4)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(.skyAwareBackground))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(step.progressAccessibilityLabel)
    }
}
