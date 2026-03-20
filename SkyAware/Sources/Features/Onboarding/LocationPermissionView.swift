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
            
            Text("SkyAware needs your location to provide accurate severe weather alerts for your area.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Text("Your location data stays on your device and is never shared or tracked.")
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
