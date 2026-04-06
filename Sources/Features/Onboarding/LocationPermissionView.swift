//
//  LocationPermissionView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/22/25.
//

import SwiftUI

struct LocationPermissionView: View {
    let isWorking: Bool
    let statusMessage: String?
    let onEnable: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "location.fill")
                .font(.system(size: 80))
                .foregroundColor(.skyAwareAccent)
            
            Text("Location Access")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("SkyAware uses your location to determine relevant severe-weather risk and nearby weather events for your area.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("To support timely location-based notifications, SkyAware may send derived location information such as your county, fire zone, and a coarse geographic index to the server.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("SkyAware does not sell your data, use it for advertising, or track you across apps or websites.")
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
            Button(action: onEnable) {
                Text("Enable Location")
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
    LocationPermissionView(
        isWorking: false,
        statusMessage: nil,
        onEnable: {},
        onSkip: {}
    )
}
