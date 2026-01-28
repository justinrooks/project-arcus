//
//  NotificationPermissionView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/22/25.
//

import SwiftUI
import OSLog

struct NotificationPermissionView: View {
    let onComplete: () -> Void
    private let logger = Logger.uiOnboarding
    
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
            
            // TODO: Adapt this code to use here, and helpfully navigate to the settings
            //            .alert("Location Permission Needed",
            //                   isPresented: $showLocationPermissionAlert) {
            //                Button("Settings") { locationMgr.openSettings() }
            //                Button("Cancel", role: .cancel) {}
            //            } message: {
            //                Text("Enable location to see nearby weather risks and alerts.")
            //            }
            //showLocationPermissionAlert = (locationMgr.authStatus == .denied || locationMgr.authStatus == .restricted)
            
            Button(action: {
                requestNotificationPermission()
                // Small delay, then complete onboarding
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }) {
                Text("Enable Notifications")
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
                onComplete()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .background(Color.skyAwareBackground.ignoresSafeArea())
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                logger.error("Notification permission error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

#Preview {
    NotificationPermissionView() { }
}
