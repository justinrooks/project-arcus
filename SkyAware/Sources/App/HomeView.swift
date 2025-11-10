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
    
//    @State private var tab: Tab = .summary
    
    var body: some View {
        ZStack {
            Color(.skyAwareBackground).ignoresSafeArea()
            TabView {
                NavigationStack {
                    SummaryView()
                        .toolbar(.hidden, for: .navigationBar)
                        .background(.skyAwareBackground)
//                    Spacer()
                }
                .tabItem { Label("Summary", systemImage: "list.bullet") }
                
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
                .tabItem { Label("Outlooks", systemImage: "cloud.bolt.rain.fill") }
                
                NavigationStack {
                    //                    SettingsView()
                    //                    LogViewerView()
                    BgHealthDiagnosticsView()
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
