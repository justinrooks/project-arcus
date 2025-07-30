//
//  iPhoneHomeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import SwiftData

struct iPhoneHomeView: View {
    //    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var provider: SpcProvider
    @EnvironmentObject private var pointsProvider: PointsProvider
    @EnvironmentObject private var locationProvider: LocationManager
    
    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()
            if provider.isLoading {
                VStack {
                    Spacer()
                    LoadingView(message: "Fetching SPC data...")
                    Spacer()
                }
                .transition(.opacity)
                .animation(.easeInOut, value: provider.isLoading)
            } else {
                TabView {
                    NavigationStack {
                        SummaryView(pointsProvider: pointsProvider, locationProvider: locationProvider)
                    }
                    .tabItem {
                        Image(systemName: "circle.grid.cross.fill") //sunrise.fill
                        Text("Summary")
                    }
                    
                    NavigationStack {
                        AlertView()
                    }    .tabItem {
                        Image(systemName: "exclamationmark.bubble") //umbrella
                        Text("Alerts")
                    }.badge(provider.alertCount)
                    
                    MapView()
                        .tabItem {
                            Image(systemName: "map")
                            Text("Map")
                        }
                    NavigationStack {
                        ForecastView()
                    }
                    .tabItem {
                        Image(systemName: "cloud.sun") //cloud.bolt.rain.fill
                        Text("Forecast")
                    }
                    NavigationStack {
                        SettingsView()
                    }
                    .tabItem {
                        Image(systemName: "gear") //exclamationmark.triangle
                        Text("Settings")
                    }
                }
            }
        }
        .accentColor(.teal)
    }
}

#Preview {
    iPhoneHomeView()
        .environmentObject(SpcProvider())
        .environmentObject(PointsProvider())
        .environmentObject(LocationManager())
    //        .modelContainer(for: ItemTest.self, inMemory: true)
    //        .environment()
}
