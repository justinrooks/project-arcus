//
//  WelcomeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/23/25.
//

import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepShell {
            Image("LaunchCyclone")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 76, height: 76)
                .foregroundStyle(Color.skyAwareAccent)
                .accessibilityHidden(true)

            Text("Welcome to SkyAware")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            Text("How weather-aware do you need to be today? SkyAware helps you understand local severe-weather risk at a glance.")
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)

            Text("Get simple, actionable severe-weather awareness based on authoritative public data from the SPC and National Weather Service.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        } footer: {
            Button(action: onContinue) {
                Text("Get Started")
            }
            .buttonStyle(OnboardingPrimaryActionStyle())
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
