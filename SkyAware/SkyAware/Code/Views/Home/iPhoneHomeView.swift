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
    @Environment(SpcProvider.self) private var provider: SpcProvider
    @Environment(LocationManager.self) private var locationProvider: LocationManager
    
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
            } else {
                TabView {
                    NavigationStack {
                        ScrollView{
                            SummaryView(provider: provider, locationProvider: locationProvider)
                        }
                        .refreshable {
                            print("Refreshing data...")
                            fetchSpcData()
                        }
                    }
                    .tabItem {
                        Image(systemName: "circle.grid.cross.fill") //sunrise.fill
                        Text("Summary")
                    }
                    
                    NavigationStack {
                        AlertView()
                    }
                    .tabItem {
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
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.5), value: provider.isLoading)
        .accentColor(.teal)
    }
}

extension iPhoneHomeView {
    func fetchSpcData() {
        provider.loadFeed()
        
        print("Got SPC Feed data")
    }
}

#Preview {
    iPhoneHomeView()
        .environment(SpcProvider())
        .environment(LocationManager())
    //        .modelContainer(for: ItemTest.self, inMemory: true)
    //        .environment()
}
