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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies
    @Environment(LocationSession.self) private var locationSession
    @Environment(RemoteAlertPresentationState.self) private var remoteAlertPresentationState
    @Environment(RuntimeConnectivityState.self) private var runtimeConnectivityState

    @AppStorage("stormSetupEnabled", store: UserDefaults.shared)
    private var stormSetupEnabled: Bool = false

    @AppStorage("detailedIngredientsEnabled", store: UserDefaults.shared)
    private var detailedIngredientsEnabled: Bool = false

    @Query(sort: [SortDescriptor(\ConvectiveOutlook.published, order: .reverse)])
    private var cachedOutlooks: [ConvectiveOutlook]

    private let logger = Logger.appHomeRefresh
    private let locationReliabilityLogger = Logger.uiLocationReliability

    @State private var refreshPipeline: HomeRefreshPipeline
    @State private var selectedTab: HomeTab = .today
    @State private var selectedMapLayer: MapLayer = .categorical
    @State private var projectionRetentionTask: Task<Void, Never>?
    @State private var showsLocationReliabilityRail: Bool = false
    @State private var locationReliabilityRailQualifyingDay: String?
    @State private var locationReliabilityRailLastEligibilityReason: LocationReliabilitySummaryRailEligibilityReason?
    @State private var showsLocationReliabilitySheet: Bool = false
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

    private var currentProjectionKey: String? {
        locationSession.currentContext.map(HomeProjection.projectionKey(for:))
    }

    private var homeProjectionObservation: some View {
        HomeProjectionObservation(
            projectionKey: currentProjectionKey
        ) { visibleRevision, startup in
            let presentation = presentationSnapshot(
                now: Date(),
                visibleRevision: visibleRevision,
                startupProjection: startup
            )
            let readinessState = readinessState(presentation: presentation)
            let todayContentState = todayContentState(
                presentation: presentation,
                readinessState: readinessState
            )
            let localAlertsDisplayState = localAlertsDisplayState(
                presentation: presentation,
                todayContentState: todayContentState,
                readinessState: readinessState
            )
            let stormSetupProfileAnalysisResponse = stormSetupPreferences.effectiveDetailedIngredientsEnabled
                ? presentation.stormSetupCurrentResponse?.profileAnalysis
                : nil
            homeBody(
                presentation: presentation,
                readinessState: readinessState,
                todayContentState: todayContentState,
                localAlertsDisplayState: localAlertsDisplayState,
                stormSetupProfileAnalysisResponse: stormSetupProfileAnalysisResponse
            )
        }
    }

    private var cachedOutlookDTOs: [ConvectiveOutlookDTO] {
        cachedOutlooks.map(\.dto)
    }

    private func presentationSnapshot(
        now: Date,
        visibleRevision: HomeVisibleRevision?,
        startupProjection: HomeProjectionRecord?
    ) -> HomePresentationSnapshot {
        HomePresentationSnapshot(
            visibleRevision: visibleRevision,
            newestStartupProjection: startupProjection,
            currentContext: locationSession.currentContext,
            pipelineSnap: refreshPipeline.snap,
            pipelineStormRisk: refreshPipeline.stormRisk,
            pipelineSevereRisk: refreshPipeline.severeRisk,
            pipelineFireRisk: refreshPipeline.fireRisk,
            pipelineWeather: refreshPipeline.summaryWeather,
            pipelineAirQuality: refreshPipeline.airQuality,
            pipelineMesos: refreshPipeline.mesos,
            pipelineAlerts: refreshPipeline.alerts,
            resolvedLocationScopedRefreshKey: refreshPipeline.lastResolvedLocationScopedRefreshKey,
            alertSnapshotRefreshKey: refreshPipeline.alertSnapshotRefreshKey,
            pipelineStormSetup: refreshPipeline.stormSetup,
            pipelineStormSetupCurrentResponse: refreshPipeline.stormSetupCurrentResponse,
            stormSetupRefreshKey: refreshPipeline.stormSetupRefreshKey,
            isUITestStaticMode: isUITestStaticMode,
            now: now
        )
    }

    private var stormSetupPreferences: StormSetupPreferences {
        StormSetupPreferences(
            stormSetupEnabled: stormSetupEnabled,
            detailedIngredientsEnabled: detailedIngredientsEnabled
        )
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

    private func localAlertsDisplayState(
        presentation: HomePresentationSnapshot,
        todayContentState: TodayContentState,
        readinessState: SummaryReadinessState
    ) -> LocalAlertsDisplayState {
        LocalAlertsDisplayState.from(
            todayContentState: todayContentState,
            hasCachedProjection: presentation.projection != nil,
            isCurrentContextResolvedInPipeline: presentation.isCurrentContextCommittedAlertSnapshot,
            lastHotAlertsLoadAt: presentation.projection?.lastHotAlertsLoadAt,
            hasActiveAlerts: !presentation.mesos.isEmpty || !presentation.alerts.isEmpty,
            isLocationUnavailable: readinessState == .locationUnavailable
        )
    }

    private func todayContentState(
        presentation: HomePresentationSnapshot,
        readinessState: SummaryReadinessState
    ) -> TodayContentState {
        TodayContentState.from(
            readinessState: readinessState,
            hasCachedContent: presentation.projection != nil,
            hasLiveContent: (presentation.projection == nil && presentation.isCurrentContextResolvedInPipeline) || (
                isUITestStaticMode && (
                    !refreshPipeline.mesos.isEmpty ||
                    !refreshPipeline.alerts.isEmpty ||
                    presentation.stormSetup != nil ||
                    ProcessInfo.processInfo.environment["UI_TESTS_STORM_SETUP_FIXTURE"] != nil
                )
            ),
            isRefreshing: refreshPipeline.isRefreshInFlight,
            isOffline: runtimeConnectivityState.isOffline
        )
    }

    private func readinessState(presentation: HomePresentationSnapshot) -> SummaryReadinessState {
        if locationSession.authorizationStatus == .denied || locationSession.authorizationStatus == .restricted {
            return .locationUnavailable
        }

        return Self.readinessState(
            startupState: locationSession.startupState,
            hasContext: locationSession.currentContext != nil,
            hasResolvedLocalData: currentContextRefreshKey == refreshPipeline.lastResolvedLocationScopedRefreshKey,
            stormRisk: presentation.stormRisk,
            severeRisk: presentation.severeRisk,
            fireRisk: presentation.fireRisk
        )
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
        initialOutlook: ConvectiveOutlookDTO? = nil,
        initialRefreshInFlight: Bool = false
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
                initialOutlook: initialOutlook,
                initialRefreshInFlight: initialRefreshInFlight
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

    private var settingsTab: some View {
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

    private func todayTab(
        presentation: HomePresentationSnapshot,
        readinessState: SummaryReadinessState,
        todayContentState: TodayContentState,
        localAlertsDisplayState: LocalAlertsDisplayState,
        stormSetupProfileAnalysisResponse: AnvilAnalyzeProfileResponse?
    ) -> some View {
        TodayTabView(
            snap: presentation.locationSnapshot,
            stormSetup: presentation.stormSetup,
            stormSetupProfileAnalysisResponse: stormSetupProfileAnalysisResponse,
            stormSetupPreferences: stormSetupPreferences,
            stormRisk: presentation.stormRisk,
            severeRisk: presentation.severeRisk,
            fireRisk: presentation.fireRisk,
            mesos: presentation.mesos,
            alerts: presentation.alerts,
            outlook: displayedOutlook,
            weather: presentation.weather,
            airQuality: presentation.airQuality,
            locationTimeZone: presentation.locationTimeZone,
            todayContentState: todayContentState,
            localAlertsDisplayState: localAlertsDisplayState,
            readinessState: readinessState,
            resolutionState: refreshPipeline.resolutionState,
            isRefreshInFlight: refreshPipeline.isRefreshInFlight,
            isStormSetupRefreshInFlight: refreshPipeline.isStormSetupRefreshInFlight,
            showsOfflineToken: runtimeConnectivityState.isOffline,
            locationReliabilityRailState: showsLocationReliabilityRail
                ? SummaryView.LocationReliabilityRailState(
                    onOpen: openLocationReliabilityRail,
                    onDismiss: dismissLocationReliabilityRailForToday
                )
                : nil,
            onOpenMapLayer: openMap,
            onOpenAlerts: openAlertsTab,
            onOpenOutlooks: openOutlooksTab,
            refreshAction: {
                await refreshPipeline.forceRefreshCurrentContext(
                    showsLoading: true,
                    environment: refreshEnvironment
                )
            },
            refreshStormSetupAction: {
                await refreshPipeline.refreshStormSetupManually(environment: refreshEnvironment)
            }
        )
        .modifier(SummaryIntensityModifier(
            request: SummaryIntensityRequest(
                projection: presentation.projection,
                location: presentation.locationSnapshot,
                threat: presentation.severeRisk,
                contentState: todayContentState
            ),
            refreshRevision: presentation.projection?.updatedAt,
            isRefreshing: refreshPipeline.isRefreshInFlight
        ))
    }

    private func alertsTab(presentation: HomePresentationSnapshot) -> some View {
        NavigationStack {
            AlertView(
                mesos: presentation.mesos,
                alerts: presentation.alerts,
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

    private var mapTab: some View {
        MapScreenView(selectedLayer: $selectedMapLayer)
            .toolbar(.hidden, for: .navigationBar)
    }

    private var outlooksTab: some View {
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

    var body: some View {
        homeProjectionObservation
    }

    @ViewBuilder
    private func homeBody(
        presentation: HomePresentationSnapshot,
        readinessState: SummaryReadinessState,
        todayContentState: TodayContentState,
        localAlertsDisplayState: LocalAlertsDisplayState,
        stormSetupProfileAnalysisResponse: AnvilAnalyzeProfileResponse?
    ) -> some View {
        ZStack {
            Color(.skyAwareBackground).ignoresSafeArea()

            TabView(selection: $selectedTab) {
                Tab("Today", systemImage: "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted", value: .today) {
                    todayTab(
                        presentation: presentation,
                        readinessState: readinessState,
                        todayContentState: todayContentState,
                        localAlertsDisplayState: localAlertsDisplayState,
                        stormSetupProfileAnalysisResponse: stormSetupProfileAnalysisResponse
                    )
                }

                Tab("Alerts", systemImage: "exclamationmark.triangle", value: .alerts) {
                    alertsTab(presentation: presentation)
                }
                .badge(presentation.mesos.count + presentation.alerts.count)

                Tab("Map", systemImage: "map", value: .map) {
                    mapTab
                }

                Tab("Outlooks", systemImage: "list.clipboard.fill", value: .outlooks) {
                    outlooksTab
                }

                Tab("Settings", systemImage: "gearshape", value: .settings) {
                    settingsTab
                }
            }
            .background(Color(.skyAwareBackground).ignoresSafeArea())
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.skyAwareBackground, for: .tabBar)
            .ignoresSafeArea(edges: .bottom)
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
        .onChange(of: currentContextRefreshKey, initial: true) { _, newKey in
            projectionRetentionTask?.cancel()
            projectionRetentionTask = nil
            if isUITestStaticMode == false,
               let currentContext = locationSession.currentContext,
               currentContext.refreshKey == newKey {
                projectionRetentionTask = Task(priority: .utility) {
                    do {
                        try await Self.retainProjectionIfContextResolved(
                            currentContext,
                            for: newKey,
                            using: dependencies.homeProjectionStore
                        )
                    } catch is CancellationError {
                        return
                    } catch {
                        logger.error(
                            "Home projection retention cleanup failed: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }
            }
            guard isUITestStaticMode == false else { return }
            Task {
                await refreshPipeline.handleContextRefreshKeyChange(
                    newKey,
                    scenePhase: scenePhase,
                    environment: refreshEnvironment
                )
            }
        }
        .onDisappear {
            projectionRetentionTask?.cancel()
        }
        .onChange(of: stormSetupEnabled) { oldValue, newValue in
            scheduleStormSetupSettingsRefreshIfNeeded(
                previousPreferences: .init(
                    stormSetupEnabled: oldValue,
                    detailedIngredientsEnabled: detailedIngredientsEnabled
                ),
                currentPreferences: .init(
                    stormSetupEnabled: newValue,
                    detailedIngredientsEnabled: detailedIngredientsEnabled
                )
            )
        }
        .onChange(of: detailedIngredientsEnabled) { oldValue, newValue in
            scheduleStormSetupSettingsRefreshIfNeeded(
                previousPreferences: .init(
                    stormSetupEnabled: stormSetupEnabled,
                    detailedIngredientsEnabled: oldValue
                ),
                currentPreferences: .init(
                    stormSetupEnabled: stormSetupEnabled,
                    detailedIngredientsEnabled: newValue
                )
            )
        }
        .onChange(of: remoteAlertPresentationState.focusRequest?.id) { _, newValue in
            guard newValue != nil else { return }
            selectedTab = .alerts
        }
        .onChange(of: locationSession.reliabilityState) { _, _ in
            refreshLocationReliabilityRail(presentation: presentation)
        }
        .onChange(of: presentation.stormRisk) { _, _ in
            refreshLocationReliabilityRail(presentation: presentation)
        }
        .onChange(of: presentation.severeRisk) { _, _ in
            refreshLocationReliabilityRail(presentation: presentation)
        }
        .task {
            refreshLocationReliabilityRail(presentation: presentation)
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

    private func scheduleStormSetupSettingsRefreshIfNeeded(
        previousPreferences: StormSetupPreferences,
        currentPreferences: StormSetupPreferences
    ) {
        guard Self.shouldScheduleStormSetupSettingsRefresh(
            previousPreferences: previousPreferences,
            currentPreferences: currentPreferences,
            hasCurrentLocationContext: locationSession.currentContext != nil,
            isPreviewMode: isPreviewMode,
            isUITestStaticMode: isUITestStaticMode
        ) else {
            return
        }

        refreshPipeline.updateEnvironment(refreshEnvironment)
        Task {
            await refreshPipeline.enqueueRefresh(.timer, environment: refreshEnvironment)
        }
    }
}

struct HomeProjectionObservation: View {
    struct Snapshot: Equatable {
        let current: HomeProjectionRecord?
        let latestObserved: HomeProjectionRecord?
    }

    @Query private var projections: [HomeProjection]
    @State private var acceptedRevision: HomeVisibleRevision?

    private let projectionKey: String?
    private let content: (HomeVisibleRevision?, HomeProjectionRecord?) -> AnyView

    init<Content: View>(
        projectionKey: String?,
        @ViewBuilder content: @escaping (HomeVisibleRevision?, HomeProjectionRecord?) -> Content
    ) {
        self.projectionKey = projectionKey
        self.content = { revision, startup in
            AnyView(content(revision, startup))
        }
        _projections = Query(HomeProjection.orderedProjectionsDescriptor())
    }

    private var snapshot: Snapshot {
        Snapshot(
            current: projectionKey == nil
                ? nil
                : Self.newestDisplayReadyProjection(in: currentProjectionCandidates),
            latestObserved: Self.newestDisplayReadyProjection(in: projections)
        )
    }

    private var currentProjectionCandidates: [HomeProjection] {
        guard let projectionKey else { return [] }
        return projections.filter { $0.projectionKey == projectionKey }
    }

    static func newestDisplayReadyProjection(in projections: [HomeProjection]) -> HomeProjectionRecord? {
        HomeProjectionRecord.newestDisplayReady(in: projections.map(\.record))
    }

    private var visibleRevision: HomeVisibleRevision? {
        HomeVisibleRevision.derive(
            previous: acceptedRevision,
            observed: projectionKey == nil ? snapshot.latestObserved : snapshot.current,
            projectionKey: projectionKey ?? snapshot.latestObserved?.projectionKey
        )
    }

    var body: some View {
        content(visibleRevision, snapshot.latestObserved)
            .onChange(of: snapshot, initial: true) { _, _ in
                acceptedRevision = visibleRevision
            }
            .onChange(of: projectionKey) { _, _ in
                acceptedRevision = visibleRevision
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

    static func retainProjectionIfContextResolved(
        _ context: LocationContext?,
        for refreshKey: LocationContext.RefreshKey?,
        using store: HomeProjectionStore,
        now: Date = .now
    ) async throws {
        guard let context, context.refreshKey == refreshKey else { return }
        try await store.retainRecentProjections(forActiveContext: context, now: now)
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

    private func refreshLocationReliabilityRail(presentation: HomePresentationSnapshot) {
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
            stormRisk: presentation.stormRisk,
            severeRisk: presentation.severeRisk,
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
                "Showing location reliability rail qualifyingDay=\(qualifyingDay, privacy: .public) authorization=\(reliability.authorization.logName, privacy: .public) accuracy=\(reliability.accuracy.logName, privacy: .public) stormRisk=\(String(describing: presentation.stormRisk), privacy: .public) severeRisk=\(String(describing: presentation.severeRisk), privacy: .public) askCount=\(snapshot.askCount, privacy: .public)"
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
