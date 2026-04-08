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
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "bell.fill")
                .font(.system(size: 80))
                .foregroundColor(.skyAwareAccent)
            
            Text("Stay Aware")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("You can allow notifications such as:")
                .font(.body)
                .padding(.horizontal, 32)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sunrise.fill")
                        .foregroundColor(.skyAwareAccent)
                    Text("A morning severe-weather summary")
                }
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.skyAwareAccent)
                    Text("Warnings, watches, and mesoscale discussions relevant to your location")
                }
            }
            .font(.body)
            .padding(.horizontal, 32)
            
            Text("Notifications are designed to help you stay aware of severe weather, but delivery timing may vary. SkyAware does not issue official warnings. Always rely on official alerts from the National Weather Service, NOAA Weather Radio, and local authorities for emergency information.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()

            if let statusMessage {
                ProgressView(statusMessage)
                    .font(.subheadline)
                    .tint(.skyAwareAccent)
            }

            Button(action: onEnable) {
                Text("Allow Notifications")
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
            
            Button("Skip for Now", action: onSkip)
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
    NotificationPermissionView(
        isWorking: false,
        statusMessage: nil,
        onEnable: {},
        onSkip: {}
    )
}
