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

    @ScaledMetric(relativeTo: .largeTitle)
    private var symbolSize: CGFloat = 80

    var body: some View {
        OnboardingStepShell {
            Image(systemName: "bell.badge.waveform.fill")
                .font(.system(size: symbolSize))
                .foregroundColor(.skyAwareAccent)

            Text("More Reliable Alerts")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("SkyAware can send more reliable severe-weather alerts when it can refresh your location in the background.")
                .font(.body)
                .multilineTextAlignment(.center)

            Text("Enable Always to improve background alert reliability. You can continue now and change this later in Settings.")
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
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: SkyAwareRadius.chip)
                                .fill(Color.skyAwareAccent)
                        )
                }
                .disabled(isWorking)

                Button("Not Now", action: onSkip)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
