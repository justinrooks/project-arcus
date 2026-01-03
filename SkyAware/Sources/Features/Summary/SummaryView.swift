//
//  SummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI
import CoreLocation
import OSLog

struct SummaryView: View {
    private let logger = Logger.summaryView
    
    let snap: LocationSnapshot?
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let mesos: [MdDTO]
    let watches: [WatchRowDTO]
    let outlook: ConvectiveOutlookDTO?
    
    var body: some View {
        VStack {
            // Header
            SummaryStatus(
                location: snap?.placemarkSummary ?? "Searching...",
                updatedAt: outlook?.published
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
            if !mesos.isEmpty || !watches.isEmpty {
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
}

// MARK: Previews
#Preview("Summary – Slight + 10% Tornado") {
    NavigationStack {
        SummaryView(
            snap: .init(
                coordinates: .init(latitude: 39.75, longitude: -104.44),
                timestamp: .now,
                accuracy: 20,
                placemarkSummary: "Bennett, CO"
            ),
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.10),
            mesos: MD.sampleDiscussionDTOs,
            watches: Watch.sampleWatchRows,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first
        )
        .toolbar(.hidden, for: .navigationBar)
        .background(.skyAwareBackground)
    }
}

#Preview("Summary – Loading") {
    NavigationStack {
        SummaryView(
            snap: .init(
                coordinates: .init(latitude: 39.75, longitude: -104.44),
                timestamp: .now,
                accuracy: 20,
                placemarkSummary: "Bennett, CO"
            ),
            stormRisk: nil,
            severeRisk: nil,
            mesos: [],
            watches: [],
            outlook: nil
        )
        .toolbar(.hidden, for: .navigationBar)
        .background(.skyAwareBackground)
    }
}
