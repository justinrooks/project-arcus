//
//  AppRootView.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies
    
//    let spcProvider: SpcProvider
//    let nwsProvider: NwsProvider
//    let locationMgr: LocationManager
//    let locationProv: LocationProvider
    
    var body: some View {
        HomeView()
            .environment(\.riskQuery, dependencies.spcProvider)
            .environment(\.spcFreshness, dependencies.spcProvider)
            .environment(\.spcSync, dependencies.spcProvider)
            .environment(\.mapData, dependencies.spcProvider)
            .environment(\.outlookQuery, dependencies.spcProvider)
            .environment(\.nwsRiskQuery, dependencies.nwsProvider)
            .environment(\.nwsSyncing, dependencies.nwsProvider)
            .environment(\.locationClient, makeLocationClient(provider: dependencies.locationProvider))
            .task {
                dependencies.locationManager.checkLocationAuthorization(isActive: true)
                dependencies.locationManager.updateMode(for: scenePhase)
            }
    }
}
