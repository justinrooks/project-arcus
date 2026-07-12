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

    static func selectProjection(
        from projections: [HomeProjectionRecord],
        currentContext: LocationContext?
    ) -> HomeProjectionRecord? {
        if let currentContext {
            let projectionKey = HomeProjection.projectionKey(for: currentContext)
            return projections.first(where: { $0.projectionKey == projectionKey })
        }

        return projections.max(by: { $0.updatedAt < $1.updatedAt })
    }

    static func selectStormSetup(
        projection: HomeProjectionRecord?,
        currentContext: LocationContext?,
        pipelineValue: StormSetupDTO?,
        pipelineRefreshKey: LocationContext.RefreshKey?,
        now: Date
    ) -> StormSetupDTO? {
        if let currentContext {
            let currentRefreshKey = currentContext.refreshKey
            if pipelineRefreshKey == currentRefreshKey,
               let pipelineValue,
               pipelineValue.freshness.expiresAt > now,
               pipelineValue.h3Cell == currentContext.h3Cell {
                return pipelineValue
            }

            guard let projection,
                  projection.projectionKey == HomeProjection.projectionKey(for: currentContext),
                  let stormSetup = projection.stormSetup,
                  stormSetup.freshness.expiresAt > now,
                  stormSetup.h3Cell == currentContext.h3Cell else {
                return nil
            }

            return stormSetup
        }

        guard let stormSetup = projection?.stormSetup,
              stormSetup.freshness.expiresAt > now else {
            return nil
        }

        return stormSetup
    }

    static func selectStormSetupCurrentResponse(
        projection: HomeProjectionRecord?,
        currentContext: LocationContext?,
        pipelineValue: StormSetupCurrentResponse?,
        pipelineRefreshKey: LocationContext.RefreshKey?,
        now: Date
    ) -> StormSetupCurrentResponse? {
        if let currentContext {
            let currentRefreshKey = currentContext.refreshKey
            if pipelineRefreshKey == currentRefreshKey,
               let pipelineValue,
               pipelineValue.setup.freshness.expiresAt > now,
               pipelineValue.setup.h3Cell == currentContext.h3Cell {
                return pipelineValue
            }

            guard let projection,
                  projection.projectionKey == HomeProjection.projectionKey(for: currentContext),
                  let response = projection.stormSetupCurrentResponse,
                  response.setup.freshness.expiresAt > now,
                  response.setup.h3Cell == currentContext.h3Cell else {
                return nil
            }
            return response
        }

        guard let response = projection?.stormSetupCurrentResponse,
              response.setup.freshness.expiresAt > now else {
            return nil
        }
        return response
    }

    static func resolveLocationTimeZone(
        selectedProjection: HomeProjectionRecord?,
        currentContext: LocationContext?,
        newestStartupProjection: HomeProjectionRecord?,
        fallback: TimeZone = .autoupdatingCurrent
    ) -> TimeZone {
        if let timeZoneIdentifier = selectedProjection?.timeZoneId,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            return timeZone
        }

        if let currentContext,
           let timeZoneIdentifier = currentContext.grid.timeZoneId,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            return timeZone
        }

        if currentContext == nil,
           let timeZoneIdentifier = newestStartupProjection?.timeZoneId,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            return timeZone
        }

        return fallback
    }

    static func selectProjection(
        from projections: [HomeProjection],
        currentContext: LocationContext?
    ) -> HomeProjection? {
        if let currentContext {
            let projectionKey = HomeProjection.projectionKey(for: currentContext)
            return projections.first(where: { $0.projectionKey == projectionKey })
        }

        return projections.max(by: { $0.updatedAt < $1.updatedAt })
    }

    static func showsBootstrapLoading(
        readinessState: SummaryReadinessState,
        isRefreshInFlight: Bool,
        hasProjection: Bool
    ) -> Bool {
        readinessState != .locationUnavailable &&
        hasProjection == false &&
        (isRefreshInFlight || readinessState != .ready)
    }

    static func preferredSummaryValue<T>(
        projectionValue: T?,
        pipelineValue: T?,
        prefersPipelineValue: Bool
    ) -> T? {
        if prefersPipelineValue {
            return pipelineValue ?? projectionValue
        }
        return projectionValue ?? pipelineValue
    }

    static func shouldRefreshStormSetupSettings(
        previousPreferences: StormSetupPreferences?,
        currentPreferences: StormSetupPreferences
    ) -> Bool {
        previousPreferences != currentPreferences
    }

    static func preferredOutlooks(
        cachedOutlooks: [ConvectiveOutlookDTO],
        liveOutlooks: [ConvectiveOutlookDTO]
    ) -> [ConvectiveOutlookDTO] {
        liveOutlooks.isEmpty ? cachedOutlooks : liveOutlooks
    }

    static func preferredOutlook(
        cachedOutlook: ConvectiveOutlookDTO?,
        liveOutlooks: [ConvectiveOutlookDTO],
        liveOutlook: ConvectiveOutlookDTO?
    ) -> ConvectiveOutlookDTO? {
        liveOutlooks.first ?? cachedOutlook ?? liveOutlook
    }

    struct LocationReliabilityRailState: Equatable {
        let shouldShowRail: Bool
        let qualifyingDay: String?
        let shouldRecordImpression: Bool
    }

    static func locationReliabilityRailState(
        reliability: LocationReliabilityState,
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        ledger: LocationReliabilityAskLedgerSnapshot,
        now: Date,
        timeZone: TimeZone,
        currentlyShownQualifyingDay: String?
    ) -> LocationReliabilityRailState {
        let decision = LocationReliabilitySummaryRailEligibility.decision(
            reliability: reliability,
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            ledger: ledger,
            now: now,
            timeZone: timeZone
        )

        guard decision.isEligible else {
            return .init(shouldShowRail: false, qualifyingDay: nil, shouldRecordImpression: false)
        }

        let qualifyingDay = LocationReliabilitySummaryRailEligibility.localDayString(for: now, timeZone: timeZone)
        let shouldRecordImpression = currentlyShownQualifyingDay != qualifyingDay
        return .init(
            shouldShowRail: true,
            qualifyingDay: qualifyingDay,
            shouldRecordImpression: shouldRecordImpression
        )
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

private struct TodayTabView: View {
    @State private var headerCondenseProgress: CGFloat = 0
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
                    locationTimeZone: locationTimeZone,
                    todayContentState: todayContentState,
                    localAlertsDisplayState: localAlertsDisplayState,
                    readinessState: readinessState,
                    resolutionState: resolutionState,
                    showsOfflineToken: showsOfflineToken,
                    headerCondenseProgress: headerCondenseProgress,
                    locationReliabilityRailState: locationReliabilityRailState,
                    onOpenMapLayer: onOpenMapLayer,
                    onOpenAlerts: onOpenAlerts,
                    onOpenOutlooks: onOpenOutlooks
                )
                    .toolbar(.hidden, for: .navigationBar)
                    .background(.skyAwareBackground)
            }
            .accessibilityIdentifier("summary-scroll")
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, newValue in
                let normalizedProgress = min(max((newValue - 6) / 68, 0), 1)
                if abs(headerCondenseProgress - normalizedProgress) > 0.001 {
                    headerCondenseProgress = normalizedProgress
                }
            }
            .background(Color(.skyAwareBackground).ignoresSafeArea())
            .refreshable {
                await refreshAction()
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

#Preview("Home") {
    HomeView(
        initialSnap: .init(
            coordinates: .init(latitude: 39.75, longitude: -104.44),
            timestamp: .now,
            accuracy: 20,
            placemarkSummary: "Bennett, CO"
        ),
        initialStormRisk: .slight,
        initialSevereRisk: .tornado(probability: 0.10),
        initialFireRisk: .extreme,
        initialMesos: MD.sampleDiscussionDTOs,
        initialAlerts: Watch.sampleWatchRows,
        initialOutlooks: ConvectiveOutlook.sampleOutlookDtos,
        initialOutlook: ConvectiveOutlook.sampleOutlookDtos.first
    )
    .environment(\.dependencies, Dependencies.unconfigured)
    .environment(LocationSession.preview)
    .environment(RemoteAlertPresentationState())
    .environment(RuntimeConnectivityState.preview)
    .modelContainer(HomeViewPreviewData.modelContainer)
}

@MainActor
private enum HomeViewPreviewData {
    static let modelContainer: ModelContainer = {
        let schema = Schema([HomeProjection.self, ConvectiveOutlook.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        if let previewContext = LocationSession.preview.currentContext {
            let projection = HomeProjection(
                context: previewContext,
                createdAt: .now,
                lastViewedAt: .now
            )
            projection.weatherPayload = HomeProjectionWeatherPayload(
                summary: SummaryWeather(
                    temperature: .init(value: 72, unit: .fahrenheit),
                    symbolName: "sun.max.fill",
                    conditionText: "Clear",
                    asOf: .now,
                    dewPoint: .init(value: 54, unit: .fahrenheit),
                    humidity: 0.45,
                    windSpeed: .init(value: 15, unit: .milesPerHour),
                    windGust: .init(value: 24, unit: .milesPerHour),
                    windDirection: "NW",
                    pressure: .init(value: 29.92, unit: .inchesOfMercury),
                    pressureTrend: "steady"
                )
            )
            projection.stormRisk = .slight
            projection.severeRisk = .tornado(probability: 0.10)
            projection.fireRisk = .extreme
            projection.activeMesos = MD.sampleDiscussionDTOs
            projection.activeAlerts = Watch.sampleWatchRows
            projection.updatedAt = .now
            context.insert(projection)
        }

        if let outlook = ConvectiveOutlook.sampleOutlookDtos.first {
            context.insert(
                ConvectiveOutlook(
                    title: outlook.title,
                    link: outlook.link,
                    published: outlook.published,
                    fullText: outlook.fullText,
                    summary: outlook.summary,
                    day: outlook.day,
                    riskLevel: outlook.riskLevel,
                    issued: outlook.issued ?? outlook.published,
                    validUntil: outlook.validUntil ?? outlook.published
                )
            )
        }

        try! context.save()
        return container
    }()
}
