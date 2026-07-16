//
//  LaunchSplashView.swift
//  SkyAware
//

import SwiftUI

struct LaunchSplashContainer<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSplashPresented = true

    @ViewBuilder let content: Content

    var body: some View {
        content
            .overlay {
                if isSplashPresented {
                    LaunchSplashView()
                        .transition(splashTransition)
                }
            }
            .task {
                guard isSplashPresented else { return }

                await Task.yield()
                withAnimation(SkyAwareMotion.settle(reduceMotion)) {
                    isSplashPresented = false
                }
            }
    }

    private var splashTransition: AnyTransition {
        .asymmetric(
            insertion: .identity,
            removal: reduceMotion
                ? .opacity
                : .scale(scale: 1.02).combined(with: .opacity)
        )
    }
}

struct LaunchSplashView: View {
    private static let markSize: CGFloat = 116

    var body: some View {
        ZStack {
            Color.launchBackground
                .ignoresSafeArea()

            Image(decorative: "LaunchCyclone")
                .resizable()
                .scaledToFit()
                .frame(width: Self.markSize, height: Self.markSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Launch Splash") {
    LaunchSplashView()
}

#Preview("Launch Splash — Dark") {
    LaunchSplashView()
        .preferredColorScheme(.dark)
}
