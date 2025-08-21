//
//  iPhoneHomeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import SwiftData

struct iPhoneHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpcProvider.self) private var provider: SpcProvider
    
    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()
            if provider.isLoading {
                VStack {
                    LoadingView(message: "Fetching SPC data...")
                }.ignoresSafeArea()
            } else {
                TabView {
                    NavigationStack {
                        ScrollView{
                            SummaryView()
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
                        ConvectiveOutlookView()
                    }
                    .tabItem {
                        Image(systemName: "cloud.bolt.rain.fill") //cloud.bolt.rain.fill
                        Text("Outlook")
                    }
                    
                    NavigationStack {
//                        CadenceSandboxView()
                        #if DEBUG
                        NavigationStack {
                            DebugFeedCacheView()
                        }
                        #endif
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
    // 1) In‑memory SwiftData container for previews
    let container = try! ModelContainer(
        for: FeedCache.self,//, RiskSnapshot.self, MDEntry.self,  // include any @Model types you use
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    // 2) Wire client → repo → service → provider (no network auto-load in previews)
    let client   = SpcClient()
    let service  = SpcService(client: client)
    let provider = SpcProvider(service: service, autoLoad: false)
    
    // 3) Build your preview view and inject env objects
    return iPhoneHomeView()
        .environment(provider)                // your @Observable provider
        .environment(LocationManager())       // or a preconfigured preview instance
        .modelContainer(container)            // attaches the container to the view tree
    //    iPhoneHomeView()
    //        .environment(SpcProvider())
    //        .environment(LocationManager())
    //        .modelContainer(for: FeedCache.self, inMemory: true)
    //    //        .environment()
}
