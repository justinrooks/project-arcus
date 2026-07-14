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
            headerCondenseProgress: 0,
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
