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
                title: "Better Awareness When You’re Not Here",
                subtitle: "Optional background location"
            )

            Text("Allowing Always location access lets SkyAware refresh your location when the app isn’t open, helping keep local severe-weather information relevant as you move.")
                .font(.body)
                .multilineTextAlignment(.center)

            OnboardingInformationCard(
                symbol: "bell",
                title: "Stay up to date",
                detail: "Background location can help refresh relevant local information. iOS controls when background work runs, so alerts and refreshes aren’t guaranteed."
            )

            Text("You can continue without this access and change your choice later in Settings.")
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
                    Text("Enable Background Location")
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
