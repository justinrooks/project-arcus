//
//  OnboardingAlwaysUpgradeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 4/29/26.
//

import SwiftUI

struct OnboardingAlwaysUpgradeView: View {
    let isWorking: Bool
    let statusMessage: String?
    let onEnableAlways: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingStepShell {
            OnboardingStepHeading(
                symbol: "location.circle.fill",
                title: "Background Awareness",
                subtitle: "An optional location upgrade"
            )

            Text("SkyAware can keep severe-weather alerts current when it can refresh your location in the background.")
                .font(.body)
                .multilineTextAlignment(.center)

            Text("Enable Always to help keep alerts current. You can continue now and change this later in Settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        } footer: {
            VStack(spacing: 12) {
                if let statusMessage {
                    ProgressView(statusMessage)
                        .font(.subheadline)
                        .tint(.skyAwareAccent)
                }

                Button(action: onEnableAlways) {
                    Text("Enable Always")
                }
                .buttonStyle(OnboardingPrimaryActionStyle())
                .disabled(isWorking)

                Button("Not Now", action: onSkip)
                    .buttonStyle(OnboardingSecondaryActionStyle())
                    .disabled(isWorking)
            }
        }
    }
}

#Preview {
    OnboardingAlwaysUpgradeView(
        isWorking: false,
        statusMessage: nil,
        onEnableAlways: {},
        onSkip: {}
    )
}

private struct OnboardingAlwaysUpgradeViewAX5Preview: PreviewProvider {
    static var previews: some View {
        OnboardingAlwaysUpgradeView(
            isWorking: false,
            statusMessage: nil,
            onEnableAlways: {},
            onSkip: {}
        )
        .previewDevice("iPhone SE (3rd generation)")
        .environment(\.dynamicTypeSize, .accessibility5)
    }
}
