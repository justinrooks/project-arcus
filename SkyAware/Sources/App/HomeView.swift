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
//    private struct RefreshContext {
//        let coordinates: CLLocationCoordinate2D
//        let refreshedAt: Date
//    }

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
    
    private let logger = Logger.uiHome
    
    // MARK: Local handles
    private var sync: any SpcSyncing { dependencies.spcSync }
    private var locSvc: LocationClient { dependencies.locationClient }
    private var svc: any SpcRiskQuerying { dependencies.spcRisk }
    private var outlookSvc: any SpcOutlookQuerying { dependencies.spcOutlook }
    private var nwsSvc: any NwsRiskQuerying { dependencies.nwsRisk  }
    private var nwsSync: any NwsSyncing { dependencies.nwsSync }
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
    @State private var loadingState = LoadingOverlayState()
    private let minimumForegroundRefreshInterval: TimeInterval = 3 * 60
    private let minimumRefreshDistanceMeters: CLLocationDistance = 800
    private let outlookRefreshPolicy = OutlookRefreshPolicy()
    
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
                            refresh: lastRefreshContext,
                            weather: summaryWeather
                        )
                        .toolbar(.hidden, for: .navigationBar)
                        .background(.skyAwareBackground)
                    }
                    .background(Color(.skyAwareBackground).ignoresSafeArea())
                    .refreshable {
                        lastRefreshContext = nil
                        await refresh(for: snap, force: true, showsLoading: true)
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
                                await sync.syncConvectiveOutlooks()
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
                    SettingsView()
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
            dependencies.locationManager.checkLocationAuthorization(isActive: true)
            dependencies.locationManager.updateMode(for: scenePhase)
            guard scenePhase == .active else { return }
            
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

        if showsLoading {
            await MainActor.run { startRefresh(message: "Refreshing data...") }
        }

        if showsLoading { await MainActor.run { updateRefreshMessage("Syncing alerts...") } }
        await nwsSync.sync(for: snap.coordinates)
        if showsLoading { await MainActor.run { updateRefreshMessage("Syncing mesos...") } }
        await sync.syncMesoscaleDiscussions()
        if showsLoading { await MainActor.run { updateRefreshMessage("Syncing map products...") } }
        await sync.syncMapProducts()
        if showsLoading { await MainActor.run { updateRefreshMessage("Updating local risks...") } }
        await refreshRisk(for: snap.coordinates)
        if shouldSyncOutlookNow {
            if showsLoading { await MainActor.run { updateRefreshMessage("Syncing outlooks...") } }
            await sync.syncConvectiveOutlooks()
        } else {
            logger.debug("Skipping convective outlook sync due to refresh throttle")
        }
        if showsLoading { await MainActor.run { updateRefreshMessage("Updating outlooks...") } }
        await refreshOutlooks()
        
        // WeatherKit Check
        if showsLoading { await MainActor.run { updateRefreshMessage("Updating current weather...") } }
        await refreshWeather(for: snap.coordinates)
        
        
        if showsLoading {
            await MainActor.run { endRefresh() }
        }
    }
    
    @MainActor
    private func refreshWeather(for snap: CLLocationCoordinate2D) async {
        if Task.isCancelled { return }
        let weather = await weatherClient.currentWeather(for: CLLocation(latitude: snap.latitude, longitude: snap.longitude))
        if Task.isCancelled { return }
        self.summaryWeather = weather
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
    
    private func refreshRisk(for coord: CLLocationCoordinate2D) async {
        async let stormResult = capture { try await svc.getStormRisk(for: coord) }
        async let severeResult = capture { try await svc.getSevereRisk(for: coord) }
        async let fireResult = capture { try await svc.getFireRisk(for: coord) }
        async let mesosResult = capture { try await svc.getActiveMesos(at: .now, for: coord) }
        async let watchResult = capture { try await nwsSvc.getActiveWatches(for: coord) }
        
        let (storm, severe, fire, mesos, watch) = await (stormResult, severeResult, fireResult, mesosResult, watchResult)
        if Task.isCancelled { return }
        
        await MainActor.run {
            if case let .success(value) = storm { self.stormRisk = value }
            if case let .success(value) = severe { self.severeRisk = value }
            if case let .success(value) = fire { self.fireRisk = value  }
            if case let .success(value) = mesos { self.mesos = value }
            if case let .success(value) = watch { self.watches = value }
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
