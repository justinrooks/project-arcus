import ArcusCore
import Foundation
import SwiftUI

struct TodayTabView: View {
    @State private var visibleWeatherState = TodayVisibleWeatherState()

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
    let weather: SummaryWeather?
    let airQuality: AirQualityCurrentResponse?
    let locationTimeZone: TimeZone
    let todayContentState: TodayContentState
    let localAlertsDisplayState: LocalAlertsDisplayState
    let readinessState: SummaryReadinessState
    let resolutionState: SummaryResolutionState
    let isRefreshInFlight: Bool
    let showsOfflineToken: Bool
    let locationReliabilityRailState: SummaryView.LocationReliabilityRailState?
    let onOpenMapLayer: (MapLayer) -> Void
    let onOpenAlerts: () -> Void
    let onOpenOutlooks: () -> Void
    let refreshAction: () async -> Void

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
                        weather: visibleWeather,
                        airQuality: airQuality,
                        locationTimeZone: locationTimeZone,
                        todayContentState: todayContentState,
                        localAlertsDisplayState: localAlertsDisplayState,
                        readinessState: readinessState,
                        resolutionState: resolutionState,
                        isRefreshInFlight: isRefreshInFlight,
                        showsOfflineToken: showsOfflineToken,
                        locationReliabilityRailState: locationReliabilityRailState,
                        onOpenMapLayer: onOpenMapLayer,
                        onOpenAlerts: onOpenAlerts,
                        onOpenOutlooks: onOpenOutlooks
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
