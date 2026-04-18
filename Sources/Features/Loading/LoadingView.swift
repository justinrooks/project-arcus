//
//  LoadingView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/12/25.
//

import SwiftUI

struct LoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var message: String = "Checking current conditions..."

    @State private var glowDrift = CGSize.zero
    @State private var glowOpacity: Double = 0.18
    @State private var glowPulseOpacity: Double = 0.72
    @State private var glowPulseScale: CGFloat = 0.98
    @State private var ghostOpacity: Double = 0.32

    var body: some View {
        ZStack(alignment: .top) {
            summaryGhost

            VStack(spacing: 14) {
                ZStack {
                    UnevenRoundedRectangle(
                        cornerRadii: .init(
                            topLeading: 38,
                            bottomLeading: 30,
                            bottomTrailing: 42,
                            topTrailing: 34
                        ),
                        style: .continuous
                    )
                        .fill(Color.skyAwareAccent.opacity(glowOpacity))
                        .frame(width: 112, height: 96)
                        .blur(radius: 34)
                        .scaleEffect(glowPulseScale)
                        .opacity(glowPulseOpacity)
                        .offset(x: -6 + glowDrift.width, y: 4 + glowDrift.height)
                        .rotationEffect(.degrees(-8))

                    Ellipse()
                        .fill(Color.skyAwareAccent.opacity(glowOpacity * 0.55))
                        .frame(width: 84, height: 66)
                        .blur(radius: 30)
                        .scaleEffect(glowPulseScale * 1.01)
                        .opacity(glowPulseOpacity)
                        .offset(x: 10 - (glowDrift.width * 0.7), y: -6 - (glowDrift.height * 0.7))
                        .rotationEffect(.degrees(12))

                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 50, height: 50)

                    Image(systemName: "cloud.sun.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.skyAwareAccent)
                }

                VStack(spacing: 6) {
                    Text("Getting your conditions ready")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.9))

                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 36)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .transition(.opacity)
        .animation(SkyAwareMotion.message(reduceMotion), value: message)
        .task(id: reduceMotion) {
            guard reduceMotion == false else {
                glowDrift = .zero
                glowOpacity = 0.18
                glowPulseOpacity = 0.72
                glowPulseScale = 1
                ghostOpacity = 0.32
                return
            }

            withAnimation(
                .easeInOut(duration: SkyAwareMotion.ambientDriftDuration)
                    .repeatForever(autoreverses: true)
            ) {
                glowDrift = CGSize(width: 4, height: -3)
                glowOpacity = 0.22
                ghostOpacity = 0.37
            }

            withAnimation(
                .easeInOut(duration: SkyAwareMotion.ambientPulseDuration)
                    .repeatForever(autoreverses: true)
            ) {
                glowPulseOpacity = 0.88
                glowPulseScale = 1.03
            }
        }
    }

    private var summaryGhost: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: SkyAwareRadius.section, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(height: 78)

            RoundedRectangle(cornerRadius: SkyAwareRadius.hero, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(height: 332)
                .overlay(alignment: .top) {
                    VStack(spacing: 16) {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 160)
                            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 160)
                        }

                        RoundedRectangle(cornerRadius: SkyAwareRadius.row, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 76)

                        RoundedRectangle(cornerRadius: SkyAwareRadius.card, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 150)
                    }
                    .padding(18)
                }

            RoundedRectangle(cornerRadius: SkyAwareRadius.card, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(height: 128)
        }
        .blur(radius: 8)
        .opacity(ghostOpacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    LoadingView(message: "Checking current conditions...")
        .padding(.horizontal, 16)
        .background(.skyAwareBackground)
}
