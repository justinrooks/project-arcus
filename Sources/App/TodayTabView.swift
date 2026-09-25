import ArcusCore
import Foundation
import SwiftUI

struct TodayTabView: View {
    @State private var visibleWeatherState = TodayVisibleWeatherState()
    @State private var selectedSummaryAlert: AlertDTO?
    @State private var selectedSummaryAlertDetent: PresentationDetent = .medium

    let snap: LocationSnapshot?
    let stormSetup: StormSetupDTO?
    let stormSetupProfileAnalysisResponse: AnvilAnalyzeProfileResponse?
    let stormSetupPreferences: StormSetupPreferences
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let mesos: [MdDTO]
    let alerts: [AlertDTO]
    let outlook: ConvectiveOutlookDTO?
    let outlookPresentationState: ConvectiveOutlookPresentationState
    let weather: SummaryWeather?
    let airQuality: AirQualityCurrentResponse?
    let locationTimeZone: TimeZone
    let todayContentState: TodayContentState
    let localAlertsDisplayState: LocalAlertsDisplayState
    let readinessState: SummaryReadinessState
    let resolutionState: SummaryResolutionState
    let isRefreshInFlight: Bool
    let isStormSetupRefreshInFlight: Bool
    let showsOfflineToken: Bool
    let locationReliabilityRailState: SummaryView.LocationReliabilityRailState?
    let onOpenMapLayer: (MapLayer) -> Void
    let onOpenAlerts: () -> Void
    let onOpenOutlooks: () -> Void
    let refreshAction: () async -> Void
    let refreshStormSetupAction: () async -> Void

    private var weatherLocationIdentity: SummaryWeatherLocationIdentity? {
        SummaryWeatherLocationIdentity(snapshot: snap)
    }

    private var visibleWeather: SummaryWeather? {
        TodayVisibleWeatherState.resolve(
            liveWeather: weather,
            displayedWeather: visibleWeatherState.weather,
            isRefreshing: isRefreshInFlight,
            displayedWeatherLocationIdentity: visibleWeatherState.locationIdentity,
            weatherLocationIdentity: weatherLocationIdentity
        ).weather
    }

    private var visibleWeatherTaskState: TodayVisibleWeatherStateTaskState {
        TodayVisibleWeatherStateTaskState(
            liveWeather: weather,
            isRefreshing: isRefreshInFlight,
            weatherLocationIdentity: weatherLocationIdentity
        )
    }

    var body: some View {
        NavigationStack {
            if todayContentState.showsResolvingSurface {
                LoadingView(message: resolutionState.primaryActiveMessage ?? readinessState.statusText)
                    .toolbar(.hidden, for: .navigationBar)
                    .accessibilityIdentifier("today-no-cache-resolving")
            } else {
                ScrollView {
                    SummaryView(
                        snap: snap,
                        stormSetup: stormSetup,
                        stormSetupProfileAnalysisResponse: stormSetupProfileAnalysisResponse,
                        stormSetupPreferences: stormSetupPreferences,
                        stormRisk: stormRisk,
                        severeRisk: severeRisk,
                        fireRisk: fireRisk,
                        mesos: mesos,
                        alerts: alerts,
                        outlook: outlook,
                        outlookPresentationState: outlookPresentationState,
                        weather: visibleWeather,
                        airQuality: airQuality,
                        locationTimeZone: locationTimeZone,
                        todayContentState: todayContentState,
                        localAlertsDisplayState: localAlertsDisplayState,
                        readinessState: readinessState,
                        resolutionState: resolutionState,
                        isRefreshInFlight: isRefreshInFlight,
                        isStormSetupRefreshInFlight: isStormSetupRefreshInFlight,
                        showsOfflineToken: showsOfflineToken,
                        locationReliabilityRailState: locationReliabilityRailState,
                        onOpenMapLayer: onOpenMapLayer,
                        onOpenAlerts: onOpenAlerts,
                        onOpenOutlooks: onOpenOutlooks,
                        onSelectAlert: { alert in
                            selectedSummaryAlertDetent = .medium
                            selectedSummaryAlert = alert
                        },
                        onRefreshStormSetup: refreshStormSetupAction
                    )
                        .toolbar(.hidden, for: .navigationBar)
                        .background(.skyAwareBackground)
                }
                .accessibilityIdentifier("summary-scroll")
                .background(Color(.skyAwareBackground).ignoresSafeArea())
                .refreshable {
                    await refreshAction()
                }
            }
        }
        .background(Color(.skyAwareBackground).ignoresSafeArea())
        .sheet(item: $selectedSummaryAlert) { alert in
            NavigationStack {
                GeometryReader { geometry in
                    let isExpanded = selectedSummaryAlertDetent == .large
                    ScrollView {
                        AlertDetailView(alert: alert, layout: .sheet, isExpanded: isExpanded)
                            .padding(.top, 8)
                            .padding(.horizontal, 6)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: geometry.size.height,
                                maxHeight: isExpanded ? nil : geometry.size.height,
                                alignment: .top
                            )
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .background(.skyAwareBackground)
                }
                .navigationBarTitleDisplayMode(.inline)
            }
            .accessibilityIdentifier("summary-watch-detail-sheet")
            .presentationDetents([.medium, .large], selection: $selectedSummaryAlertDetent)
            .presentationDragIndicator(.visible)
        }
        .task(id: visibleWeatherTaskState) {
            visibleWeatherState = TodayVisibleWeatherState.resolve(
                liveWeather: weather,
                displayedWeather: visibleWeatherState.weather,
                isRefreshing: isRefreshInFlight,
                displayedWeatherLocationIdentity: visibleWeatherState.locationIdentity,
                weatherLocationIdentity: weatherLocationIdentity
            )
        }
    }
}

private struct TodayVisibleWeatherStateTaskState: Equatable {
    let liveWeather: SummaryWeather?
    let isRefreshing: Bool
    let weatherLocationIdentity: SummaryWeatherLocationIdentity?
}
