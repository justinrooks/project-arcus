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
    
    @State private var snap: LocationSnapshot?
    
    @State private var stormRisk: StormRiskLevel = .allClear
    @State private var severeRisk: SevereWeatherThreat = .allClear
    @State private var riskRefreshTask: Task<Void, Never>?
    
    init( // This is purely for Preview functionality.
        initialStormRisk: StormRiskLevel = .allClear,
        initialSevereRisk: SevereWeatherThreat = .allClear,
        initialSnapshot: LocationSnapshot? = nil
    ) {
        _stormRisk = State(initialValue: initialStormRisk)
        _severeRisk = State(initialValue: initialSevereRisk)
        _snap = State(initialValue: initialSnapshot)
    }

    
    var body: some View {
        VStack {
            // Header
            FreshnessView()

            Label(snap?.placemarkSummary ?? "Searching...", systemImage: "location")
                .fontWeight(.medium)
            
            // Badges
            HStack {
                StormRiskBadgeView(level: stormRisk)
                Spacer()
                SevereWeatherBadgeView(threat: severeRisk)
            }
            .padding(.vertical, 5)
            
            //Mesos
            ActiveMesoSummaryView(coordinates: snap?.coordinates)
    
            // Filler
            GroupBox{
                Divider()
                HStack {
                    Text("No active watches in your area")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } label: {
                Label("Nearby Watches", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.teal)
            }
            
            GroupBox {
                //                Text("Scattered severe storms with damaging winds are possible into this evening across parts of the Lower and Middle Ohio Valley. The greatest threat is in northeast Lower Michigan, where isolated hail or a tornado is possible. Further south, clusters of storms may bring damaging wind gusts through Indiana, Kentucky, and Ohio. Lesser threats exist in Oklahoma, New Mexico, and Upper Michigan.")
                //                Text("Severe storms are expected this afternoon and evening across the Lower/Middle Ohio Valley, especially Indiana, Kentucky, and Ohio, with damaging wind the main threat. In northeast Lower Michigan, supercells could form with a risk of hail, damaging winds, and possibly a tornado. Scattered storms may also develop in Oklahoma, North Texas, New Mexico, and Upper Michigan, but the overall severe threat in those areas is more isolated.")
                Text("A Slight Risk is in place from northeast Lower Michigan into the Lower and Middle Ohio Valley. In Michigan, filtered heating, strong low-level flow, and modest instability (MLCAPE 1000–1500 J/kg) may allow supercells with wind, hail, and isolated tornadoes. Farther south, scattered storms from southern Illinois through Indiana and into Ohio/Kentucky may form multicell clusters with damaging winds as the main hazard. Additional isolated severe storms are possible in Oklahoma and North Texas, aided by MCVs, and over the high terrain of New Mexico and Colorado, where hail is the main concern. Activity diminishes tonight.")
            } label: {
                Label("Outlook Summary", systemImage: "sun.max.fill")
                    .foregroundStyle(.teal)
            }
        }
        .padding(.horizontal)
        .task {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
            if let first = await locSvc.snapshot() {
                await MainActor.run { snap = first }
                //risk task here
                startRefreshTask(for: first.coordinates)
            }
            
            let stream = await locSvc.updates()
            for await s in stream {
                snap = s
                await MainActor.run { snap = s }
                startRefreshTask(for: s.coordinates)
            }
        }
    }
    
    private func startRefreshTask(for coord: CLLocationCoordinate2D) {
        riskRefreshTask?.cancel()
        riskRefreshTask = Task {
            do {
                async let storm = svc.getStormRisk(for: coord)
                async let severe = svc.getSevereRisk(for: coord)
                
                let (s, v) = try await (storm, severe)
                await MainActor.run {
                    self.stormRisk = s
                    self.severeRisk = v
                }
            } catch {
                
            }
        }
    }
}

// MARK: Preview
#Preview("Summary – Slight + 10% Tornado") {
    // Seed some sample Mesos so ActiveMesoSummaryView has content
    let spcMock = MockSpcService(storm: .slight, severe: .tornado(probability: 0.10))
    let mdPreview = Preview(MD.self)
    mdPreview.addExamples(MD.sampleDiscussions)
    
    return NavigationStack {
        SummaryView(
            initialStormRisk: .slight,
            initialSevereRisk: .tornado(probability: 0.10),
            initialSnapshot: .init(
                coordinates: .init(latitude: 39.75, longitude: -104.44),
                timestamp: .now,
                accuracy: 20,
                placemarkSummary: "Bennett, CO"
            )
        )
            .modelContainer(mdPreview.container)
            .environment(\.locationClient, .offline)
            .environment(\.riskQuery, spcMock)
            .environment(\.spcFreshness, spcMock)
    }
}
