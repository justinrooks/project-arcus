//
//  AppRootView.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    let spcProvider: SpcProvider
    let locationMgr: LocationManager
    let locationProv: LocationProvider
    
    var body: some View {
        HomeView()
            .environment(\.riskQuery, spcProvider)
            .environment(\.spcFreshness, spcProvider)
            .environment(\.spcSync, spcProvider)
            .environment(\.mapData, spcProvider)
            .environment(\.outlookQuery, spcProvider)
            .environment(\.locationClient, makeLocationClient(provider: locationProv))
            .task {
                locationMgr.checkLocationAuthorization(isActive: true)
                locationMgr.updateMode(for: scenePhase)
            }
    }
}
