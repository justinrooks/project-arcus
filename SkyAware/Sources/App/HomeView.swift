//
//  HomeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies

    #warning("TODO: Remove swift data and call the repo properly")
    @Query private var mesos: [MD]
    @Query private var watches: [Watch]
    
    var body: some View {
        ZStack {
            Color(.skyAwareBackground).ignoresSafeArea()
            TabView {
                NavigationStack {
                    SummaryView()
                        .toolbar(.hidden, for: .navigationBar)
                        .background(.skyAwareBackground)
                }
                .tabItem { Label("Today", systemImage: "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted")
//                    "clock.arrow.trianglehead.2.counterclockwise.rotate.90") //gauge.with.needle.fill
                }
                
                NavigationStack {
                    AlertView()
                        .navigationTitle("Active Alerts")
                        .navigationBarTitleDisplayMode(.inline)
            //            .toolbarBackground(.visible, for: .navigationBar)      // <- non-translucent
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                        .scrollContentBackground(.hidden)
                        .background(.skyAwareBackground)
                }
                .tabItem { Label("Alerts", systemImage: "exclamationmark.triangle") }//umbrella
                    .badge(mesos.count + watches.count)
                
                MapView()
                    .toolbar(.hidden, for: .navigationBar)
                    .background(.skyAwareBackground)
                    .tabItem { Label("Map", systemImage: "map") }
                
                NavigationStack {
                    ConvectiveOutlookView()
                        .navigationTitle("Convective Outlooks")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                        .scrollContentBackground(.hidden)
                        .background(.skyAwareBackground)
                }
                .tabItem { Label("Outlooks", systemImage: "list.clipboard.fill") }
                
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Background Health")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                        .scrollContentBackground(.hidden)
                        .background(.skyAwareBackground)
                }
                .tabItem {Label("Settings", systemImage: "gearshape")}
            
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .transition(.opacity)
        .tint(.skyAwareAccent)
        .task {
            dependencies.locationManager.checkLocationAuthorization(isActive: true)
            dependencies.locationManager.updateMode(for: scenePhase)
        }
    }
}

// MARK: Preview
#Preview("Home") {
    HomeView()
}
