//
//  HomeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import OSLog
import SwiftData
import Foundation
import ArcusCore

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies
    @Environment(LocationSession.self) private var locationSession
    @Environment(RemoteAlertPresentationState.self) private var remoteAlertPresentationState
    @Environment(RuntimeConnectivityState.self) private var runtimeConnectivityState

    @AppStorage("stormSetupEnabled", store: UserDefaults.shared)
    private var stormSetupEnabled: Bool = false

    @AppStorage("detailedIngredientsEnabled", store: UserDefaults.shared)
    private var detailedIngredientsEnabled: Bool = false

    @Query(sort: [SortDescriptor(\HomeProjection.updatedAt, order: .reverse)])
    private var cachedProjections: [HomeProjection]

    @Query(sort: [SortDescriptor(\ConvectiveOutlook.published, order: .reverse)])
    private var cachedOutlooks: [ConvectiveOutlook]

    private let logger = Logger.appHomeRefresh
    private let locationReliabilityLogger = Logger.uiLocationReliability

    @State private var refreshPipeline: HomeRefreshPipeline
    @State private var selectedTab: HomeTab = .today
    @State private var selectedMapLayer: MapLayer = .categorical
    @State private var showsLocationReliabilityRail: Bool = false
    @State private var locationReliabilityRailQualifyingDay: String?
    @State private var locationReliabilityRailLastEligibilityReason: LocationReliabilitySummaryRailEligibilityReason?
    @State private var showsLocationReliabilitySheet: Bool = false
    @State private var lastStormSetupPreferences: StormSetupPreferences?

    private var isUITestStaticMode: Bool {
        ProcessInfo.processInfo.environment["UI_TESTS_STATIC_HOME"] == "1"
    }

    private var isUITestForceReliabilityRail: Bool {
        ProcessInfo.processInfo.environment["UI_TESTS_FORCE_RELIABILITY_RAIL"] == "1"
    }

    private var isPreviewMode: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var currentContextRefreshKey: LocationContext.RefreshKey? {
        locationSession.currentContext?.refreshKey
    }

    private var cachedOutlookDTOs: [ConvectiveOutlookDTO] {
        cachedOutlooks.map(\.dto)
    }

    private var displayedProjection: HomeProjectionRecord? {
        Self.selectProjection(from: cachedProjections, currentContext: locationSession.currentContext)?.record
    }

    private var newestCachedProjection: HomeProjectionRecord? {
        cachedProjections.first?.record
    }

    private var stormSetupPreferences: StormSetupPreferences {
        StormSetupPreferences(
            stormSetupEnabled: stormSetupEnabled,
            detailedIngredientsEnabled: detailedIngredientsEnabled
        )
    }

    private var displayedStormSetup: StormSetupDTO? {
        let response = Self.selectStormSetupCurrentResponse(
            projection: displayedProjection,
            currentContext: locationSession.currentContext,
            pipelineValue: refreshPipeline.stormSetupCurrentResponse,
            pipelineRefreshKey: refreshPipeline.stormSetupRefreshKey,
            now: Date()
        )
        return response.map(StormSetupDTO.init(response:)) ?? Self.selectStormSetup(
            projection: displayedProjection,
            currentContext: locationSession.currentContext,
            pipelineValue: refreshPipeline.stormSetup,
            pipelineRefreshKey: refreshPipeline.stormSetupRefreshKey,
            now: Date()
        )
    }

    private var displayedStormSetupCurrentResponse: StormSetupCurrentResponse? {
        Self.selectStormSetupCurrentResponse(
            projection: displayedProjection,
            currentContext: locationSession.currentContext,
            pipelineValue: refreshPipeline.stormSetupCurrentResponse,
            pipelineRefreshKey: refreshPipeline.stormSetupRefreshKey,
            now: Date()
        )
    }

    private var displayedStormSetupProfileAnalysisResponse: AnvilAnalyzeProfileResponse? {
        guard stormSetupPreferences.effectiveDetailedIngredientsEnabled else { return nil }
        return displayedStormSetupCurrentResponse?.profileAnalysis
    }

    private var resolvedLocationTimeZone: TimeZone {
        Self.resolveLocationTimeZone(
            selectedProjection: displayedProjection,
            currentContext: locationSession.currentContext,
            newestStartupProjection: newestCachedProjection
        )
    }

    private var isCurrentContextResolvedInPipeline: Bool {
        guard let currentContextRefreshKey else { return false }
        return currentContextRefreshKey == refreshPipeline.lastResolvedLocationScopedRefreshKey
    }

    private var usesPipelineSummaryFallback: Bool {
        displayedProjection == nil && isCurrentContextResolvedInPipeline
    }

    private var displayedLocationSnapshot: LocationSnapshot? {
        Self.preferredSummaryValue(
            projectionValue: displayedProjection?.locationSnapshot,
            pipelineValue: refreshPipeline.snap,
            prefersPipelineValue: isCurrentContextResolvedInPipeline
        )
    }

    private var displayedStormRisk: StormRiskLevel? {
        Self.preferredSummaryValue(
            projectionValue: displayedProjection?.stormRisk,
            pipelineValue: refreshPipeline.stormRisk,
            prefersPipelineValue: isCurrentContextResolvedInPipeline
        )
    }

    private var displayedSevereRisk: SevereWeatherThreat? {
        Self.preferredSummaryValue(
            projectionValue: displayedProjection?.severeRisk,
            pipelineValue: refreshPipeline.severeRisk,
            prefersPipelineValue: isCurrentContextResolvedInPipeline
        )
    }

    private var displayedFireRisk: FireRiskLevel? {
        Self.preferredSummaryValue(
            projectionValue: displayedProjection?.fireRisk,
            pipelineValue: refreshPipeline.fireRisk,
            prefersPipelineValue: isCurrentContextResolvedInPipeline
        )
    }

    private var displayedWeather: SummaryWeather? {
        Self.preferredSummaryValue(
            projectionValue: displayedProjection?.weather,
            pipelineValue: refreshPipeline.summaryWeather,
            prefersPipelineValue: isCurrentContextResolvedInPipeline
        )
    }

    private var displayedAirQuality: AirQualityCurrentResponse? {
        isCurrentContextResolvedInPipeline ? refreshPipeline.airQuality : nil
    }

    private var displayedMesos: [MdDTO] {
        if isUITestStaticMode && refreshPipeline.mesos.isEmpty == false {
            return refreshPipeline.mesos
        }
        if isCurrentContextResolvedInPipeline {
            return refreshPipeline.mesos
        }
        return displayedProjection?.activeMesos ?? []
    }

    private var displayedAlerts: [AlertDTO] {
        if isUITestStaticMode && refreshPipeline.alerts.isEmpty == false {
            return refreshPipeline.alerts
        }
        if isCurrentContextResolvedInPipeline {
            return refreshPipeline.alerts
        }
        return displayedProjection?.activeAlerts ?? []
    }

    private var displayedOutlook: ConvectiveOutlookDTO? {
        Self.preferredOutlook(
            cachedOutlook: cachedOutlooks.first?.dto,
            liveOutlooks: refreshPipeline.outlooks,
            liveOutlook: refreshPipeline.outlook
        )
    }

    private var displayedOutlooks: [ConvectiveOutlookDTO] {
        Self.preferredOutlooks(
            cachedOutlooks: cachedOutlookDTOs,
            liveOutlooks: refreshPipeline.outlooks
        )
    }

    private var localAlertsDisplayState: LocalAlertsDisplayState {
        LocalAlertsDisplayState.from(
            todayContentState: todayContentState,
            hasCachedProjection: displayedProjection != nil,
            isCurrentContextResolvedInPipeline: isCurrentContextResolvedInPipeline,
            lastHotAlertsLoadAt: displayedProjection?.lastHotAlertsLoadAt,
            hasActiveAlerts: !displayedMesos.isEmpty || !displayedAlerts.isEmpty,
            isLocationUnavailable: readinessState == .locationUnavailable
        )
    }

    private var todayContentState: TodayContentState {
        TodayContentState.from(
            readinessState: readinessState,
            hasCachedContent: displayedProjection != nil,
            hasLiveContent: usesPipelineSummaryFallback || (
                isUITestStaticMode && (!refreshPipeline.mesos.isEmpty || !refreshPipeline.alerts.isEmpty)
            ),
            isRefreshing: refreshPipeline.isRefreshInFlight,
            isOffline: runtimeConnectivityState.isOffline
        )
    }

    private var readinessState: SummaryReadinessState {
        if locationSession.authorizationStatus == .denied || locationSession.authorizationStatus == .restricted {
            return .locationUnavailable
        }

        return Self.readinessState(
            startupState: locationSession.startupState,
            hasContext: locationSession.currentContext != nil,
            hasResolvedLocalData: currentContextRefreshKey == refreshPipeline.lastResolvedLocationScopedRefreshKey,
            stormRisk: displayedStormRisk,
            severeRisk: displayedSevereRisk,
            fireRisk: displayedFireRisk
        )
    }

    private var isEmptyResolvingSummary: Bool {
        todayContentState.showsResolvingSurface
    }

    init(
        initialSnap: LocationSnapshot? = nil,
        initialStormRisk: StormRiskLevel? = nil,
        initialSevereRisk: SevereWeatherThreat? = nil,
        initialFireRisk: FireRiskLevel? = nil,
        initialStormSetup: StormSetupDTO? = nil,
        initialStormSetupCurrentResponse: StormSetupCurrentResponse? = nil,
        initialStormSetupRefreshKey: LocationContext.RefreshKey? = nil,
        initialMesos: [MdDTO] = [],
        initialAlerts: [AlertDTO] = [],
        initialOutlooks: [ConvectiveOutlookDTO] = [],
        initialOutlook: ConvectiveOutlookDTO? = nil
    ) {
        _refreshPipeline = State(
            initialValue: HomeRefreshPipeline(
                initialSnap: initialSnap,
                initialStormRisk: initialStormRisk,
                initialSevereRisk: initialSevereRisk,
                initialFireRisk: initialFireRisk,
                initialStormSetup: initialStormSetup,
                initialStormSetupCurrentResponse: initialStormSetupCurrentResponse,
                initialStormSetupRefreshKey: initialStormSetupRefreshKey,
                initialMesos: initialMesos,
                initialAlerts: initialAlerts,
                initialOutlooks: initialOutlooks,
                initialOutlook: initialOutlook
            )
        )
    }

    private var refreshEnvironment: HomeRefreshPipeline.Environment {
        HomeRefreshPipeline.Environment(
            logger: logger,
            sync: dependencies.spcSync,
            outlooks: dependencies.spcOutlook,
            coordinator: dependencies.homeIngestionCoordinator,
            locationSession: locationSession
        )
    }

    var body: some View {
        ZStack {
            Color(.skyAwareBackground).ignoresSafeArea()

            TabView(selection: $selectedTab) {
                Tab("Today", systemImage: "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted", value: .today) {
                    TodayTabView(
                        snap: displayedLocationSnapshot,
                        stormSetup: displayedStormSetup,
                        stormSetupProfileAnalysisResponse: displayedStormSetupProfileAnalysisResponse,
                        stormSetupPreferences: stormSetupPreferences,
                        stormRisk: displayedStormRisk,
                        severeRisk: displayedSevereRisk,
                        fireRisk: displayedFireRisk,
                        mesos: displayedMesos,
                        alerts: displayedAlerts,
                        outlook: displayedOutlook,
                        weather: displayedWeather,
                        airQuality: displayedAirQuality,
                        locationTimeZone: resolvedLocationTimeZone,
                        todayContentState: todayContentState,
                        localAlertsDisplayState: localAlertsDisplayState,
                        readinessState: readinessState,
                        resolutionState: refreshPipeline.resolutionState,
                        isRefreshInFlight: refreshPipeline.isRefreshInFlight,
                        showsOfflineToken: runtimeConnectivityState.isOffline,
                        locationReliabilityRailState: showsLocationReliabilityRail
                            ? SummaryView.LocationReliabilityRailState(
                                onOpen: openLocationReliabilityRail,
                                onDismiss: dismissLocationReliabilityRailForToday
                            )
                            : nil,
                        onOpenMapLayer: openMap,
                        onOpenAlerts: openAlertsTab,
                        onOpenOutlooks: openOutlooksTab
                    ) {
                        await refreshPipeline.forceRefreshCurrentContext(
                            showsLoading: true,
                            environment: refreshEnvironment
                        )
                    }
                }

                Tab("Alerts", systemImage: "exclamationmark.triangle", value: .alerts) {
                    NavigationStack {
                        AlertView(
                            mesos: displayedMesos,
                            alerts: displayedAlerts,
                            focusedAlertRequest: remoteAlertPresentationState.focusRequest,
                            onRefresh: {
                                logger.notice("Manual alerts refresh requested")
                                refreshPipeline.resetLocationRefreshContext()
                                await refreshPipeline.forceRefreshCurrentContext(
                                    showsLoading: true,
                                    environment: refreshEnvironment
                                )
                            },
                            onFocusedAlertRequestHandled: { requestID in
                                remoteAlertPresentationState.clearFocusRequest(id: requestID)
                            }
                        )
                        .background(.skyAwareBackground)
                        .navigationTitle("Active Alerts")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                    }
                    .background(Color(.skyAwareBackground).ignoresSafeArea())
                }
                .badge(displayedMesos.count + displayedAlerts.count)

                Tab("Map", systemImage: "map", value: .map) {
                    MapScreenView(selectedLayer: $selectedMapLayer)
                        .toolbar(.hidden, for: .navigationBar)
                }

                Tab("Outlooks", systemImage: "list.clipboard.fill", value: .outlooks) {
                    NavigationStack {
                        ConvectiveOutlookView(
                            dtos: displayedOutlooks,
                            refreshStatus: refreshPipeline.outlookRefreshStatus,
                            onRefresh: {
                                logger.notice("Manual convective outlook refresh requested")
                                await refreshPipeline.refreshOutlooksManually(environment: refreshEnvironment)
                            }
                        )
                        .background(.skyAwareBackground)
                        .navigationTitle("Convective Outlooks")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                    }
                    .background(Color(.skyAwareBackground).ignoresSafeArea())
                }

                Tab("Settings", systemImage: "gearshape", value: .settings) {
                    NavigationStack {
                        SettingsView()
                            .background(.skyAwareBackground)
                            .navigationTitle("Settings")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbarBackground(.visible, for: .navigationBar)
                            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                    }
                    .background(Color(.skyAwareBackground).ignoresSafeArea())
                }
            }
            .background(Color(.skyAwareBackground).ignoresSafeArea())
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.skyAwareBackground.opacity(isEmptyResolvingSummary ? 0.68 : 1.0), for: .tabBar)
            .animation(SkyAwareMotion.settle(reduceMotion), value: isEmptyResolvingSummary)
            .ignoresSafeArea(edges: .bottom)

            if isEmptyResolvingSummary {
                RoundedRectangle(cornerRadius: SkyAwareRadius.section, style: .continuous)
                    .fill(Color.skyAwareBackground.opacity(0.28))
                    .frame(height: 96)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .tint(.skyAwareAccent)
        .task {
            if isPreviewMode { return }
            if isUITestStaticMode { return }
            refreshPipeline.updateEnvironment(refreshEnvironment)
            await refreshPipeline.handleScenePhaseChange(scenePhase, environment: refreshEnvironment)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard isUITestStaticMode == false else { return }
            Task {
                await refreshPipeline.handleScenePhaseChange(newPhase, environment: refreshEnvironment)
            }
        }
        .onChange(of: currentContextRefreshKey) { _, newKey in
            guard isUITestStaticMode == false else { return }
            Task {
                await refreshPipeline.handleContextRefreshKeyChange(
                    newKey,
                    scenePhase: scenePhase,
                    environment: refreshEnvironment
                )
            }
        }
        .onChange(of: stormSetupEnabled) { _, _ in
            scheduleStormSetupSettingsRefreshIfNeeded()
        }
        .onChange(of: detailedIngredientsEnabled) { _, _ in
            scheduleStormSetupSettingsRefreshIfNeeded()
        }
        .onChange(of: remoteAlertPresentationState.focusRequest?.id) { _, newValue in
            guard newValue != nil else { return }
            selectedTab = .alerts
        }
        .onChange(of: locationSession.reliabilityState) { _, _ in
            refreshLocationReliabilityRail()
        }
        .onChange(of: displayedStormRisk) { _, _ in
            refreshLocationReliabilityRail()
        }
        .onChange(of: displayedSevereRisk) { _, _ in
            refreshLocationReliabilityRail()
        }
        .task {
            refreshLocationReliabilityRail()
        }
        .sheet(isPresented: $showsLocationReliabilitySheet) {
            LocationReliabilitySummaryExplanationSheet(
                reliability: locationSession.reliabilityState,
                onEnableAlways: enableAlwaysFromReliabilitySheet,
                onNotNow: dismissLocationReliabilitySheetForToday
            )
        }
        .onOpenURL { url in
            guard let tab = Self.tabSelection(forIncomingURL: url) else {
                return
            }

            selectedTab = tab
        }
    }

    private func scheduleStormSetupSettingsRefreshIfNeeded() {
        guard isPreviewMode == false, isUITestStaticMode == false else {
            return
        }

        let currentPreferences = stormSetupPreferences
        guard Self.shouldRefreshStormSetupSettings(
            previousPreferences: lastStormSetupPreferences,
            currentPreferences: currentPreferences
        ) else {
            return
        }

        lastStormSetupPreferences = currentPreferences
        refreshPipeline.updateEnvironment(refreshEnvironment)
        Task {
            await refreshPipeline.enqueueRefresh(.timer, environment: refreshEnvironment)
        }
    }
}

extension HomeView {
    private func openMap(_ layer: MapLayer) {
        selectedMapLayer = layer
        selectedTab = .map
    }

    private func openAlertsTab() {
        selectedTab = .alerts
    }

    private func openOutlooksTab() {
        selectedTab = .outlooks
    }

    enum HomeTab: Hashable {
        case today
        case alerts
        case map
        case outlooks
        case settings
    }

    static func tabSelection(forIncomingURL url: URL) -> HomeTab? {
        guard let destination = WidgetRouteURL.destination(from: url) else {
            return nil
        }

        switch destination {
        case .summary:
            return .today
        }
    }

    private func refreshLocationReliabilityRail() {
        if isUITestForceReliabilityRail {
            let qualifyingDay = LocationReliabilitySummaryRailEligibility.localDayString(
                for: .now,
                timeZone: .autoupdatingCurrent
            )
            if showsLocationReliabilityRail == false {
                locationReliabilityLogger.debug("Forcing location reliability rail visible for UI test coverage")
            }
            showsLocationReliabilityRail = true
            locationReliabilityRailQualifyingDay = qualifyingDay
            locationReliabilityRailLastEligibilityReason = .eligible
            return
        }

        let now = Date.now
        let timeZone = TimeZone.autoupdatingCurrent
        let reliability = locationSession.reliabilityState
        let ledger = LocationReliabilityAskLedger.live()
        let decision = LocationReliabilitySummaryRailEligibility.decision(
            reliability: reliability,
            stormRisk: displayedStormRisk,
            severeRisk: displayedSevereRisk,
            ledger: ledger.snapshot(),
            now: now,
            timeZone: timeZone
        )

        guard decision.isEligible else {
            if locationReliabilityRailLastEligibilityReason != decision.reason {
                locationReliabilityLogger.debug(
                    "Location reliability rail not shown reason=\(decision.reason.logName, privacy: .public)"
                )
                locationReliabilityRailLastEligibilityReason = decision.reason
            }
            showsLocationReliabilityRail = false
            locationReliabilityRailQualifyingDay = nil
            return
        }

        let qualifyingDay = LocationReliabilitySummaryRailEligibility.localDayString(for: now, timeZone: timeZone)
        let shouldRecordImpression = locationReliabilityRailQualifyingDay != qualifyingDay

        if showsLocationReliabilityRail == false {
            let snapshot = ledger.snapshot()
            locationReliabilityLogger.notice(
                "Showing location reliability rail qualifyingDay=\(qualifyingDay, privacy: .public) authorization=\(reliability.authorization.logName, privacy: .public) accuracy=\(reliability.accuracy.logName, privacy: .public) stormRisk=\(String(describing: displayedStormRisk), privacy: .public) severeRisk=\(String(describing: displayedSevereRisk), privacy: .public) askCount=\(snapshot.askCount, privacy: .public)"
            )
        }

        showsLocationReliabilityRail = true
        locationReliabilityRailQualifyingDay = qualifyingDay
        locationReliabilityRailLastEligibilityReason = .eligible

        if shouldRecordImpression {
            ledger.recordCountedRailImpression(at: now, qualifyingDay: qualifyingDay)
            let updatedSnapshot = ledger.snapshot()
            locationReliabilityLogger.info(
                "Counted location reliability rail impression qualifyingDay=\(qualifyingDay, privacy: .public) askCount=\(updatedSnapshot.askCount, privacy: .public)"
            )
        }
    }

    private func dismissLocationReliabilityRailForToday() {
        let now = Date.now
        let timeZone = TimeZone.autoupdatingCurrent
        let qualifyingDay = LocationReliabilitySummaryRailEligibility.localDayString(for: now, timeZone: timeZone)
        let ledger = LocationReliabilityAskLedger.live()
        ledger.recordSameDaySuppression(qualifyingDay: qualifyingDay)
        locationReliabilityLogger.notice("Dismissed location reliability rail for qualifyingDay=\(qualifyingDay, privacy: .public)")
        showsLocationReliabilityRail = false
        locationReliabilityRailQualifyingDay = nil
    }

    private func openLocationReliabilityRail() {
        recordLocationReliabilitySameDaySuppression()
        locationReliabilityLogger.notice("Opened location reliability explanation sheet from the summary rail")
        showsLocationReliabilitySheet = true
        showsLocationReliabilityRail = false
        locationReliabilityRailQualifyingDay = nil
    }

    private func dismissLocationReliabilitySheetForToday() {
        recordLocationReliabilitySameDaySuppression()
        locationReliabilityLogger.info("Deferred the location reliability explanation sheet for today")
        showsLocationReliabilitySheet = false
    }

    private func enableAlwaysFromReliabilitySheet() {
        recordLocationReliabilitySameDaySuppression()
        locationSession.openSettings()
        locationReliabilityLogger.notice("Opened system Settings from the location reliability sheet")
        showsLocationReliabilitySheet = false
    }

    private func recordLocationReliabilitySameDaySuppression(now: Date = .now, timeZone: TimeZone = .autoupdatingCurrent) {
        let qualifyingDay = LocationReliabilitySummaryRailEligibility.localDayString(for: now, timeZone: timeZone)
        LocationReliabilityAskLedger.live().recordSameDaySuppression(qualifyingDay: qualifyingDay)
    }

}
