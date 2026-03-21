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

    static func preferredBootstrapSnapshot(
        providerSnapshot: LocationSnapshot?,
        renderedSnapshot: LocationSnapshot?
    ) -> LocationSnapshot? {
        providerSnapshot ?? renderedSnapshot
    }

    static func shouldRequestInteractiveLocationAuthorization(
        authStatus: CLAuthorizationStatus
    ) -> Bool {
        authStatus == .notDetermined
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies
    
    private let logger = Logger.uiHome
    
    // MARK: Local handles
    private var sync: any SpcSyncing { dependencies.spcSync }
    private var locSvc: LocationClient { dependencies.locationClient }
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
                            weather: summaryWeather
                        )
                        .toolbar(.hidden, for: .navigationBar)
                        .background(.skyAwareBackground)
                    }
                    .background(Color(.skyAwareBackground).ignoresSafeArea())
                    .refreshable {
                        await forceRefreshFromLatestSnapshot(showsLoading: true)
                    }
                }
                .background(Color(.skyAwareBackground).ignoresSafeArea())
                .tabItem { Label("Today", systemImage: "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted")
//                    "clock.arrow.trianglehead.2.counterclockwise.rotate.90") //gauge.with.needle.fill
                }
                
                NavigationStack {
                    AlertView(
                        mesos: mesos,
                        watches: watches,
                        onRefresh: {
                            logger.debug("refreshing alerts")
                            lastRefreshContext = nil
                            await withLoading(message: "Refreshing alerts...") {
                                await refresh(for: snap, force: true, showsLoading: false)
                            }
                        }
                    )
                        .background(.skyAwareBackground)
                        .navigationTitle("Active Alerts")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                }
                .background(Color(.skyAwareBackground).ignoresSafeArea())
                .tabItem { Label("Alerts", systemImage: "exclamationmark.triangle") }//umbrella
                    .badge(mesos.count + watches.count)
                
                MapScreenView()
                    .toolbar(.hidden, for: .navigationBar)
                    .tabItem { Label("Map", systemImage: "map") }
                
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
                .tabItem { Label("Outlooks", systemImage: "list.clipboard.fill") }
                
                NavigationStack {
                    SettingsView(locationClient: locSvc)
                        .background(.skyAwareBackground)
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                }
                .background(Color(.skyAwareBackground).ignoresSafeArea())
                .tabItem {Label("Settings", systemImage: "gearshape")}
            
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
            if isActive,
               Self.shouldRequestInteractiveLocationAuthorization(
                   authStatus: dependencies.locationManager.authStatus
               ) {
                dependencies.locationManager.checkLocationAuthorization(isActive: true)
            }
            dependencies.locationManager.updateMode(for: scenePhase)
            guard isActive else { return }

            await bootstrapForegroundRefreshIfPossible(showsLoading: true)
            
            // Whenever a location snapshot hits, refresh the data with
            // the newest location.
            let stream = await locSvc.updates()
            for await s in stream {
                if Task.isCancelled { break }
                await MainActor.run { snap = s }
                await refresh(for: s, showsLoading: true)
            }
        }
    }

    private func latestAvailableSnapshot() async -> LocationSnapshot? {
        let providerSnapshot = await locSvc.snapshot()
        let renderedSnapshot = await MainActor.run { snap }
        return Self.preferredBootstrapSnapshot(
            providerSnapshot: providerSnapshot,
            renderedSnapshot: renderedSnapshot
        )
    }

    private func bootstrapForegroundRefreshIfPossible(showsLoading: Bool) async {
        guard let latestSnapshot = await latestAvailableSnapshot() else {
            logger.notice("Foreground activation has no cached location snapshot yet; waiting for live location updates")
            return
        }

        logger.info("Bootstrapping foreground refresh from latest available snapshot")
        await MainActor.run { snap = latestSnapshot }
        await refresh(for: latestSnapshot, showsLoading: showsLoading)
    }
    
    /// Refreshes outlook plus location-scoped data together
    private func refresh(for snap: LocationSnapshot?, force: Bool = false, showsLoading: Bool = true) async {
        guard let snap else {
            logger.info("No location snapshot, skipping refresh")
            return
        }
        guard shouldRefresh(for: snap, force: force) else {
            logger.debug("Refresh denied, no change detected")
            return
        }

        logger.info("Refreshing summary data")
        let now = Date()
        let shouldSyncOutlookNow = await MainActor.run {
            markOutlookSyncIfNeeded(force: force, now: now)
        }
        let shouldSyncWeatherKitNow = await MainActor.run {
            shouldSyncWeatherKit(force: force, now: now)
        }

        if showsLoading {
            await MainActor.run { startRefresh(message: "Refreshing data...") }
        }

        let location = snap.coordinates
        let sync = self.sync

        if !shouldSyncOutlookNow {
            logger.debug("Skipping convective outlook sync due to refresh throttle")
        }

        if showsLoading { await MainActor.run { updateRefreshMessage("Syncing network feeds...") } }
        await HTTPExecutionMode.$current.withValue(.foreground) {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await sync.syncMesoscaleDiscussions() }
                group.addTask { await sync.syncMapProducts() }
                group.addTask { await arcusAlertSync.sync(h3Cell: snap.h3Cell)}
                if shouldSyncOutlookNow {
                    group.addTask { await sync.syncConvectiveOutlooks() }
                }
                await group.waitForAll()
            }
        }

        if Task.isCancelled {
            if showsLoading { await MainActor.run { endRefresh() } }
            return
        }

        if showsLoading { await MainActor.run { updateRefreshMessage("Updating local risks and outlooks...") } }
        async let riskRefresh: Void = refreshRisk(for: location, with: snap.h3Cell)
        async let outlookRefresh: Void = refreshOutlooks()
        _ = await (riskRefresh, outlookRefresh)

        if Task.isCancelled {
            if showsLoading { await MainActor.run { endRefresh() } }
            return
        }
        
        if shouldSyncWeatherKitNow {
            if showsLoading { await MainActor.run { updateRefreshMessage("Updating current weather...") } }
            let didRefreshWeather = await refreshWeather(for: location)
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

    private func forceRefreshFromLatestSnapshot(showsLoading: Bool) async {
        let latestSnapshot = await latestAvailableSnapshot()
        guard let latestSnapshot else {
            logger.info("Manual refresh skipped because no location snapshot is available yet")
            return
        }

        await MainActor.run {
            snap = latestSnapshot
            lastRefreshContext = nil
        }
        await refresh(for: latestSnapshot, force: true, showsLoading: showsLoading)
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
        let current = RefreshContext(coordinates: snap.coordinates, refreshedAt: snap.timestamp)

        if force {
            lastRefreshContext = current
            return true
        }

        guard let lastRefreshContext else {
            self.lastRefreshContext = current
            return true
        }

        let elapsed = current.refreshedAt.timeIntervalSince(lastRefreshContext.refreshedAt)
        let currentLocation = CLLocation(latitude: current.coordinates.latitude, longitude: current.coordinates.longitude)
        let previousLocation = CLLocation(latitude: lastRefreshContext.coordinates.latitude, longitude: lastRefreshContext.coordinates.longitude)
        let distance = currentLocation.distance(from: previousLocation)

        guard elapsed >= minimumForegroundRefreshInterval || distance >= minimumRefreshDistanceMeters else {
            return false
        }

        self.lastRefreshContext = current
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
    
    private func refreshRisk(for coord: CLLocationCoordinate2D, with cell: Int64?) async {
        async let stormResult = capture { try await svc.getStormRisk(for: coord) }
        async let severeResult = capture { try await svc.getSevereRisk(for: coord) }
        async let fireResult = capture { try await svc.getFireRisk(for: coord) }
        async let mesosResult = capture { try await svc.getActiveMesos(at: .now, for: coord) }
        async let arcusWatch  = capture { try await arcusAlertSvc.getActiveWatches(h3Cell: cell) }
        
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
}
