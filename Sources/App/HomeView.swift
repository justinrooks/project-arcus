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

    @State private var refreshPipeline: HomeRefreshPipeline
    @State private var selectedTab: HomeTab = .today
    @State private var selectedMapLayer: MapLayer = .categorical
    @State private var todayHeaderCondenseProgress: CGFloat = 0

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
        if isCurrentContextResolvedInPipeline {
            return refreshPipeline.mesos
        }
        return displayedProjection?.activeMesos ?? []
    }

    private var displayedWatches: [WatchRowDTO] {
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
                            SummaryView(
                                snap: displayedLocationSnapshot,
                                stormRisk: displayedStormRisk,
                                severeRisk: displayedSevereRisk,
                                fireRisk: displayedFireRisk,
                                mesos: displayedMesos,
                                watches: displayedWatches,
                                outlook: displayedOutlook,
                                weather: displayedWeather,
                                readinessState: readinessState,
                                resolutionState: refreshPipeline.resolutionState,
                                showsOfflineToken: runtimeConnectivityState.isOffline,
                                headerCondenseProgress: todayHeaderCondenseProgress,
                                onOpenMapLayer: openMap,
                                onOpenAlerts: { selectedTab = .alerts },
                                onOpenOutlooks: { selectedTab = .outlooks }
                            )
                            .toolbar(.hidden, for: .navigationBar)
                            .background(.skyAwareBackground)
                        }
                        .onScrollGeometryChange(for: CGFloat.self) { geometry in
                            geometry.contentOffset.y + geometry.contentInsets.top
                        } action: { _, newValue in
                            let normalizedProgress = min(max(newValue / 46, 0), 1)
                            todayHeaderCondenseProgress = normalizedProgress
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
            refreshPipeline.updateEnvironment(refreshEnvironment)
            await refreshPipeline.handleScenePhaseChange(scenePhase, environment: refreshEnvironment)
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task {
                await refreshPipeline.handleScenePhaseChange(newPhase, environment: refreshEnvironment)
            }
        }
        .onChange(of: currentContextRefreshKey) { _, newKey in
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
    }
}

extension HomeView {
    private func openMap(_ layer: MapLayer) {
        selectedMapLayer = layer
        selectedTab = .map
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
