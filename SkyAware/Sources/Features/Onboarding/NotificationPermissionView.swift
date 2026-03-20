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
            
            Text("Stay Informed")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Get notified about:")
                .font(.body)
                .padding(.horizontal, 32)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sunrise.fill")
                        .foregroundColor(.skyAwareAccent)
                    Text("Morning weather summary")
                }
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.skyAwareAccent)
                    Text("Watches and mesoscale discussions issued for your location")
                }
            }
            .font(.body)
            .padding(.horizontal, 32)
            
            Spacer()

            if let statusMessage {
                ProgressView(statusMessage)
                    .font(.subheadline)
                    .tint(.skyAwareAccent)
            }

            Button(action: onEnable) {
                Text("Enable Notifications")
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
