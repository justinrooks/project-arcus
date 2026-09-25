//
//  SummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI
import Foundation
import ArcusCore

// MARK: Previews
#Preview("Summary – Thunderstorms") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .thunderstorm,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Tornado Primary") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Moderate Storm Risk") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .moderate,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Quiet Weather") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – No Active Alerts") {
    NavigationStack {
        SummaryPreviewContent(
            stormSetup: SummaryPreviewData.stormSetup,
            stormSetupPreferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            todayContentState: .current,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: [],
            alerts: [],
            localAlertsDisplayState: .current(content: .empty, source: .cached)
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Active Alerts") {
    NavigationStack {
        SummaryPreviewContent(
            stormSetup: SummaryPreviewData.stormSetup,
            stormSetupPreferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            stormRisk: .moderate,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .current,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows,
            localAlertsDisplayState: .current(content: .populated, source: .cached)
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Storm Setup Visible") {
    NavigationStack {
        SummaryPreviewContent(
            stormSetup: SummaryPreviewData.stormSetup,
            stormSetupPreferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            stormRisk: .moderate,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .current,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: [],
            alerts: [],
            localAlertsDisplayState: .current(content: .empty, source: .cached)
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Storm Setup Hidden") {
    NavigationStack {
        SummaryPreviewContent(
            stormSetup: nil,
            stormSetupPreferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            stormRisk: .moderate,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .current,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: [],
            alerts: [],
            localAlertsDisplayState: .current(content: .empty, source: .cached)
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – AX1 Stacked Awareness") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .high,
            severeRisk: .hail(probability: 0.30),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            alerts: []
        )
        .environment(\.dynamicTypeSize, .accessibility1)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – No Cache Resolving Weather") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: nil,
            severeRisk: nil,
            fireRisk: nil,
            weather: nil,
            todayContentState: .noCacheResolving,
            readinessState: .loadingLocalData,
            showsOfflineToken: false,
            outlook: nil,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Weather") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: nil,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Complete") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .moderate,
            severeRisk: .hail(probability: 0.20),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Empty Alerts") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Unavailable Weather") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: nil,
            severeRisk: nil,
            fireRisk: nil,
            weather: nil,
            todayContentState: .unavailable,
            readinessState: .ready,
            showsOfflineToken: false,
            outlook: nil,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Populated Alerts") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Risk") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .high,
            severeRisk: .tornado(probability: 0.20),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Local Alerts Location Unavailable") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            readinessState: .locationUnavailable,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – No Cache Resolving") {
    NavigationStack {
        SummaryPreviewContent(
            snap: nil,
            stormRisk: nil,
            severeRisk: nil,
            fireRisk: nil,
            weather: nil,
            todayContentState: .noCacheResolving,
            readinessState: .loadingLocalData,
            outlook: nil,
            mesos: [],
            alerts: [],
            hasCachedProjectionForAlerts: false,
            lastHotAlertsLoadAt: nil
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Valid Cache Current") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .extreme,
            weather: SummaryPreviewData.weather,
            todayContentState: .current,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Composite") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .moderate,
            severeRisk: .hail(probability: 0.20),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows,
            resolutionState: SummaryPreviewData.calmRefreshState()
        )
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Empty Local Alerts") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: [],
            alerts: [],
            resolutionState: SummaryPreviewData.calmRefreshState(primaryTask: .alerts)
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Stale Cache") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .slight,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            todayContentState: .degraded,
            showsOfflineToken: true,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows
        )
        .environment(\.colorScheme, .light)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Stale Refreshing") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .moderate,
            severeRisk: .hail(probability: 0.15),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .staleRefreshing,
            showsOfflineToken: true,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: [],
            alerts: [],
            resolutionState: SummaryPreviewData.calmRefreshState(primaryTask: .weather)
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Degraded With Useful Cached Content") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .high,
            severeRisk: .tornado(probability: 0.20),
            fireRisk: .extreme,
            weather: SummaryPreviewData.weather,
            todayContentState: .degraded,
            showsOfflineToken: true,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Unavailable No Useful Data") {
    NavigationStack {
        SummaryPreviewContent(
            snap: nil,
            stormRisk: nil,
            severeRisk: nil,
            fireRisk: nil,
            weather: nil,
            todayContentState: .unavailable,
            readinessState: .ready,
            outlook: nil,
            mesos: [],
            alerts: [],
            hasCachedProjectionForAlerts: false,
            lastHotAlertsLoadAt: nil
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Partial Data Available") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .moderate,
            severeRisk: nil,
            fireRisk: nil,
            weather: nil,
            todayContentState: .current,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: [MD.sampleDiscussionDTOs[0]],
            alerts: [],
            hasCachedProjectionForAlerts: true,
            lastHotAlertsLoadAt: .now
        )
        .environment(\.dynamicTypeSize, .accessibility3)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Current Weather Retained During Refresh") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows,
            resolutionState: SummaryPreviewData.calmRefreshState(primaryTask: .weather)
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Atmospheric Values Retained During Refresh") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows,
            resolutionState: SummaryPreviewData.calmRefreshState(primaryTask: .weather)
        )
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Local Alerts Update Present") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows,
            resolutionState: SummaryPreviewData.calmRefreshState(primaryTask: .alerts)
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Storm Setup Ordering") {
    NavigationStack {
        SummaryPreviewContent(
            stormSetup: SummaryPreviewData.stormSetup,
            stormSetupPreferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            stormRisk: .moderate,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            locationTimeZone: TimeZone(identifier: "America/Denver")!,
            todayContentState: .current,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows,
            localAlertsDisplayState: .current(content: .populated, source: .cached)
        )
        .environment(\.dynamicTypeSize, .accessibility1)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Storm Setup Loading") {
    NavigationStack {
        SummaryPreviewContent(
            stormSetup: nil,
            stormSetupPreferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            stormRisk: .moderate,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            locationTimeZone: TimeZone(identifier: "America/Denver")!,
            todayContentState: .cachedRefreshing,
            isRefreshInFlight: true,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows,
            resolutionState: SummaryPreviewData.calmRefreshState(primaryTask: .weather),
            localAlertsDisplayState: .current(content: .populated, source: .cached)
        )
        .environment(\.dynamicTypeSize, .accessibility1)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Home – Atomic Presentation Contract") {
    HomePresentationContractPreview()
}

@MainActor
private struct HomePresentationContractPreview: View {
    @State private var scenario: Scenario = .refreshing

    private enum Scenario: String, CaseIterable {
        case cold = "Cold start"
        case warm = "Warm cache"
        case refreshing = "Refreshing"
        case failed = "Failed refresh"
        case empty = "Accepted empty"
        case changedLocation = "Location changed"
    }

    private var presentation: HomeVisiblePresentation {
        let key = "preview:current-location"
        let cached = Self.record(key: key, at: 100, risk: .slight)
        let attemptID = UUID(uuid: (0, 0, 0, 0, 0, 0, 4, 97, 0, 0, 0, 0, 0, 0, 0, 1))
        var state = HomeVisiblePresentation(contextKey: key)

        switch scenario {
        case .cold:
            break
        case .warm:
            state.apply(.persistedFallback(cached))
        case .refreshing:
            state.apply(.persistedFallback(cached))
            state.apply(.refreshStarted(id: attemptID, source: .manual, projectionKey: key))
        case .failed:
            state.apply(.persistedFallback(cached))
            state.apply(.refreshStarted(id: attemptID, source: .manual, projectionKey: key))
            state.apply(.failed(id: attemptID))
        case .empty:
            let empty = Self.record(key: key, at: 200, risk: nil, acceptedAlerts: true)
            state.apply(.coreAccepted(
                .init(record: empty, riskProfileChange: nil),
                .init(weather: .some(nil))
            ))
        case .changedLocation:
            state.apply(.persistedFallback(cached))
            state.apply(.contextChanged(projectionKey: "preview:next-location"))
        }
        return state
    }

    var body: some View {
        let current = presentation
        VStack(alignment: .leading, spacing: 16) {
            Text("Production Home state")
                .font(.headline)
            Text("Phase: \(String(describing: current.phase))")
            Text("Accepted risk: \(current.revision?.stormRisk.map { String(describing: $0) } ?? "none")")
            Text("Context: \(current.contextKey ?? "unavailable")")
                .font(.caption)
                .foregroundStyle(.secondary)
            ViewThatFits {
                HStack {
                    scenarioButtons
                }
                VStack(alignment: .leading) {
                    scenarioButtons
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.skyAwareBackground)
    }

    @ViewBuilder
    private var scenarioButtons: some View {
        ForEach(Scenario.allCases, id: \.self) { value in
            Button(value.rawValue) { scenario = value }
                .buttonStyle(.bordered)
                .font(.caption)
        }
    }

    private static func record(
        key: String,
        at timestamp: TimeInterval,
        risk: StormRiskLevel?,
        acceptedAlerts: Bool = false
    ) -> HomeProjectionRecord {
        let date = Date(timeIntervalSince1970: timestamp)
        return HomeProjectionRecord(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            projectionKey: key,
            latitude: 39,
            longitude: -104,
            h3Cell: 1,
            countyCode: "COC001",
            forecastZone: "COZ001",
            fireZone: "COZ201",
            placemarkSummary: "Preview location",
            timeZoneId: "America/Denver",
            locationTimestamp: date,
            createdAt: date,
            updatedAt: date,
            lastViewedAt: date,
            weather: risk == nil ? nil : SummaryPreviewData.weather,
            stormRisk: risk,
            severeRisk: risk == nil ? nil : .allClear,
            fireRisk: risk == nil ? nil : .clear,
            activeAlerts: [],
            activeMesos: [],
            lastHotAlertsLoadAt: acceptedAlerts ? date : nil,
            lastSlowProductsLoadAt: date,
            lastWeatherLoadAt: date
        )
    }
}

private struct SummaryPreviewContent: View {
    let snap: LocationSnapshot?
    let stormSetup: StormSetupDTO?
    let stormSetupPreferences: StormSetupPreferences
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let weather: SummaryWeather?
    let locationTimeZone: TimeZone
    let todayContentState: TodayContentState
    let readinessState: SummaryReadinessState
    let showsOfflineToken: Bool
    let isRefreshInFlight: Bool
    let outlook: ConvectiveOutlookDTO?
    let mesos: [MdDTO]
    let alerts: [AlertDTO]
    let resolutionState: SummaryResolutionState
    let localAlertsDisplayState: LocalAlertsDisplayState?
    let hasCachedProjectionForAlerts: Bool
    let lastHotAlertsLoadAt: Date?
    let isCurrentContextResolvedInPipeline: Bool

    init(
        snap: LocationSnapshot? = SummaryPreviewData.snapshot,
        stormSetup: StormSetupDTO? = nil,
        stormSetupPreferences: StormSetupPreferences = .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        fireRisk: FireRiskLevel? = .extreme,
        weather: SummaryWeather?,
        locationTimeZone: TimeZone = .current,
        todayContentState: TodayContentState = .current,
        readinessState: SummaryReadinessState = .ready,
        showsOfflineToken: Bool = false,
        isRefreshInFlight: Bool = false,
        outlook: ConvectiveOutlookDTO? = ConvectiveOutlook.sampleOutlookDtos.first,
        mesos: [MdDTO] = MD.sampleDiscussionDTOs,
        alerts: [AlertDTO] = Watch.sampleWatchRows,
        resolutionState: SummaryResolutionState = SummaryResolutionState(),
        localAlertsDisplayState: LocalAlertsDisplayState? = nil,
        hasCachedProjectionForAlerts: Bool = true,
        lastHotAlertsLoadAt: Date? = .now,
        isCurrentContextResolvedInPipeline: Bool = false
    ) {
        self.snap = snap
        self.stormSetup = stormSetup
        self.stormSetupPreferences = stormSetupPreferences
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
        self.weather = weather
        self.locationTimeZone = locationTimeZone
        self.todayContentState = todayContentState
        self.readinessState = readinessState
        self.showsOfflineToken = showsOfflineToken
        self.isRefreshInFlight = isRefreshInFlight
        self.outlook = outlook
        self.mesos = mesos
        self.alerts = alerts
        self.resolutionState = resolutionState
        self.localAlertsDisplayState = localAlertsDisplayState
        self.hasCachedProjectionForAlerts = hasCachedProjectionForAlerts
        self.lastHotAlertsLoadAt = lastHotAlertsLoadAt
        self.isCurrentContextResolvedInPipeline = isCurrentContextResolvedInPipeline
    }

    var body: some View {
        let localAlertsDisplayState = localAlertsDisplayState ?? LocalAlertsDisplayState.from(
            todayContentState: todayContentState,
            hasCachedProjection: hasCachedProjectionForAlerts,
            isCurrentContextResolvedInPipeline: isCurrentContextResolvedInPipeline,
            lastHotAlertsLoadAt: lastHotAlertsLoadAt,
            hasActiveAlerts: !mesos.isEmpty || !alerts.isEmpty,
            isLocationUnavailable: readinessState == .locationUnavailable
        )

        SummaryView(
            snap: snap,
            stormSetup: stormSetup,
            stormSetupPreferences: stormSetupPreferences,
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            fireRisk: fireRisk,
            mesos: mesos,
            alerts: alerts,
            outlook: outlook,
            weather: weather,
            locationTimeZone: locationTimeZone,
            todayContentState: todayContentState,
            localAlertsDisplayState: localAlertsDisplayState,
            readinessState: readinessState,
            resolutionState: resolutionState,
            isRefreshInFlight: isRefreshInFlight,
            showsOfflineToken: showsOfflineToken,
            locationReliabilityRailState: .init(onOpen: {}, onDismiss: {}),
            onOpenMapLayer: { _ in },
            onOpenAlerts: {},
            onOpenOutlooks: {}
        )
    }
}

private enum SummaryPreviewData {
    static let snapshot = LocationSnapshot(
        coordinates: .init(latitude: 39.75, longitude: -104.44),
        timestamp: .now,
        accuracy: 20,
        placemarkSummary: "Bennett, CO"
    )

    static let weather = SummaryWeather(
        temperature: Measurement(value: 82.0, unit: .fahrenheit),
        symbolName: "sun.max.fill",
        conditionText: "Warm and humid",
        asOf: .now,
        dewPoint: Measurement(value: 68.0, unit: .fahrenheit),
        humidity: 0.66,
        windSpeed: Measurement(value: 22.0, unit: .milesPerHour),
        windGust: Measurement(value: 34.0, unit: .milesPerHour),
        windDirection: "SSW",
        pressure: Measurement(value: 29.78, unit: .inchesOfMercury),
        pressureTrend: "falling"
    )

    static let stormSetup = StormSetupDTO(
        h3Cell: 8_623_451_234_567_890,
        freshness: .init(
            isStale: false,
            isDegraded: false,
            modelRunTime: .now,
            sourceValidTime: .now,
            forecastHour: 3,
            fetchedAt: .now,
            expiresAt: .now.addingTimeInterval(3_600)
        ),
        source: .init(
            model: "HRRR",
            product: "Storm Setup",
            domain: "severe",
            fieldSetVersion: "1",
            sourceKind: "production",
            runTime: .now,
            validTime: .now,
            forecastHour: 3,
            bbox: .init(toplat: 41.5, leftlon: -104.3, rightlon: -96.2, bottomlat: 36.8),
            primaryDownloadURL: "https://example.invalid/storm-setup"
        ),
        raw: .init(
            mlcapeJkg: 1_850,
            mucapeJkg: 2_200.5,
            sbcapeJkg: 1_700,
            mlcinJkg: -42,
            srh01kmM2s2: 125.5,
            srh03kmM2s2: 175,
            shear06kmKt: 42,
            mllclM: 980,
            tempDewPtDeltaF: 4.5,
            threeCapeJkg: 95
        ),
        assessment: .init(
            overall: "strong",
            summary: "The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation.",
            instability: "supportive",
            moisture: "supportive",
            lowLevelRotation: "conditional",
            deepShear: "strong",
            cloudBase: "weak",
            capInhibition: "weak",
            limitingFactors: ["capping"],
            confidence: "high",
            primaryDrivers: ["instability", "shear"],
            stormMode: "supportive",
            stormModeHint: "supportive",
            trend: "conditional",
            compositeSignal: "strong"
        ),
        anvilEvidence: nil,
        centroid: .init(latitude: 39.5, longitude: -100.0),
        surfaceHeightMslM: 1132.4
    )

    static func calmRefreshState(primaryTask: SummaryProviderTask = .weather) -> SummaryResolutionState {
        var state = SummaryResolutionState()
        state.begin(task: primaryTask, sections: [.conditions, .atmosphere, .alerts, .outlook])
        return state
    }
}
