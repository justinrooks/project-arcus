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
    
    // MARK: State
    @State private var riskRefreshTask: Task<Void, Never>?
    
    // Header State
    @State private var snap: LocationSnapshot?
    
    // Badge State
    @State private var stormRisk: StormRiskLevel?
    @State private var severeRisk: SevereWeatherThreat?
    
    // Alert State
    @State private var mesos: [MdDTO]
    
    // Outlook State
    @State private var outlook: ConvectiveOutlookDTO?
    
    init( // This is purely for Preview functionality.
        initialStormRisk: StormRiskLevel? = nil,
        initialSevereRisk: SevereWeatherThreat? = nil,
        initialSnapshot: LocationSnapshot? = nil,
        initialOutlook: ConvectiveOutlookDTO? = nil,
        initialMesos: [MdDTO] = []
    ) {
        _stormRisk = State(initialValue: initialStormRisk)
        _severeRisk = State(initialValue: initialSevereRisk)
        _snap = State(initialValue: initialSnapshot)
        _outlook = State(initialValue: initialOutlook)
        _mesos = State(initialValue: initialMesos)
    }
    
    var body: some View {
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
            .padding(.bottom, 5)

            // Alerts
            if !mesos.isEmpty {
                ActiveAlertSummaryView(mesos: mesos)
                    .toolbar(.hidden, for: .navigationBar)
                    .background(.skyAwareBackground)
            }
            
            if let outlook {
                OutlookSummaryCard(outlook: outlook)
                //                    .placeholder(outlook == nil)
            }
            Spacer()
        }
        .padding()
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
                async let outlk = sync.getLatestConvectiveOutlook()
                async let storm = svc.getStormRisk(for: coord)
                async let severe = svc.getSevereRisk(for: coord)
                async let meso = svc.getActiveMesos(at: .now, for: coord)
                
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
    let last = ConvectiveOutlook.sampleOutlooks.last!
    
    let dto:ConvectiveOutlookDTO = .init(
        title: "Outlook Test",
        link: URL(string: "https://www.weather.gov/severe/outlook/test")!,
        published: Date(),
        summary: "Isolated severe thunderstorms are possible through the day along the western Oregon and far northern California coastal region. Strong to locally severe gusts may accompany shallow convection that develops over parts of the Northeast.",
        fullText: "...SUMMARY... \nIsolated severe thunderstorms are possible through the day along the western Oregon and far northern California coastal region. Strong to locally severe gusts may accompany shallow convection that develops over parts of the Northeast.\n....20z UPDATE... \nThe only adjustment was a northward expansion of the 2% tornado and 5% wind risk probabilities across the far southwest WA coast. Recent imagery from KLGX shows a cluster of semi-discrete cells off the far southwest WA coast with weak, but discernible, mid-level rotation. Regional VWPs continue to show ample low-level shear, and surface temperatures are warming to near/slightly above the upper-end of the ensemble envelope. These kinematic/thermodynamic conditions may support at least a low-end wind and brief tornado threat along the coast.",
        day: 1,
        riskLevel: "mdt"
    )
    
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
            initialOutlook: dto,
            initialMesos: MD.sampleDiscussionDTOs
        )
        .toolbar(.hidden, for: .navigationBar)
        .background(.skyAwareBackground)
        .modelContainer(mdPreview.container)
        .environment(\.locationClient, .offline)
        .environment(\.riskQuery, spcMock)
        .environment(\.spcFreshness, spcMock)
        .environment(\.spcSync, spcMock)
    }
}

#Preview("Summary – Loading") {
    // Seed some sample Mesos so ActiveMesoSummaryView has content
    let spcMock = MockSpcService(storm: .slight, severe: .tornado(probability: 0.10))
    let mdPreview = Preview(MD.self, ConvectiveOutlook.self)
    
    mdPreview.addExamples(MD.sampleDiscussions)
    mdPreview.addExamples(ConvectiveOutlook.sampleOutlooks)
    let last = ConvectiveOutlook.sampleOutlooks.last!
    
    let dto:ConvectiveOutlookDTO = .init(
        title: "Outlook Test",
        link: URL(string: "https://www.weather.gov/severe/outlook/test")!,
        published: Date(),
        summary: "Isolated severe thunderstorms are possible through the day along the western Oregon and far northern California coastal region. Strong to locally severe gusts may accompany shallow convection that develops over parts of the Northeast.",
        fullText: "...SUMMARY... \nIsolated severe thunderstorms are possible through the day along the western Oregon and far northern California coastal region. Strong to locally severe gusts may accompany shallow convection that develops over parts of the Northeast.\n....20z UPDATE... \nThe only adjustment was a northward expansion of the 2% tornado and 5% wind risk probabilities across the far southwest WA coast. Recent imagery from KLGX shows a cluster of semi-discrete cells off the far southwest WA coast with weak, but discernible, mid-level rotation. Regional VWPs continue to show ample low-level shear, and surface temperatures are warming to near/slightly above the upper-end of the ensemble envelope. These kinematic/thermodynamic conditions may support at least a low-end wind and brief tornado threat along the coast.",
        day: 1,
        riskLevel: "mdt"
    )
    
    return NavigationStack {
        SummaryView(
//            initialStormRisk: .slight,
//            initialSevereRisk: .tornado(probability: 0.10),
            initialSnapshot: .init(
                coordinates: .init(latitude: 39.75, longitude: -104.44),
                timestamp: .now,
                accuracy: 20,
                placemarkSummary: "Bennett, CO"
            ),
//            initialOutlook: dto
        )
        .toolbar(.hidden, for: .navigationBar)
        .background(.skyAwareBackground)
        .modelContainer(mdPreview.container)
        .environment(\.locationClient, .offline)
        .environment(\.riskQuery, spcMock)
        .environment(\.spcFreshness, spcMock)
        .environment(\.spcSync, spcMock)
    }
}
