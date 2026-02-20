//
//  SummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

struct SummaryView: View {
    let snap: LocationSnapshot?
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let mesos: [MdDTO]
    let watches: [WatchRowDTO]
    let outlook: ConvectiveOutlookDTO?
    let weather: SummaryWeather?

    private var hasActiveAlerts: Bool {
        !mesos.isEmpty || !watches.isEmpty
    }

    @ViewBuilder
    private var riskSnapshotContent: some View {
        VStack(spacing: 12) {
            badgeRow
            // TODO: Toggle this with an option one day
            //       Make the option that, if its clear to show
            //       the row. Default should be to hide a no fire
            //       danger
            FireWeatherRailView(level: fireRisk ?? .clear)
                .placeholder(fireRisk == nil)
        }
    }

    @ViewBuilder
    private var badgeRow: some View {
        HStack {
            StormRiskBadgeView(level: stormRisk ?? .allClear)
                .placeholder(stormRisk == nil)
            Spacer()
            SevereWeatherBadgeView(threat: severeRisk ?? .allClear)
                .placeholder(severeRisk == nil)
        }
        .padding(.top, 8)
    }
    
    var body: some View {
        VStack(spacing: 18) {
            SummaryStatus(
                location: snap?.placemarkSummary ?? "Searching...",
                weather: weather
            )
            .placeholder(snap == nil)

            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Risk Snapshot", icon: "gauge.with.needle.fill")
                if #available(iOS 26, *) {
                    GlassEffectContainer(spacing: 14) {
                        riskSnapshotContent
                    }
                } else {
                    riskSnapshotContent
                }
            }
            .padding(16)
            .cardBackground(cornerRadius: SkyAwareRadius.hero, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)

            if hasActiveAlerts {
                ActiveAlertSummaryView(
                    mesos: mesos,
                    watches: watches
                )
            } else {
                emptySectionCard(
                    title: "No Active Alerts",
                    message: "Your local area currently has no active watches or mesoscale discussions.",
                    symbol: "checkmark.shield"
                )
            }

            if let outlook {
                OutlookSummaryCard(outlook: outlook)
            } else {
                emptySectionCard(
                    title: "Outlook Pending",
                    message: "Convective outlook text has not been synced yet.",
                    symbol: "clock.arrow.circlepath"
                )
            }
            
            AttributionView()

            Spacer(minLength: 14)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func emptySectionCard(title: String, message: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.06, shadowRadius: 6, shadowY: 2)
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
            fireRisk: .extreme,
            mesos: MD.sampleDiscussionDTOs,
            watches: Watch.sampleWatchRows,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            weather: nil
        )
        .toolbar(.hidden, for: .navigationBar)
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
            fireRisk: nil,
            mesos: [],
            watches: [],
            outlook: nil,
            weather: nil
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}
