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
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge.waveform.fill")
                .font(.system(size: 80))
                .foregroundColor(.skyAwareAccent)

            Text("More Reliable Alerts")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("SkyAware can send more reliable severe-weather alerts when it can refresh your location in the background.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("Enable Always to improve background alert reliability. You can continue now and change this later in Settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

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
            .padding(.horizontal, 32)
            .disabled(isWorking)

            Button("Not Now", action: onSkip)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .disabled(isWorking)

            Spacer()
        }
        .padding()
        .background(Color(.skyAwareBackground).ignoresSafeArea())
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
