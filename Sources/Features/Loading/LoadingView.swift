//
//  LoadingView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/12/25.
//

import SwiftUI

struct LoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var message: String = "Bringing in your conditions…"

    @State private var glowDrift = CGSize.zero
    @State private var glowOpacity: Double = 0.24
    @State private var glowPulseOpacity: Double = 0.74
    @State private var glowPulseScale: CGFloat = 1.0
    @State private var ghostOpacity: Double = 0.58

    var body: some View {
        ZStack {
            atmosphericBackground
            summaryGhost

            VStack(spacing: 10) {
                Text("Getting your conditions ready")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.96))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .padding(.horizontal, 18)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.08), radius: 6, x: 0, y: 3)
        }
        .frame(maxWidth: .infinity, minHeight: 500)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .clipShape(RoundedRectangle(cornerRadius: SkyAwareRadius.hero, style: .continuous))
        .transition(.opacity)
        .animation(SkyAwareMotion.message(reduceMotion), value: message)
        .task(id: reduceMotion) {
            guard reduceMotion == false else {
                glowDrift = .zero
                glowOpacity = 0.24
                glowPulseOpacity = 0.74
                glowPulseScale = 1
                ghostOpacity = 0.58
                return
            }

            withAnimation(
                .easeInOut(duration: SkyAwareMotion.ambientDriftDuration)
                    .repeatForever(autoreverses: true)
            ) {
                glowDrift = CGSize(width: 6, height: -5)
                glowOpacity = 0.30
                ghostOpacity = 0.62
            }

            withAnimation(
                .easeInOut(duration: SkyAwareMotion.ambientPulseDuration)
                    .repeatForever(autoreverses: true)
            ) {
                glowPulseOpacity = 0.88
                glowPulseScale = 1.07
            }
        }
    }

    private var atmosphericBackground: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color(red: 0.045, green: 0.074, blue: 0.118),
                        Color(red: 0.060, green: 0.091, blue: 0.142),
                        Color(red: 0.032, green: 0.050, blue: 0.082)
                    ]
                    : [
                        Color(red: 0.955, green: 0.972, blue: 0.995),
                        Color(red: 0.930, green: 0.955, blue: 0.990),
                        Color(red: 0.905, green: 0.934, blue: 0.978)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.skyAwareAccent.opacity(glowOpacity * (colorScheme == .dark ? 1.05 : 0.54)),
                    Color.skyAwareAccent.opacity(glowOpacity * (colorScheme == .dark ? 0.44 : 0.24)),
                    .clear
                ],
                center: UnitPoint(x: 0.80 + glowDrift.width / 120, y: 0.24 + glowDrift.height / 120),
                startRadius: 8,
                endRadius: colorScheme == .dark ? 260 : 220
            )
            .opacity(glowPulseOpacity)
            .scaleEffect(glowPulseScale)

            LinearGradient(
                colors: [
                    .white.opacity(colorScheme == .dark ? 0.07 : 0.30),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
        }
        .overlay {
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(colorScheme == .dark ? 0.16 : 0.04)
                ],
                startPoint: .center,
                endPoint: .bottomTrailing
            )
        }
    }

    private var summaryGhost: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: SkyAwareRadius.section, style: .continuous)
                .fill(.white.opacity(colorScheme == .dark ? 0.10 : 0.22))
                .frame(height: 72)

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                    .fill(.white.opacity(colorScheme == .dark ? 0.10 : 0.21))
                    .frame(height: 126)
                RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                    .fill(.white.opacity(colorScheme == .dark ? 0.09 : 0.18))
                    .frame(height: 126)
            }

            RoundedRectangle(cornerRadius: SkyAwareRadius.row, style: .continuous)
                .fill(.white.opacity(colorScheme == .dark ? 0.09 : 0.19))
                .frame(height: 70)

            RoundedRectangle(cornerRadius: SkyAwareRadius.card, style: .continuous)
                .fill(.white.opacity(colorScheme == .dark ? 0.09 : 0.17))
                .frame(height: 110)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 28)
        .blur(radius: colorScheme == .dark ? 14 : 10)
        .opacity(ghostOpacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    LoadingView(message: "Bringing in local conditions…")
        .padding(.horizontal, 16)
        .background(.skyAwareBackground)
}

#Preview("Dark") {
    LoadingView(message: "Bringing in local conditions…")
        .padding(.horizontal, 16)
        .background(.skyAwareBackground)
        .preferredColorScheme(.dark)
}

#Preview("Reduce Motion (Name Only)") {
    LoadingView(message: "Bringing in local conditions…")
        .padding(.horizontal, 16)
        .background(.skyAwareBackground)
}
