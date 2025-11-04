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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.spcSync) private var svc: any SpcSyncing
    
    @Query private var mesos: [MD]
    @Query private var watches: [WatchModel]
    
    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()
            TabView {
                NavigationStack {
                    ScrollView{
                        SummaryView()
                    }
                    .refreshable {
                        Task {
                            await svc.sync()
                        }
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
                }.badge(mesos.count + watches.count)
                
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
//                    SettingsView()
//                    LogViewerView()
                    BgHealthDiagnosticsView()
                }
                .tabItem {
                    Image(systemName: "gearshape") //exclamationmark.triangle
                    Text("Settings")
                }
            }
        }
        .transition(.opacity)
        .accentColor(.green.opacity(0.80))
    }
}

// MARK: Preview
#Preview("Home") {
    // In-memory SwiftData container with sample data for all tabs
    let preview = Preview(ConvectiveOutlook.self, MD.self, WatchModel.self, StormRisk.self, SevereRisk.self, BgRunSnapshot.self)
    preview.addExamples(MD.sampleDiscussions)
    preview.addExamples(WatchModel.sampleWatches)
    preview.addExamples(ConvectiveOutlook.sampleOutlooks)
    preview.addExamples(BgRunSnapshot.sampleRuns)
    
    // Environment dependencies
    let spcMock = MockSpcService(storm: .slight, severe: .tornado(probability: 0.10))
    
    return HomeView()
        .modelContainer(preview.container)
        .environment(\.spcSync, spcMock)
        .environment(\.spcFreshness, spcMock)
}
