//
//  ContentView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import SwiftData
import MapKit

struct HomeView: View {
//    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var provider: SpcProvider
    @EnvironmentObject private var pointsProvider: PointsProvider
    
    var body: some View {
        ZStack {
            TabView {
                SummaryView()
                    .tabItem {
                        Image(systemName: "sunrise.fill")
                        Text("Summary")
                    }
                MapView(polygons: pointsProvider.slight)
                    .tabItem {
                        Image(systemName: "map")
                        Text("Map")
                    }
                ConvectiveOutlookView(outlooks: provider.outlooks)
                    .tabItem {
                        Image(systemName: "umbrella")
                        Text("Outlooks")
                    }
                MesoView(discussions: provider.meso)
                    .tabItem {
                        Image(systemName: "cloud.bolt.rain.fill")
                        Text("Meso")
                    }
                WatchWarn(watches: provider.watches)
                    .tabItem {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Watches")
                    }
            }
            
            if provider.isLoading {
                VStack {
                    Spacer()
                    LoadingView(message: "Fetching SPC data...")
                    Spacer()
                }
                .transition(.opacity)
                .animation(.easeInOut, value: provider.isLoading)
            }
        }
        .accentColor(.teal)
        .onAppear {
            fetchSpcData()
        }
    }
}

extension HomeView {
    func fetchSpcData() {
        provider.loadFeed()
        
        print("Got SPC Feed data")
        
        pointsProvider.loadPoints()
        
        print("Got SPC Points data")
    }
}


#Preview {
    HomeView()
        .environmentObject(SpcProvider())
        .environmentObject(PointsProvider())
    //        .modelContainer(for: ItemTest.self, inMemory: true)
    //        .environment()
}
