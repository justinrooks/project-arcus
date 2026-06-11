//
//  WelcomeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/23/25.
//

import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    @ScaledMetric(relativeTo: .largeTitle)
    private var symbolSize: CGFloat = 96

    var body: some View {
        OnboardingStepShell {
            Image(systemName: "cloud.bolt.fill")
                .font(.system(size: symbolSize))
                .foregroundColor(.skyAwareAccent)
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    Color.skyAwareAccent,
                    Color.skyAwareAccent.opacity(0.5)
                )

            Text("Welcome to SkyAware")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("How weather-aware do you need to be today? SkyAware helps you understand local severe-weather risk at a glance.")
                .font(.title3)
                .multilineTextAlignment(.center)

            Text("Get simple, actionable severe-weather awareness based on authoritative public data from the SPC and National Weather Service.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        } footer: {
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: SkyAwareRadius.chip)
                            .fill(Color.skyAwareAccent)
                    )
            }
        }
    }
}

#Preview {
    WelcomeView() { }
}

private struct WelcomeViewAX5Preview: PreviewProvider {
    static var previews: some View {
        WelcomeView() { }
            .previewDevice("iPhone SE (3rd generation)")
            .environment(\.dynamicTypeSize, .accessibility5)
    }
}
