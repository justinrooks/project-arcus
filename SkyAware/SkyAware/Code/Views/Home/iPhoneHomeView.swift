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
//    @Environment(SpcProvider.self) private var provider: SpcProvider
    
    @Query private var mesos: [MD]
    @Query private var watches: [WatchModel]
    
    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()
//            if provider.isLoading {
//                VStack {
//                    LoadingView(message: "Fetching SPC data...")
//                }.ignoresSafeArea()
//            } else {
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
                        SettingsView()
                    }
                    .tabItem {
                        Image(systemName: "gearshape") //exclamationmark.triangle
                        Text("Settings")
                    }
                }
            }
//        }
        .transition(.opacity)
//        .animation(.easeInOut(duration: 0.5), value: provider.isLoading)
        .accentColor(.green.opacity(0.80))
    }
}

extension iPhoneHomeView {
    func fetchSpcData() {
//        provider.loadFeed()
//        
//        print("Got SPC Feed data")
    }
}

// Shared mock service for previews
private struct PreviewSpcService: SpcService {
    let storm: StormRiskLevel
    let severe: SevereWeatherThreat

    func sync() async {}
    func syncTextProducts() async {}
    func cleanup(daysToKeep: Int) async {}

    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel { storm }
    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat { severe }
    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] { [] }
}

#Preview("Home – Slight + 10% Tornado") {
    // In-memory SwiftData container with sample data for all tabs
    let preview = Preview(ConvectiveOutlook.self, MD.self, WatchModel.self, StormRisk.self, SevereRisk.self)
    preview.addExamples(MD.sampleDiscussions)
    preview.addExamples(WatchModel.sampleWatches)
    preview.addExamples(ConvectiveOutlook.sampleOutlooks)

    // Environment dependencies
    let location = LocationManager()
    let spcMock = PreviewSpcService(storm: .slight, severe: .tornado(probability: 0.10))

    return iPhoneHomeView()
        .modelContainer(preview.container)
        .environment(location)
        .environment(\.spcService, spcMock)
}

#Preview("Home – All Clear") {
    let preview = Preview(ConvectiveOutlook.self, MD.self, WatchModel.self, StormRisk.self, SevereRisk.self)
    preview.addExamples(MD.sampleDiscussions)
    preview.addExamples(WatchModel.sampleWatches)
    preview.addExamples(ConvectiveOutlook.sampleOutlooks)

    let location = LocationManager()
    let spcMock = PreviewSpcService(storm: .allClear, severe: .allClear)

    return iPhoneHomeView()
        .modelContainer(preview.container)
        .environment(location)
        .environment(\.spcService, spcMock)
}

#Preview("Home – Enhanced + 30% Hail (Dark)") {
    let preview = Preview(ConvectiveOutlook.self, MD.self, WatchModel.self, StormRisk.self, SevereRisk.self)
    preview.addExamples(MD.sampleDiscussions)
    preview.addExamples(WatchModel.sampleWatches)
    preview.addExamples(ConvectiveOutlook.sampleOutlooks)

    let location = LocationManager()
    let spcMock = PreviewSpcService(storm: .enhanced, severe: .hail(probability: 0.30))

    return iPhoneHomeView()
        .modelContainer(preview.container)
        .environment(location)
        .environment(\.spcService, spcMock)
        .environment(\.colorScheme, .dark)
}
