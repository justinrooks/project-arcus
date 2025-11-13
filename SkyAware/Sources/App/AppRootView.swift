//
//  AppRootView.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import SwiftUI

struct AppRootView: View {
    // EnvVars
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showLocationPermissionAlert = false
    
    let spcProvider: SpcProvider
    let locationMgr: LocationManager
    let locationProv: LocationProvider
    
    var body: some View {
//        RoundedRectangle(cornerRadius: 12)
//                    .fill(Color("Background"))
//                    .frame(height: 80)
//                    .overlay(Text("Background").bold())
//                    .padding()
        HomeView()
            .environment(\.riskQuery, spcProvider)
            .environment(\.spcFreshness, spcProvider)
            .environment(\.spcSync, spcProvider)
            .environment(\.mapData, spcProvider)
            .environment(\.outlookQuery, spcProvider)
            .environment(\.locationClient, makeLocationClient(provider: locationProv))
            .alert("Location Permission Needed",
                   isPresented: $showLocationPermissionAlert) {
                Button("Settings") { locationMgr.openSettings() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable location to see nearby weather risks and alerts.")
            }
            .task {
//                if isPreview { return }
                locationMgr.checkLocationAuthorization(isActive: true)
                locationMgr.updateMode(for: scenePhase)
                
                showLocationPermissionAlert = (locationMgr.authStatus == .denied || locationMgr.authStatus == .restricted)
            }
    }
}

//#Preview {
//    AppRootView()
//}
