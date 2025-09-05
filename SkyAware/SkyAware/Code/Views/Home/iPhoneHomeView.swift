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
                        Image(systemName: "list.bullet") //sunrise.fill, circle.grid.cross.fill
                        Text("Summary")
                    }
                    
                    NavigationStack {
                        AlertView()
                    }
                    .tabItem {
                        Image(systemName: "exclamationmark.triangle") //umbrella
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
//                            DebugFeedCacheView()
                        }
                        #endif
                    }
                    .tabItem {
                        Image(systemName: "gearshape") //exclamationmark.triangle
                        Text("Settings")
                    }
                }
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.5), value: provider.isLoading)
        .accentColor(.green.opacity(0.80))
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
//    let container = try! ModelContainer(
//        for: FeedCache.self,//, RiskSnapshot.self, MDEntry.self,  // include any @Model types you use
//        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
//    )
    
    let client   = SpcClient()
    let provider = SpcProvider(client: client, autoLoad: true)
    let mock = LocationManager()
    
    return iPhoneHomeView()
        .environment(provider)                // your @Observable provider
        .environment(LocationManager())       // or a preconfigured preview instance
        .environment(SummaryProvider(provider: provider, location: mock))
}
