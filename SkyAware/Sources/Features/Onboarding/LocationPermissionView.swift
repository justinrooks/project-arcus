//
//  LocationPermissionView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/22/25.
//

import SwiftUI

struct LocationPermissionView: View {
    let locationMgr: LocationManager
    let onContinue: () -> Void
//    @StateObject private var locationManager = LocationManager()
    
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
            
            Button(action: {
                locationMgr.checkLocationAuthorization(isActive: true)
                
                // Small delay to let permission dialog appear/dismiss, then continue

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onContinue()
                }
            }) {
                Text("Enable Location")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.skyAwareAccent)
                    )
            }
            .padding(.horizontal, 32)
            
            Button("Skip for Now") {
                onContinue()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .background(Color(.skyAwareBackground).ignoresSafeArea())
    }
}

#Preview {
    let provider = LocationProvider()
    let sink: LocationSink = { [provider] update in await provider.send(update: update) }
    let locationMgr = LocationManager(onUpdate: sink)
    
    LocationPermissionView(locationMgr: locationMgr) { }
}
