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
            "Finding your location…"
        case .resolvingLocalContext:
            "Getting your area ready…"
        case .loadingLocalData:
            "Bringing in your conditions…"
        case .ready:
            "Ready"
        case .locationUnavailable:
            "Location not available"
        }
    }
}

struct SummaryView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum LocalAlertsPresentationState: Equatable {
        case unavailable
        case loading
        case alerts
        case empty
    }

    let snap: LocationSnapshot?
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let mesos: [MdDTO]
    let watches: [WatchRowDTO]
    let outlook: ConvectiveOutlookDTO?
    let weather: SummaryWeather?
    let readinessState: SummaryReadinessState
    let resolutionState: SummaryResolutionState
    let showsOfflineToken: Bool
    let headerCondenseProgress: CGFloat
    let onOpenMapLayer: (MapLayer) -> Void
    let onOpenAlerts: () -> Void
    let onOpenOutlooks: () -> Void

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

    private var localAlertsPresentationState: LocalAlertsPresentationState {
        Self.localAlertsPresentationState(
            readinessState: readinessState,
            hasActiveAlerts: hasActiveAlerts,
            isLocationUnavailable: isLocationUnavailable
        )
    }

    private var hasMeaningfulContent: Bool {
        snap != nil ||
        weather != nil ||
        stormRisk != nil ||
        severeRisk != nil ||
        fireRisk != nil ||
        outlook != nil ||
        hasActiveAlerts
    }

    private var showsEmptyResolving: Bool {
        isLocationUnavailable == false &&
        hasMeaningfulContent == false &&
        (isSummaryLoading || resolutionState.isRefreshing)
    }

    private var severeMapLayer: MapLayer {
        switch severeRisk ?? .allClear {
        case .allClear:
            return .categorical
        case .wind:
            return .wind
        case .hail:
            return .hail
        case .tornado:
            return .tornado
        }
    }

    @ViewBuilder
    private var riskSnapshotContent: some View {
        VStack(spacing: 12) {
            badgeRow
            // TODO: Toggle this with an option one day
            //       Make the option that, if its clear to show
            //       the row. Default should be to hide a no fire
            //       danger
            Button {
                onOpenMapLayer(.fire)
            } label: {
                FireWeatherRailView(level: fireRisk ?? .clear)
                    .placeholder(fireRisk == nil)
                    .contentShape(RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous))
            }
            .buttonStyle(
                SkyAwarePressableButtonStyle(
                    cornerRadius: SkyAwareRadius.large,
                    pressedScale: 0.992,
                    pressedOverlayOpacity: 0.06
                )
            )
            .summaryResolving(resolutionState.isResolving(.fireRisk))
            .accessibilityHint("Opens the fire risk map.")
            AtmosphereRailView(weather: weather)
                .allowsHitTesting(!isWeatherLoading)
                .summaryResolving(resolutionState.isResolving(.atmosphere))
        }
    }

    @ViewBuilder
    private var badgeRow: some View {
        HStack {
            Button {
                onOpenMapLayer(.categorical)
            } label: {
                StormRiskBadgeView(level: stormRisk ?? .allClear)
                    .placeholder(stormRisk == nil)
                    .contentShape(RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous))
            }
            .buttonStyle(
                SkyAwarePressableButtonStyle(
                    cornerRadius: SkyAwareRadius.large,
                    pressedScale: 0.992,
                    pressedOverlayOpacity: 0.06
                )
            )
            .summaryResolving(resolutionState.isResolving(.stormRisk))
            .accessibilityHint("Opens the severe risk map.")
            Spacer()
            Button {
                onOpenMapLayer(severeMapLayer)
            } label: {
                SevereWeatherBadgeView(threat: severeRisk ?? .allClear)
                    .placeholder(severeRisk == nil)
                    .contentShape(RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous))
            }
            .buttonStyle(
                SkyAwarePressableButtonStyle(
                    cornerRadius: SkyAwareRadius.large,
                    pressedScale: 0.992,
                    pressedOverlayOpacity: 0.06
                )
            )
            .summaryResolving(resolutionState.isResolving(.severeRisk))
            .accessibilityHint("Opens the highlighted severe threat map.")
        }
        .padding(.top, 8)
    }
    
    var body: some View {
        VStack(spacing: 18) {
            if showsEmptyResolving {
                LoadingView(message: resolutionState.activeMessages.first ?? readinessState.statusText)
            } else {
                SummaryStatus(
                    statusText: statusText,
                    weather: weather,
                    resolutionState: resolutionState,
                    showsOfflineToken: showsOfflineToken,
                    condenseProgress: headerCondenseProgress
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
                .cardBackground(
                    cornerRadius: SkyAwareRadius.hero,
                    shadowOpacity: 0.08,
                    shadowRadius: 8,
                    shadowY: 3,
                    allowsGlass: false
                )

                switch localAlertsPresentationState {
                case .unavailable:
                    unavailableCard(
                        title: "Location Required",
                        message: "Active alerts appear after SkyAware resolves your local county and fire zone.",
                        symbol: "location.slash"
                    )
                case .loading:
                    ActiveAlertSummaryView(mesos: [], watches: [], isLoading: true)
                        .summaryResolving(resolutionState.isResolving(.alerts))
                case .alerts:
                    ActiveAlertSummaryView(
                        mesos: mesos,
                        watches: watches,
                        onOpenAlertCenter: onOpenAlerts
                    )
                    .summaryResolving(resolutionState.isResolving(.alerts))
                case .empty:
                    emptySectionCard(
                        title: "No Active Alerts",
                        message: "Your local area currently has no active watches or mesoscale discussions.",
                        symbol: "checkmark.shield"
                    )
                    .summaryResolving(resolutionState.isResolving(.alerts))
                }

                if let outlook {
                    OutlookSummaryCard(
                        outlook: outlook,
                        onBrowseAllOutlooks: onOpenOutlooks
                    )
                        .summaryResolving(resolutionState.isResolving(.outlook))
                } else if readinessState == .loadingLocation || readinessState == .resolvingLocalContext {
                    OutlookSummaryCard(
                        outlook: nil,
                        isLoading: true,
                        onBrowseAllOutlooks: onOpenOutlooks
                    )
                        .summaryResolving(resolutionState.isResolving(.outlook))
                } else {
                    emptySectionCard(
                        title: "Outlook Pending",
                        message: "Convective outlook text has not been synced yet.",
                        symbol: "clock.arrow.circlepath"
                    )
                    .summaryResolving(resolutionState.isResolving(.outlook))
                }
                
                AttributionView()
            }

            Spacer(minLength: 14)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .animation(SkyAwareMotion.settle(reduceMotion), value: showsEmptyResolving)
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

    static func localAlertsPresentationState(
        readinessState: SummaryReadinessState,
        hasActiveAlerts: Bool,
        isLocationUnavailable: Bool
    ) -> LocalAlertsPresentationState {
        if isLocationUnavailable {
            return .unavailable
        }
        if hasActiveAlerts {
            return .alerts
        }

        switch readinessState {
        case .loadingLocation, .resolvingLocalContext:
            return .loading
        case .loadingLocalData, .ready, .locationUnavailable:
            return .empty
        }
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
            readinessState: .ready,
            resolutionState: SummaryResolutionState(),
            showsOfflineToken: false,
            headerCondenseProgress: 0,
            onOpenMapLayer: { _ in },
            onOpenAlerts: {},
            onOpenOutlooks: {}
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
            readinessState: .loadingLocalData,
            resolutionState: SummaryResolutionState(),
            showsOfflineToken: true,
            headerCondenseProgress: 0,
            onOpenMapLayer: { _ in },
            onOpenAlerts: {},
            onOpenOutlooks: {}
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}
