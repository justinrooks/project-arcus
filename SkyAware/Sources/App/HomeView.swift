//
//  HomeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import OSLog

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies
    @Environment(LocationSession.self) private var locationSession

    private let logger = Logger.uiHome

    @State private var refreshPipeline: HomeRefreshPipeline

    private var currentContextRefreshKey: LocationContext.RefreshKey? {
        locationSession.currentContext?.refreshKey
    }

    private var readinessState: SummaryReadinessState {
        Self.readinessState(
            startupState: locationSession.startupState,
            hasContext: locationSession.currentContext != nil,
            stormRisk: refreshPipeline.stormRisk,
            severeRisk: refreshPipeline.severeRisk,
            fireRisk: refreshPipeline.fireRisk
        )
    }

    private var hasMeaningfulSummaryContent: Bool {
        refreshPipeline.snap != nil ||
        refreshPipeline.summaryWeather != nil ||
        refreshPipeline.stormRisk != nil ||
        refreshPipeline.severeRisk != nil ||
        refreshPipeline.fireRisk != nil ||
        refreshPipeline.outlook != nil ||
        refreshPipeline.mesos.isEmpty == false ||
        refreshPipeline.watches.isEmpty == false
    }

    private var isEmptyResolvingSummary: Bool {
        readinessState != .locationUnavailable &&
        hasMeaningfulSummaryContent == false &&
        (refreshPipeline.resolutionState.isRefreshing || readinessState != .ready)
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
            spcRisk: dependencies.spcRisk,
            outlooks: dependencies.spcOutlook,
            arcusAlerts: dependencies.arcusProvider,
            arcusAlertSync: dependencies.arcusProvider,
            weatherClient: dependencies.weatherClient,
            locationSession: locationSession
        )
    }

    var body: some View {
        ZStack {
            Color(.skyAwareBackground).ignoresSafeArea()

            TabView {
                Tab("Today", systemImage: "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted") {
                    NavigationStack {
                        ScrollView {
                            SummaryView(
                                snap: refreshPipeline.snap,
                                stormRisk: refreshPipeline.stormRisk,
                                severeRisk: refreshPipeline.severeRisk,
                                fireRisk: refreshPipeline.fireRisk,
                                mesos: refreshPipeline.mesos,
                                watches: refreshPipeline.watches,
                                outlook: refreshPipeline.outlook,
                                weather: refreshPipeline.summaryWeather,
                                readinessState: readinessState,
                                resolutionState: refreshPipeline.resolutionState
                            )
                            .toolbar(.hidden, for: .navigationBar)
                            .background(.skyAwareBackground)
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

                Tab("Alerts", systemImage: "exclamationmark.triangle") {
                    NavigationStack {
                        AlertView(
                            mesos: refreshPipeline.mesos,
                            watches: refreshPipeline.watches,
                            onRefresh: {
                                logger.debug("refreshing alerts")
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
                .badge(refreshPipeline.mesos.count + refreshPipeline.watches.count)

                Tab("Map", systemImage: "map") {
                    MapScreenView()
                        .toolbar(.hidden, for: .navigationBar)
                }

                Tab("Outlooks", systemImage: "list.clipboard.fill") {
                    NavigationStack {
                        ConvectiveOutlookView(
                            dtos: refreshPipeline.outlooks,
                            onRefresh: {
                                logger.debug("refreshing outlooks")
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

                Tab("Settings", systemImage: "gearshape") {
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
            .animation(.easeInOut(duration: 0.35), value: isEmptyResolvingSummary)
            .ignoresSafeArea(edges: .bottom)

            if isEmptyResolvingSummary {
                Rectangle()
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
            guard scenePhase == .active, newKey != nil else { return }
            Task {
                await refreshPipeline.enqueueRefresh(.contextChanged, environment: refreshEnvironment)
            }
        }
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
}
