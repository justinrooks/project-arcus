//
//  NotificationPermissionView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/22/25.
//

import SwiftUI

struct NotificationPermissionView: View {
    let isWorking: Bool
    let statusMessage: String?
    let onEnable: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingStepShell {
            OnboardingStepHeading(
                symbol: "bell.fill",
                title: "Stay Aware"
            )

            Text("You can allow notifications such as:")
                .font(.body)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sunrise.fill")
                        .foregroundColor(.skyAwareAccent)
                    Text("A morning severe-weather summary")
                }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.skyAwareAccent)
                    Text("Warnings, watches, and mesoscale discussion alerts relevant to your location")
                }
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Notifications are designed to help you stay aware of severe weather, but delivery timing may vary. SkyAware does not issue official warnings. Always rely on official alerts from the National Weather Service, NOAA Weather Radio, and local authorities for emergency information.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        } footer: {
            VStack(spacing: 12) {
                if let statusMessage {
                    ProgressView(statusMessage)
                        .font(.subheadline)
                        .tint(.skyAwareAccent)
                }

                Button(action: onEnable) {
                    Text("Allow Notifications")
                }
                .buttonStyle(OnboardingPrimaryActionStyle())
                .disabled(isWorking)

                Button("Skip for Now", action: onSkip)
                    .buttonStyle(OnboardingSecondaryActionStyle())
                    .disabled(isWorking)
            }
        }
    }
}

#Preview {
    NotificationPermissionView(
        isWorking: false,
        statusMessage: nil,
        onEnable: {},
        onSkip: {}
    )
}

private struct NotificationPermissionViewAX5Preview: PreviewProvider {
    static var previews: some View {
        NotificationPermissionView(
            isWorking: false,
            statusMessage: nil,
            onEnable: {},
            onSkip: {}
        )
        .previewDevice("iPhone SE (3rd generation)")
        .environment(\.dynamicTypeSize, .accessibility5)
    }
}
