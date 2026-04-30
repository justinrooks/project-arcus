//
//  HomeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import OSLog
import SwiftData

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies
    @Environment(LocationSession.self) private var locationSession
    @Environment(RemoteAlertPresentationState.self) private var remoteAlertPresentationState
    @Environment(RuntimeConnectivityState.self) private var runtimeConnectivityState

    @Query(sort: [SortDescriptor(\HomeProjection.updatedAt, order: .reverse)])
    private var cachedProjections: [HomeProjection]

    @Query(sort: [SortDescriptor(\ConvectiveOutlook.published, order: .reverse)])
    private var cachedOutlooks: [ConvectiveOutlook]

    private let logger = Logger.appHomeRefresh
    private let locationReliabilityLogger = Logger.uiLocationReliability

    @State private var refreshPipeline: HomeRefreshPipeline
    @State private var selectedTab: HomeTab = .today
    @State private var selectedMapLayer: MapLayer = .categorical
    @State private var todayHeaderCondenseProgress: CGFloat = 0
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

    private var currentContextRefreshKey: LocationContext.RefreshKey? {
        locationSession.currentContext?.refreshKey
    }

    private var cachedOutlookDTOs: [ConvectiveOutlookDTO] {
        cachedOutlooks.map(\.dto)
    }

    private var displayedProjection: HomeProjectionRecord? {
        Self.selectProjection(
            from: cachedProjections.map(\.record),
            currentContext: locationSession.currentContext
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
        displayedProjection?.locationSnapshot ?? (usesPipelineSummaryFallback ? refreshPipeline.snap : nil)
    }

    private var displayedStormRisk: StormRiskLevel? {
        displayedProjection?.stormRisk ?? (usesPipelineSummaryFallback ? refreshPipeline.stormRisk : nil)
    }

    private var displayedSevereRisk: SevereWeatherThreat? {
        displayedProjection?.severeRisk ?? (usesPipelineSummaryFallback ? refreshPipeline.severeRisk : nil)
    }

    private var displayedFireRisk: FireRiskLevel? {
        displayedProjection?.fireRisk ?? (usesPipelineSummaryFallback ? refreshPipeline.fireRisk : nil)
    }

    private var displayedWeather: SummaryWeather? {
        displayedProjection?.weather ?? (usesPipelineSummaryFallback ? refreshPipeline.summaryWeather : nil)
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

    private var displayedWatches: [WatchRowDTO] {
        if isUITestStaticMode && refreshPipeline.watches.isEmpty == false {
            return refreshPipeline.watches
        }
        if isCurrentContextResolvedInPipeline {
            return refreshPipeline.watches
        }
        return displayedProjection?.activeAlerts ?? []
    }

    private var displayedOutlook: ConvectiveOutlookDTO? {
        displayedOutlooks.first ?? refreshPipeline.outlook
    }

    private var displayedOutlooks: [ConvectiveOutlookDTO] {
        if refreshPipeline.outlooks.isEmpty == false {
            return refreshPipeline.outlooks
        }
        return cachedOutlookDTOs
    }

    private var readinessState: SummaryReadinessState {
        Self.readinessState(
            startupState: locationSession.startupState,
            hasContext: locationSession.currentContext != nil,
            hasResolvedLocalData: currentContextRefreshKey == refreshPipeline.lastResolvedLocationScopedRefreshKey,
            stormRisk: displayedStormRisk,
            severeRisk: displayedSevereRisk,
            fireRisk: displayedFireRisk
        )
    }

    private var hasMeaningfulSummaryContent: Bool {
        displayedProjection != nil || usesPipelineSummaryFallback
    }

    private var isEmptyResolvingSummary: Bool {
        Self.showsBootstrapLoading(
            readinessState: readinessState,
            resolutionState: refreshPipeline.resolutionState,
            hasProjection: hasMeaningfulSummaryContent
        )
    }

    init(
        initialSnap: LocationSnapshot? = nil,
        initialStormRisk: StormRiskLevel? = nil,
        initialSevereRisk: SevereWeatherThreat? = nil,
        initialFireRisk: FireRiskLevel? = nil,
        initialMesos: [MdDTO] = [],
        initialWatches: [WatchRowDTO] = [],
        initialOutlooks: [ConvectiveOutlookDTO] = [],
        initialOutlook: ConvectiveOutlookDTO? = nil
    ) {
        _refreshPipeline = State(
            initialValue: HomeRefreshPipeline(
                initialSnap: initialSnap,
                initialStormRisk: initialStormRisk,
                initialSevereRisk: initialSevereRisk,
                initialFireRisk: initialFireRisk,
                initialMesos: initialMesos,
                initialWatches: initialWatches,
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
                    NavigationStack {
                        ScrollView {
                            summaryContentView
                            .toolbar(.hidden, for: .navigationBar)
                            .background(.skyAwareBackground)
                        }
                        .onScrollGeometryChange(for: CGFloat.self) { geometry in
                            geometry.contentOffset.y + geometry.contentInsets.top
                        } action: { _, newValue in
                            let normalizedProgress = min(max((newValue - 6) / 68, 0), 1)
                            if abs(todayHeaderCondenseProgress - normalizedProgress) > 0.001 {
                                todayHeaderCondenseProgress = normalizedProgress
                            }
                        }
                        .background(Color(.skyAwareBackground).ignoresSafeArea())
                        .refreshable {
                            await refreshPipeline.forceRefreshCurrentContext(
                                showsLoading: true,
                                environment: refreshEnvironment
                            )
                        }
                    }
                    .background(Color(.skyAwareBackground).ignoresSafeArea())
                }

                Tab("Alerts", systemImage: "exclamationmark.triangle", value: .alerts) {
                    NavigationStack {
                        AlertView(
                            mesos: displayedMesos,
                            watches: displayedWatches,
                            focusedWatchRequest: remoteAlertPresentationState.focusRequest,
                            onRefresh: {
                                logger.notice("Manual alerts refresh requested")
                                refreshPipeline.resetLocationRefreshContext()
                                await refreshPipeline.forceRefreshCurrentContext(
                                    showsLoading: true,
                                    environment: refreshEnvironment
                                )
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
                .badge(displayedMesos.count + displayedWatches.count)

                Tab("Map", systemImage: "map", value: .map) {
                    MapScreenView(selectedLayer: $selectedMapLayer)
                        .toolbar(.hidden, for: .navigationBar)
                }

                Tab("Outlooks", systemImage: "list.clipboard.fill", value: .outlooks) {
                    NavigationStack {
                        ConvectiveOutlookView(
                            dtos: displayedOutlooks,
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
        .transition(.opacity)
        .tint(.skyAwareAccent)
        .task {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
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
        .sheet(isPresented: $showsLocationReliabilitySheet) {
            LocationReliabilitySummaryExplanationSheet(
                reliability: locationSession.reliabilityState,
                onEnableAlways: enableAlwaysFromReliabilitySheet,
                onNotNow: dismissLocationReliabilitySheetForToday
            )
        }
        .task(id: locationSession.reliabilityState) {
            refreshLocationReliabilityRail()
        }
        .task(id: displayedStormRisk) {
            refreshLocationReliabilityRail()
        }
        .task(id: displayedSevereRisk) {
            refreshLocationReliabilityRail()
        }
    }
}

extension HomeView {
    @ViewBuilder
    private var summaryContentView: some View {
        let snap = displayedLocationSnapshot
        let stormRisk = displayedStormRisk
        let severeRisk = displayedSevereRisk
        let fireRisk = displayedFireRisk
        let mesos = displayedMesos
        let watches = displayedWatches
        let outlook = displayedOutlook
        let weather = displayedWeather
        let readiness = readinessState
        let resolution = refreshPipeline.resolutionState
        let isOffline = runtimeConnectivityState.isOffline
        let condenseProgress = todayHeaderCondenseProgress
        let railState = showsLocationReliabilityRail
            ? SummaryView.LocationReliabilityRailState(
                onOpen: openLocationReliabilityRail,
                onDismiss: dismissLocationReliabilityRailForToday
            )
            : nil

        SummaryView(
            snap: snap,
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            fireRisk: fireRisk,
            mesos: mesos,
            watches: watches,
            outlook: outlook,
            weather: weather,
            readinessState: readiness,
            resolutionState: resolution,
            showsOfflineToken: isOffline,
            headerCondenseProgress: condenseProgress,
            locationReliabilityRailState: railState,
            onOpenMapLayer: openMap,
            onOpenAlerts: openAlertsTab,
            onOpenOutlooks: openOutlooksTab
        )
    }

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

    static func showsBootstrapLoading(
        readinessState: SummaryReadinessState,
        resolutionState: SummaryResolutionState,
        hasProjection: Bool
    ) -> Bool {
        readinessState != .locationUnavailable &&
        hasProjection == false &&
        (resolutionState.isRefreshing || readinessState != .ready)
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
        initialWatches: Watch.sampleWatchRows,
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
