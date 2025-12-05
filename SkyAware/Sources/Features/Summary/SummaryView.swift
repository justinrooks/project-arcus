//
//  SummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI
import CoreLocation

struct SummaryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locationClient) private var locSvc
    @Environment(\.riskQuery) private var svc: any SpcRiskQuerying
//    @Environment(\.spcFreshness) private var fresh: any SpcFreshnessPublishing
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
    
    @State private var outlookRefreshTask: Task<Void, Never>?
    @State private var lastRefreshCoord: CLLocationCoordinate2D?
    @State private var lastRefreshAt: Date?
    
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
                    ActiveAlertSummaryView(
                        mesos: mesos,
                        watches: watches
                    )
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
        .task {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
            if Task.isCancelled { return }
            refreshOutlook()
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
                if Task.isCancelled { break }
                await MainActor.run { snap = s }
                startRefreshTask(for: s.coordinates)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active { refresh(for: snap) }
        }
        .refreshable { refresh(for: snap) }
    }
    
    
    private func refresh(for snap: LocationSnapshot?) {
        guard let snap else {
            refreshOutlook()
            return
        }
        refreshOutlook()
        startRefreshTask(for: snap.coordinates)
    }
    
    /// Manages data refreshes for outlook, storm, severe, and mesos for a given location
    /// - Parameter coord: coordinates to provide to downstream location based checking
    private func startRefreshTask(for coord: CLLocationCoordinate2D) {
        riskRefreshTask?.cancel()
        riskRefreshTask = Task {
            do {
//                await sync.sync()
                async let storm = svc.getStormRisk(for: coord)
                async let severe = svc.getSevereRisk(for: coord)
                async let meso = svc.getActiveMesos(at: .now, for: coord)
                #warning("Add a fetch for active watches here")
                
                let (s, v, m) = try await (storm, severe, meso)
                if Task.isCancelled { return }
                await MainActor.run {
                    self.stormRisk = s
                    self.severeRisk = v
                    self.mesos = m
                    self.lastRefreshCoord = coord
                    self.lastRefreshAt = Date()
                }
            } catch {
                
            }
        }
    }
    
    /// Determines whether we should refresh based on distance moved or time elapsed
    private func shouldRefresh(for coord: CLLocationCoordinate2D) -> Bool {
        if let last = lastRefreshCoord, let lastAt = lastRefreshAt {
            let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let newLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let distance = newLoc.distance(from: lastLoc) // meters
            // Only refresh if we've moved >= 1km or it's been >= 5 minutes
            if distance < 1000 && Date().timeIntervalSince(lastAt) < 300 {
                return false
            }
        }
        return true
    }

    /// Fetches the latest convective outlook independently of location updates
    private func refreshOutlook() {
        outlookRefreshTask?.cancel()
        outlookRefreshTask = Task {
            do {
                let o = try await outlookSvc.getLatestConvectiveOutlook()
                await MainActor.run {
                    self.outlook = o
                }
            } catch {
                // Swallow for now; consider logging
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
