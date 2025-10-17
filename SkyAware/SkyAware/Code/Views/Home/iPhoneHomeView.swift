//
//  iPhoneHomeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct iPhoneHomeView: View {
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
                    LogViewerView()
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

//#Preview("Home – Slight + 10% Tornado") {
//    // In-memory SwiftData container with sample data for all tabs
//    let preview = Preview(ConvectiveOutlook.self, MD.self, WatchModel.self, StormRisk.self, SevereRisk.self)
//    preview.addExamples(MD.sampleDiscussions)
//    preview.addExamples(WatchModel.sampleWatches)
//    preview.addExamples(ConvectiveOutlook.sampleOutlooks)
//    
//    // Environment dependencies
//    let spcMock = MockSpcService(storm: .slight, severe: .tornado(probability: 0.10))
//    
//    return iPhoneHomeView()
//        .modelContainer(preview.container)
//        .environment(\.spcService, spcMock)
//}
//
//#Preview("Home – All Clear") {
//    let preview = Preview(ConvectiveOutlook.self, MD.self, WatchModel.self, StormRisk.self, SevereRisk.self)
//    preview.addExamples(MD.sampleDiscussions)
//    preview.addExamples(WatchModel.sampleWatches)
//    preview.addExamples(ConvectiveOutlook.sampleOutlooks)
//    
//    let spcMock = MockSpcService(storm: .allClear, severe: .allClear)
//    
//    return iPhoneHomeView()
//        .modelContainer(preview.container)
//        .environment(\.spcService, spcMock)
//}
//
//#Preview("Home – Enhanced + 30% Hail (Dark)") {
//    let preview = Preview(ConvectiveOutlook.self, MD.self, WatchModel.self, StormRisk.self, SevereRisk.self)
//    preview.addExamples(MD.sampleDiscussions)
//    preview.addExamples(WatchModel.sampleWatches)
//    preview.addExamples(ConvectiveOutlook.sampleOutlooks)
//    
//    let spcMock = MockSpcService(storm: .enhanced, severe: .hail(probability: 0.30))
//    
//    return iPhoneHomeView()
//        .modelContainer(preview.container)
//        .environment(\.spcService, spcMock)
//        .environment(\.colorScheme, .dark)
//}
