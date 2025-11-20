//
//  SummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI
import CoreLocation

struct SummaryView: View {
    @Environment(\.locationClient) private var locSvc
    @Environment(\.riskQuery) private var svc: any SpcRiskQuerying
    @Environment(\.spcFreshness) private var fresh: any SpcFreshnessPublishing
    @Environment(\.spcSync) private var sync: any SpcSyncing
    @Environment(\.outlookQuery) private var outlookSvc: any SpcOutlookQuerying
    
    // MARK: State
    @State private var riskRefreshTask: Task<Void, Never>?
    
    // Header State
    @State private var snap: LocationSnapshot?
    
    // Badge State
    @State private var stormRisk: StormRiskLevel?
    @State private var severeRisk: SevereWeatherThreat?
    
    // Alert State
    @State private var mesos: [MdDTO]
    @State private var watches: [WatchDTO]
    
    // Outlook State
    @State private var outlook: ConvectiveOutlookDTO?
    
    init( // This is purely for Preview functionality.
        initialStormRisk: StormRiskLevel? = nil,
        initialSevereRisk: SevereWeatherThreat? = nil,
        initialSnapshot: LocationSnapshot? = nil,
        initialOutlook: ConvectiveOutlookDTO? = nil,
        initialMesos: [MdDTO] = [],
        initialWatches: [WatchDTO] = []
    ) {
        _stormRisk = State(initialValue: initialStormRisk)
        _severeRisk = State(initialValue: initialSevereRisk)
        _snap = State(initialValue: initialSnapshot)
        _outlook = State(initialValue: initialOutlook)
        _mesos = State(initialValue: initialMesos)
        _watches = State(initialValue: initialWatches)
    }
    
    var body: some View {
        ScrollView {
            VStack {
                // Header
                SummaryStatus(
                    location: snap?.placemarkSummary ?? "Searching...",
                    updatedAt: outlook?.published ?? Date()
                )
                .placeholder(outlook == nil || snap == nil)
                
                // Badges
                HStack {
                    StormRiskBadgeView(level: stormRisk ?? .allClear)
                        .placeholder(stormRisk == nil)
                    Spacer()
                    SevereWeatherBadgeView(threat: severeRisk ?? .allClear)
                        .placeholder(severeRisk == nil)
                }
                .padding(.vertical, 24)
                
                // Alerts
                if !mesos.isEmpty {
                    ActiveAlertSummaryView(mesos: mesos, watches: watches)
                        .toolbar(.hidden, for: .navigationBar)
                        .background(.skyAwareBackground)
                        .padding(.bottom, 12)
                }
                
                // Current Outlook
                if let outlook {
                    OutlookSummaryCard(outlook: outlook)
                        .padding(.bottom, 12)
                }
                Spacer()
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.skyAwareBackground.ignoresSafeArea())
        .refreshable {
            guard let snap else { return }
            startRefreshTask(for: snap.coordinates)
        }
        .task {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
            if let first = await locSvc.snapshot() {
                await MainActor.run { snap = first }
                startRefreshTask(for: first.coordinates)
            }
            
            // Whenever a location snapshot hits, refresh the data with
            // the newest location. We have a filter here so it is at
            // least 1k meters, city to city changes, not across the
            // street.
            let stream = await locSvc.updates()
            for await s in stream {
                snap = s
                await MainActor.run { snap = s }
                startRefreshTask(for: s.coordinates)
            }
        }
    }
    
    
    /// Manages data refreshes for outlook, storm, severe, and mesos for a given location
    /// - Parameter coord: coordinates to provide to downstream location based checking
    private func startRefreshTask(for coord: CLLocationCoordinate2D) {
        riskRefreshTask?.cancel()
        riskRefreshTask = Task {
            do {
                async let outlk = outlookSvc.getLatestConvectiveOutlook()
                async let storm = svc.getStormRisk(for: coord)
                async let severe = svc.getSevereRisk(for: coord)
                async let meso = svc.getActiveMesos(at: .now, for: coord)
                #warning("Add a fetch for active watches here")
                
                let (o, s, v, m) = try await (outlk, storm, severe, meso)
                await MainActor.run {
                    self.outlook = o
                    self.stormRisk = s
                    self.severeRisk = v
                    self.mesos = m
                }
            } catch {
                
            }
        }
    }
}

// MARK: Previews
#Preview("Summary – Slight + 10% Tornado") {
    // Seed some sample Mesos so ActiveMesoSummaryView has content
    let spcMock = MockSpcService(storm: .slight, severe: .tornado(probability: 0.10))
    let mdPreview = Preview(MD.self, ConvectiveOutlook.self)
    
    mdPreview.addExamples(MD.sampleDiscussions)
    mdPreview.addExamples(ConvectiveOutlook.sampleOutlooks)
    
    return NavigationStack {
        SummaryView(
            initialStormRisk: .slight,
            initialSevereRisk: .tornado(probability: 0.10),
            initialSnapshot: .init(
                coordinates: .init(latitude: 39.75, longitude: -104.44),
                timestamp: .now,
                accuracy: 20,
                placemarkSummary: "Bennett, CO"
            ),
            initialOutlook: ConvectiveOutlook.sampleOutlookDtos.first!,
            initialMesos: MD.sampleDiscussionDTOs,
            initialWatches: WatchModel.sampleWatcheDtos
        )
        .toolbar(.hidden, for: .navigationBar)
        .background(.skyAwareBackground)
        .modelContainer(mdPreview.container)
        .environment(\.locationClient, .offline)
        .environment(\.riskQuery, spcMock)
        .environment(\.spcFreshness, spcMock)
        .environment(\.spcSync, spcMock)
        .environment(\.outlookQuery, spcMock)
    }
}

#Preview("Summary – Loading") {
    // Seed some sample Mesos so ActiveMesoSummaryView has content
    let spcMock = MockSpcService(storm: .slight, severe: .tornado(probability: 0.10))
    let mdPreview = Preview(MD.self, ConvectiveOutlook.self, WatchModel.self)
    
    mdPreview.addExamples(MD.sampleDiscussions)
    mdPreview.addExamples(ConvectiveOutlook.sampleOutlooks)
    mdPreview.addExamples(WatchModel.sampleWatches)
    
    return NavigationStack {
        SummaryView(
            initialSnapshot: .init(
                coordinates: .init(latitude: 39.75, longitude: -104.44),
                timestamp: .now,
                accuracy: 20,
                placemarkSummary: "Bennett, CO"
            )
        )
        .toolbar(.hidden, for: .navigationBar)
        .background(.skyAwareBackground)
        .modelContainer(mdPreview.container)
        .environment(\.locationClient, .offline)
        .environment(\.riskQuery, spcMock)
        .environment(\.spcFreshness, spcMock)
        .environment(\.spcSync, spcMock)
        .environment(\.outlookQuery, spcMock)
    }
}
