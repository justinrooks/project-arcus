//
//  HomeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import CoreLocation
import OSLog

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
    
    private let logger = Logger.uiHome
    
    // MARK: Local handles
    private var sync: any SpcSyncing { dependencies.spcSync }
    private var locSvc: LocationClient { dependencies.locationClient }
    private var svc: any SpcRiskQuerying { dependencies.spcRisk }
    private var outlookSvc: any SpcOutlookQuerying { dependencies.spcOutlook }
    private var nwsSvc: any NwsRiskQuerying { dependencies.nwsRisk  }
    private var nwsSync: any NwsSyncing { dependencies.nwsSync }

    // MARK: State
    // Header State
    @State private var snap: LocationSnapshot?
    
    // Badge State
    @State private var stormRisk: StormRiskLevel?
    @State private var severeRisk: SevereWeatherThreat?
    
    // Alert State
    @State private var mesos: [MdDTO] = []
    @State private var watches: [WatchRowDTO] = []
    
    // Refresh State
    @State private var lastRefreshKey: RefreshKey?
    @State private var lastOutlookSyncAt: Date?
    @State private var loadingState = LoadingOverlayState()
    private let outlookRefreshPolicy = OutlookRefreshPolicy()
    
    // Outlook State
    @State private var outlooks: [ConvectiveOutlookDTO] = []
    @State private var outlook: ConvectiveOutlookDTO?

    init(
        initialSnap: LocationSnapshot? = nil,
        initialStormRisk: StormRiskLevel? = nil,
        initialSevereRisk: SevereWeatherThreat? = nil,
        initialMesos: [MdDTO] = [],
        initialWatches: [WatchRowDTO] = [],
        initialOutlooks: [ConvectiveOutlookDTO] = [],
        initialOutlook: ConvectiveOutlookDTO? = nil
    ) {
        _snap = State(initialValue: initialSnap)
        _stormRisk = State(initialValue: initialStormRisk)
        _severeRisk = State(initialValue: initialSevereRisk)
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
                            mesos: mesos,
                            watches: watches,
                            outlook: outlook
                        )
                        .toolbar(.hidden, for: .navigationBar)
                        .background(.skyAwareBackground)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.skyAwareBackground.ignoresSafeArea())
                    .refreshable {
                        lastRefreshKey = nil
                        await refresh(for: snap, force: true, showsLoading: true)
                    }
                }
                .tabItem { Label("Today", systemImage: "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted")
//                    "clock.arrow.trianglehead.2.counterclockwise.rotate.90") //gauge.with.needle.fill
                }
                
                NavigationStack {
                    AlertView(mesos: mesos, watches: watches)
                        .navigationTitle("Active Alerts")
                        .navigationBarTitleDisplayMode(.inline)
            //            .toolbarBackground(.visible, for: .navigationBar)      // <- non-translucent
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                        .scrollContentBackground(.hidden)
                        .background(.skyAwareBackground)
                        .refreshable {
                            logger.debug("refreshing alerts")
                            lastRefreshKey = nil
                            await withLoading(message: "Refreshing alerts...") {
                                await refresh(for: snap, force: true, showsLoading: false)
                            }
                        }
                }
                .tabItem { Label("Alerts", systemImage: "exclamationmark.triangle") }//umbrella
                    .badge(mesos.count + watches.count)
                
                MapView()
                    .toolbar(.hidden, for: .navigationBar)
                    .background(.skyAwareBackground)
                    .tabItem { Label("Map", systemImage: "map") }
                
                NavigationStack {
                    ConvectiveOutlookView(dtos: outlooks)
                        .navigationTitle("Convective Outlooks")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                        .scrollContentBackground(.hidden)
                        .background(.skyAwareBackground)
                        .refreshable {
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
                }
                .tabItem { Label("Outlooks", systemImage: "list.clipboard.fill") }
                
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Background Health")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                        .scrollContentBackground(.hidden)
                        .background(.skyAwareBackground)
                }
                .tabItem {Label("Settings", systemImage: "gearshape")}
            
            }
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
        if showsLoading {
            await MainActor.run { endRefresh() }
        }
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
        let key = RefreshKey(coord: snap.coordinates, timestamp: snap.timestamp)
        if force {
            lastRefreshKey = key
            return true
        }
        guard key != lastRefreshKey else { return false } // skip placemark-only or repeated initial yield
        lastRefreshKey = key
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
        async let mesosResult = capture { try await svc.getActiveMesos(at: .now, for: coord) }
        async let watchResult = capture { try await nwsSvc.getActiveWatches(for: coord) }
        
        let (storm, severe, mesos, watch) = await (stormResult, severeResult, mesosResult, watchResult)
        if Task.isCancelled { return }
        
        await MainActor.run {
            if case let .success(value) = storm { self.stormRisk = value }
            if case let .success(value) = severe { self.severeRisk = value }
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
        initialMesos: MD.sampleDiscussionDTOs,
        initialWatches: Watch.sampleWatchRows,
        initialOutlooks: ConvectiveOutlook.sampleOutlookDtos,
        initialOutlook: ConvectiveOutlook.sampleOutlookDtos.first
    )
    .environment(\.dependencies, Dependencies.unconfigured)
}
