//
//  HomeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import CoreLocation
import OSLog

struct RefreshContext {
    let coordinates: CLLocationCoordinate2D
    let refreshedAt: Date
}

struct HomeView: View {
    struct LoadingOverlayState {
        private(set) var activeRefreshes: Int = 0
        private(set) var message: String?

        var isVisible: Bool { activeRefreshes > 0 }
        var displayMessage: String { message ?? "Refreshing data..." }

        mutating func begin(message: String) {
            self.message = message
            activeRefreshes += 1
        }

        mutating func setMessage(_ message: String) {
            self.message = message
        }

        mutating func end() {
            activeRefreshes = max(0, activeRefreshes - 1)
            if activeRefreshes == 0 {
                message = nil
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies
    @Environment(LocationSession.self) private var locationSession
    
    private let logger = Logger.uiHome
    
    // MARK: Local handles
    private var sync: any SpcSyncing { dependencies.spcSync }
    private var svc: any SpcRiskQuerying { dependencies.spcRisk }
    private var outlookSvc: any SpcOutlookQuerying { dependencies.spcOutlook }
    private var arcusAlertSvc: any ArcusAlertQuerying { dependencies.arcusProvider }
    private var arcusAlertSync: any ArcusAlertSyncing { dependencies.arcusProvider }
    private var weatherClient: WeatherClient { dependencies.weatherClient }

    // MARK: State
    // Header State
    @State private var snap: LocationSnapshot?
    @State private var summaryWeather: SummaryWeather?
    
    // Badge State
    @State private var stormRisk: StormRiskLevel?
    @State private var severeRisk: SevereWeatherThreat?
    @State private var fireRisk: FireRiskLevel?
    
    // Alert State
    @State private var mesos: [MdDTO] = []
    @State private var watches: [WatchRowDTO] = []
    
    // Refresh State
    @State private var lastRefreshContext: RefreshContext?
    @State private var lastOutlookSyncAt: Date?
    @State private var lastWeatherKitSyncAt: Date?
    @State private var loadingState = LoadingOverlayState()
    private let minimumForegroundRefreshInterval: TimeInterval = 3 * 60
    private let minimumRefreshDistanceMeters: CLLocationDistance = 800
    private let outlookRefreshPolicy = OutlookRefreshPolicy()
    private let weatherKitRefreshPolicy = WeatherKitRefreshPolicy()

    static func shouldRunContextDrivenRefresh(
        scenePhase: ScenePhase,
        refreshKey: LocationContext.RefreshKey?
    ) -> Bool {
        scenePhase == .active && refreshKey != nil
    }

    static func shouldPerformLocationRefresh(
        lastRefreshContext: RefreshContext?,
        snapshot: LocationSnapshot,
        force: Bool,
        minimumForegroundRefreshInterval: TimeInterval = 3 * 60,
        minimumRefreshDistanceMeters: CLLocationDistance = 800
    ) -> Bool {
        if force {
            return true
        }

        guard let lastRefreshContext else {
            return true
        }

        let currentLocation = CLLocation(
            latitude: snapshot.coordinates.latitude,
            longitude: snapshot.coordinates.longitude
        )
        let previousLocation = CLLocation(
            latitude: lastRefreshContext.coordinates.latitude,
            longitude: lastRefreshContext.coordinates.longitude
        )
        let elapsed = snapshot.timestamp.timeIntervalSince(lastRefreshContext.refreshedAt)
        let distance = currentLocation.distance(from: previousLocation)
        return elapsed >= minimumForegroundRefreshInterval || distance >= minimumRefreshDistanceMeters
    }

    static func readinessState(
        startupState: LocationStartupState,
        hasContext: Bool,
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        fireRisk: FireRiskLevel?
    ) -> SummaryReadinessState {
        switch startupState {
        case .idle, .requestingAuthorization, .acquiringLocation:
            return SummaryReadinessState.loadingLocation
        case .resolvingContext:
            return SummaryReadinessState.resolvingLocalContext
        case .failed:
            return SummaryReadinessState.locationUnavailable
        case .ready:
            if hasContext == false {
                return SummaryReadinessState.loadingLocation
            }
            if stormRisk == nil || severeRisk == nil || fireRisk == nil {
                return SummaryReadinessState.loadingLocalData
            }
            return SummaryReadinessState.ready
        }
    }

    private var currentContextRefreshKey: LocationContext.RefreshKey? {
        locationSession.currentContext?.refreshKey
    }

    private var readinessState: SummaryReadinessState {
        Self.readinessState(
            startupState: locationSession.startupState,
            hasContext: locationSession.currentContext != nil,
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            fireRisk: fireRisk
        )
    }
    
    // Outlook State
    @State private var outlooks: [ConvectiveOutlookDTO] = []
    @State private var outlook: ConvectiveOutlookDTO?

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
        _snap = State(initialValue: initialSnap)
        _stormRisk = State(initialValue: initialStormRisk)
        _severeRisk = State(initialValue: initialSevereRisk)
        _fireRisk = State(initialValue: initialFireRisk)
        _mesos = State(initialValue: initialMesos)
        _watches = State(initialValue: initialWatches)
        _outlook = State(initialValue: initialOutlook)
        _outlooks = State(initialValue: initialOutlooks)
    }

    var body: some View {
        ZStack {
            Color(.skyAwareBackground).ignoresSafeArea()
            TabView {
                Tab("Today", systemImage: "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted") {
                    NavigationStack {
                        ScrollView {
                            SummaryView(
                                snap: snap,
                                stormRisk: stormRisk,
                                severeRisk: severeRisk,
                                fireRisk: fireRisk,
                                mesos: mesos,
                                watches: watches,
                                outlook: outlook,
                                weather: summaryWeather,
                                readinessState: readinessState
                            )
                            .toolbar(.hidden, for: .navigationBar)
                            .background(.skyAwareBackground)
                        }
                        .background(Color(.skyAwareBackground).ignoresSafeArea())
                        .refreshable {
                            await forceRefreshCurrentContext(showsLoading: true)
                        }
                    }
                    .background(Color(.skyAwareBackground).ignoresSafeArea())
                }

                Tab("Alerts", systemImage: "exclamationmark.triangle") {
                    NavigationStack {
                        AlertView(
                            mesos: mesos,
                            watches: watches,
                            onRefresh: {
                                logger.debug("refreshing alerts")
                                lastRefreshContext = nil
                                await forceRefreshCurrentContext(showsLoading: true)
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
                .badge(mesos.count + watches.count)

                Tab("Map", systemImage: "map") {
                    MapScreenView()
                        .toolbar(.hidden, for: .navigationBar)
                }

                Tab("Outlooks", systemImage: "list.clipboard.fill") {
                    NavigationStack {
                        ConvectiveOutlookView(
                            dtos: outlooks,
                            onRefresh: {
                                logger.debug("refreshing outlooks")
                                await withLoading(message: "Syncing outlooks...") {
                                    let now = Date()
                                    await MainActor.run {
                                        _ = markOutlookSyncIfNeeded(force: true, now: now)
                                    }
                                    await HTTPExecutionMode.$current.withValue(.foreground) {
                                        await sync.syncConvectiveOutlooks()
                                    }
                                    await refreshOutlooks()
                                }
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
            .toolbarBackground(.skyAwareBackground, for: .tabBar)
            .ignoresSafeArea(edges: .bottom)
            if loadingState.isVisible {
                LoadingView(message: loadingState.displayMessage)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(1)
            }
        }
        .transition(.opacity)
        .tint(.skyAwareAccent)
        .task(id: scenePhase) {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
            let isActive = scenePhase == .active
            guard isActive else { return }

            await bootstrapForegroundRefresh(showsLoading: true)
        }
        .task(id: currentContextRefreshKey) {
            guard Self.shouldRunContextDrivenRefresh(
                scenePhase: scenePhase,
                refreshKey: currentContextRefreshKey
            ) else { return }
            let latestContext = locationSession.currentContext
            await MainActor.run {
                snap = latestContext?.snapshot
            }
            guard let latestContext else { return }
            await refresh(for: latestContext, showsLoading: true)
        }
    }

    private func bootstrapForegroundRefresh(showsLoading: Bool) async {
        await refreshForegroundData(
            force: true,
            requiresFreshLocation: true,
            showsAuthorizationPrompt: true,
            showsLoading: showsLoading
        )
    }
    
    private func refreshForegroundData(
        force: Bool,
        requiresFreshLocation: Bool,
        showsAuthorizationPrompt: Bool,
        showsLoading: Bool
    ) async {
        let now = Date()
        let shouldSyncOutlookNow = await MainActor.run {
            markOutlookSyncIfNeeded(force: force, now: now)
        }
        let shouldSyncWeatherKitNow = await MainActor.run {
            shouldSyncWeatherKit(force: force, now: now)
        }

        if showsLoading {
            await MainActor.run { startRefresh(message: "Preparing location context...") }
        }

        if !shouldSyncOutlookNow {
            logger.debug("Skipping convective outlook sync due to refresh throttle")
        }

        let contextTask = Task {
            await locationSession.prepareCurrentLocationContext(
                requiresFreshLocation: requiresFreshLocation,
                showsAuthorizationPrompt: showsAuthorizationPrompt
            )
        }
        let globalSyncTask = Task {
            await syncGlobalFeeds(shouldSyncOutlookNow: shouldSyncOutlookNow)
        }
        let context = await contextTask.value

        if Task.isCancelled {
            if showsLoading { await MainActor.run { endRefresh() } }
            return
        }

        if showsLoading { await MainActor.run { updateRefreshMessage("Syncing global SPC feeds...") } }
        await globalSyncTask.value
        await refreshOutlooks()

        if Task.isCancelled {
            if showsLoading { await MainActor.run { endRefresh() } }
            return
        }

        guard let context else {
            logger.notice("Foreground activation could not prepare a current location context")
            if showsLoading { await MainActor.run { endRefresh() } }
            return
        }

        await MainActor.run { snap = context.snapshot }
        await refresh(
            for: context,
            force: force,
            showsLoading: false,
            now: now,
            shouldSyncWeatherKitNow: shouldSyncWeatherKitNow
        )

        if showsLoading {
            await MainActor.run { endRefresh() }
        }
    }

    /// Refreshes location-scoped data once a deterministic context is ready.
    private func refresh(
        for context: LocationContext,
        force: Bool = false,
        showsLoading: Bool = true,
        now: Date = Date(),
        shouldSyncWeatherKitNow: Bool? = nil
    ) async {
        guard shouldRefresh(for: context.snapshot, force: force) else {
            logger.debug("Refresh denied, no change detected")
            return
        }

        logger.info("Refreshing location-scoped summary data")
        let shouldRefreshWeather: Bool
        if let shouldSyncWeatherKitNow {
            shouldRefreshWeather = shouldSyncWeatherKitNow
        } else {
            shouldRefreshWeather = await MainActor.run {
                shouldSyncWeatherKit(force: force, now: now)
            }
        }

        if showsLoading {
            await MainActor.run { startRefresh(message: "Refreshing local weather data...") }
        }

        if showsLoading { await MainActor.run { updateRefreshMessage("Syncing local alerts...") } }
        await HTTPExecutionMode.$current.withValue(.foreground) {
            await arcusAlertSync.sync(context: context)
        }

        if Task.isCancelled {
            if showsLoading { await MainActor.run { endRefresh() } }
            return
        }

        if showsLoading { await MainActor.run { updateRefreshMessage("Updating local risks...") } }
        await refreshRisk(for: context)

        if Task.isCancelled {
            if showsLoading { await MainActor.run { endRefresh() } }
            return
        }

        if shouldRefreshWeather {
            if showsLoading { await MainActor.run { updateRefreshMessage("Updating current weather...") } }
            let didRefreshWeather = await refreshWeather(for: context.snapshot.coordinates)
            if didRefreshWeather {
                await MainActor.run { lastWeatherKitSyncAt = now }
            } else {
                logger.debug("WeatherKit refresh returned no data; leaving throttle timestamp unchanged")
            }
        } else {
            logger.debug("Skipping WeatherKit refresh due to refresh throttle")
        }
        
        if showsLoading {
            await MainActor.run { endRefresh() }
        }
    }

    private func forceRefreshCurrentContext(showsLoading: Bool) async {
        await MainActor.run {
            lastRefreshContext = nil
        }
        await refreshForegroundData(
            force: true,
            requiresFreshLocation: true,
            showsAuthorizationPrompt: false,
            showsLoading: showsLoading
        )
    }
    
    @MainActor
    private func refreshWeather(for snap: CLLocationCoordinate2D) async -> Bool {
        if Task.isCancelled { return false }
        let weather = await weatherClient.currentWeather(for: CLLocation(latitude: snap.latitude, longitude: snap.longitude))
        if Task.isCancelled { return false }
        guard let weather else { return false }
        self.summaryWeather = weather
        return true
    }
    
    private func refreshOutlooks() async {
        do {
            let dtos = try await outlookSvc.getConvectiveOutlooks()
            let latest = dtos.max(by: { $0.published < $1.published })
            if Task.isCancelled { return }
            await MainActor.run {
                self.outlooks = dtos
                self.outlook = latest
            }
        } catch {
            // Swallow for now; consider logging
        }
    }
    
    @MainActor
    private func shouldRefresh(for snap: LocationSnapshot, force: Bool = false) -> Bool {
        guard Self.shouldPerformLocationRefresh(
            lastRefreshContext: lastRefreshContext,
            snapshot: snap,
            force: force,
            minimumForegroundRefreshInterval: minimumForegroundRefreshInterval,
            minimumRefreshDistanceMeters: minimumRefreshDistanceMeters
        ) else {
            return false
        }

        self.lastRefreshContext = RefreshContext(
            coordinates: snap.coordinates,
            refreshedAt: snap.timestamp
        )
        return true
    }

    @MainActor
    private func markOutlookSyncIfNeeded(force: Bool, now: Date) -> Bool {
        let shouldSync = outlookRefreshPolicy.shouldSync(
            now: now,
            lastSync: lastOutlookSyncAt,
            force: force
        )
        if shouldSync {
            lastOutlookSyncAt = now
        }
        return shouldSync
    }

    @MainActor
    private func shouldSyncWeatherKit(force: Bool, now: Date) -> Bool {
        weatherKitRefreshPolicy.shouldSync(
            now: now,
            lastSync: lastWeatherKitSyncAt,
            force: force
        )
    }
    
    private func syncGlobalFeeds(shouldSyncOutlookNow: Bool) async {
        await HTTPExecutionMode.$current.withValue(.foreground) {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await sync.syncMesoscaleDiscussions() }
                group.addTask { await sync.syncMapProducts() }
                if shouldSyncOutlookNow {
                    group.addTask { await sync.syncConvectiveOutlooks() }
                }
                await group.waitForAll()
            }
        }
    }

    private func refreshRisk(for context: LocationContext) async {
        let coord = context.snapshot.coordinates
        async let stormResult = capture { try await svc.getStormRisk(for: coord) }
        async let severeResult = capture { try await svc.getSevereRisk(for: coord) }
        async let fireResult = capture { try await svc.getFireRisk(for: coord) }
        async let mesosResult = capture { try await svc.getActiveMesos(at: .now, for: coord) }
        async let arcusWatch  = capture { try await arcusAlertSvc.getActiveWatches(context: context) }
        
        let (storm, severe, fire, mesos, arcus) = await (stormResult, severeResult, fireResult, mesosResult, arcusWatch)
        if Task.isCancelled { return }
        
        await MainActor.run {
            if case let .success(value) = storm { self.stormRisk = value }
            if case let .success(value) = severe { self.severeRisk = value }
            if case let .success(value) = fire { self.fireRisk = value  }
            if case let .success(value) = mesos { self.mesos = value }
            if case let .success(value) = arcus { self.watches = value }
        }
    }
    
    private func capture<T>(_ operation: @Sendable () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private func withLoading(message: String, operation: @escaping () async -> Void) async {
        await MainActor.run { startRefresh(message: message) }
        await operation()
        await MainActor.run { endRefresh() }
    }

    @MainActor
    private func startRefresh(message: String) {
        loadingState.begin(message: message)
    }

    @MainActor
    private func updateRefreshMessage(_ message: String) {
        loadingState.setMessage(message)
    }

    @MainActor
    private func endRefresh() {
        loadingState.end()
    }
}

// MARK: Preview
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
