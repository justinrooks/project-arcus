//
//  SummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

enum SummaryReadinessState: Equatable {
    case loadingLocation
    case resolvingLocalContext
    case loadingLocalData
    case ready
    case locationUnavailable

    var statusText: String {
        switch self {
        case .loadingLocation:
            "Finding your location..."
        case .resolvingLocalContext:
            "Resolving local weather context..."
        case .loadingLocalData:
            "Loading local weather details..."
        case .ready:
            "Current location ready"
        case .locationUnavailable:
            "Location unavailable"
        }
    }
}

struct SummaryView: View {
    let snap: LocationSnapshot?
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let mesos: [MdDTO]
    let watches: [WatchRowDTO]
    let outlook: ConvectiveOutlookDTO?
    let weather: SummaryWeather?
    let readinessState: SummaryReadinessState

    private var hasActiveAlerts: Bool {
        !mesos.isEmpty || !watches.isEmpty
    }

    private var isWeatherLoading: Bool {
        weather == nil
    }

    private var isSummaryLoading: Bool {
        switch readinessState {
        case .loadingLocation, .resolvingLocalContext, .loadingLocalData:
            true
        case .ready, .locationUnavailable:
            false
        }
    }

    private var statusText: String {
        if let placemark = snap?.placemarkSummary {
            return placemark
        }
        return readinessState.statusText
    }

    private var isLocationUnavailable: Bool {
        readinessState == .locationUnavailable
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
            AtmosphereRailView(weather: weather)
//                .placeholder(isWeatherLoading)
                .allowsHitTesting(!isWeatherLoading)
                .animation(.snappy, value: isWeatherLoading)
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
                statusText: statusText,
                weather: weather
            )

            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Risk Snapshot", icon: "gauge.with.needle.fill")
                if isLocationUnavailable {
                    unavailableCard(
                        title: "Location Required",
                        message: "Enable location access to load local risk, alerts, and weather conditions.",
                        symbol: "location.slash"
                    )
                } else if #available(iOS 26, *) {
                    GlassEffectContainer(spacing: 14) {
                        riskSnapshotContent
                    }
                } else {
                    riskSnapshotContent
                }
            }
            .padding(16)
            .cardBackground(cornerRadius: SkyAwareRadius.hero, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)

            if isLocationUnavailable {
                unavailableCard(
                    title: "Location Required",
                    message: "Active alerts appear after SkyAware resolves your local county and fire zone.",
                    symbol: "location.slash"
                )
            } else if isSummaryLoading {
                ActiveAlertSummaryView(mesos: [], watches: [], isLoading: true)
            } else if hasActiveAlerts {
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
            } else if readinessState == .loadingLocation || readinessState == .resolvingLocalContext {
                OutlookSummaryCard(outlook: nil, isLoading: true)
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
            .sectionLabel()
    }

    private func emptySectionCard(title: String, message: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .sectionLabel()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.06, shadowRadius: 6, shadowY: 2)
    }

    private func unavailableCard(title: String, message: String, symbol: String) -> some View {
        emptySectionCard(title: title, message: message, symbol: symbol)
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
            weather: nil,
            readinessState: .ready
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
            weather: nil,
            readinessState: .loadingLocalData
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}
