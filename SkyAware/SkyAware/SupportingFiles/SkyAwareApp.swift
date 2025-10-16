//
//  SkyAwareApp.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import SwiftData
import BackgroundTasks
import OSLog

// e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.skyaware.app.refresh"]

@main
struct SkyAwareApp: App {
    private let appRefreshID = "com.skyaware.app.refresh"
    private let mesoRefreshID = "com.skyaware.meso.refresh"
    private let logger = Logger.mainApp
    
    // Location
    @MainActor private let provider = LocationProvider()
    @MainActor private var locationMgr: LocationManager
    
    // Repos
    private let outlookRepo: ConvectiveOutlookRepo
    private let mesoRepo: MesoRepo
    private let watchRepo: WatchRepo
    private let stormRiskRepo: StormRiskRepo
    private let severeRiskRepo: SevereRiskRepo
    
    @State private var spcProvider: SpcProvider
    @State private var showLocationPermissionAlert = false

    // EnvVars
    @Environment(\.scenePhase) private var scenePhase
    
    // Shared SwiftData context
    var sharedModelContainer: ModelContainer = {
//        print(URL.applicationSupportDirectory.path(percentEncoded: false))
        let schema = Schema([ConvectiveOutlook.self, MD.self, WatchModel.self, StormRisk.self, SevereRisk.self])
        let config = ModelConfiguration("SkyAware_Data", schema: schema) //isStoredInMemoryOnly: false)
        do { return try ModelContainer(for: schema, configurations: config) }
        catch { fatalError("Could not create ModelContainer: \(error)") }
    }()
    
    init() {
        print(URL.applicationSupportDirectory.path(percentEncoded: false))

        // Setup Location Monitoring
        let sink: LocationSink = { [provider] update in await provider.send(update: update) }
        locationMgr = LocationManager(onUpdate: sink)
        
        // Configure the network cache
        let memoryCapacity = 4 * 1024 * 1024 // 4 MB
        let diskCapacity = 100 * 1024 * 1024 // 100 MB
        URLCache.shared = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "skyaware-dataCache"
        )
        
        // Create our data layer repos
        self.outlookRepo    = ConvectiveOutlookRepo(modelContainer: sharedModelContainer)
        self.mesoRepo       = MesoRepo(modelContainer: sharedModelContainer)
        self.watchRepo      = WatchRepo(modelContainer: sharedModelContainer)
        self.stormRiskRepo  = StormRiskRepo(modelContainer: sharedModelContainer)
        self.severeRiskRepo = SevereRiskRepo(modelContainer: sharedModelContainer)

        let spc1 = SpcProvider(outlookRepo: self.outlookRepo,
                                 mesoRepo: self.mesoRepo,
                                 watchRepo: self.watchRepo,
                                 stormRiskRepo: self.stormRiskRepo,
                                 severeRiskRepo: self.severeRiskRepo,
                                 client: SpcHttpClient())

        // Assign
        _spcProvider = .init(wrappedValue: spc1)
    }
    
    var body: some Scene {
        WindowGroup {
            iPhoneHomeView()
                .environment(\.spcService, spcProvider)
                .environment(\.locationClient, makeLocationClient(provider: provider))
                .alert("Location Permission Needed",
                       isPresented: $showLocationPermissionAlert) {
                    Button("Settings") { locationMgr.openSettings() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Enable location to see nearby weather risks and alerts.")
                }
                .task {
                    if isPreview { return }
                    locationMgr.checkLocationAuthorization(isActive: true)
                    locationMgr.updateMode(for: scenePhase)
                    
                    showLocationPermissionAlert = (locationMgr.authStatus == .denied || locationMgr.authStatus == .restricted)
                }
        }
        .modelContainer(sharedModelContainer)
        .backgroundTask(.appRefresh(appRefreshID)) {
            await scheduleNextAppRefresh() // Ensure we schedule again
            
            await withTaskCancellationHandler {
                do {
                    let mgr = NotificationManager()
                    await spcProvider.sync()
                    let outlook = try await spcProvider.getLatestConvectiveOutlook()
                    
                    guard let snap = await provider.snapshot() else {
                        let message = "New convective outlook available"
                        await mgr.notify(for: outlook, with: message)
                        
                        return
                    }
                    
                    async let updatedSnap = provider.ensurePlacemark(for: snap.coordinates)
                    async let severeRisk = spcProvider.getSevereRisk(for: snap.coordinates)
                    async let stormRisk = spcProvider.getStormRisk(for: snap.coordinates)
                    let message = "Latest severe weather outlook for \(await updatedSnap.placemarkSummary, default: "Unknown"):\nStorm Activity: \(try await stormRisk.summary)\nSevere Activity: \(try await severeRisk.summary)"
                    
                    await mgr.notify(for: outlook, with: message)
                } catch {
                    logger.error("Error refreshing background data: \(error.localizedDescription)")
                }
            } onCancel: {
                logger.warning("Background data fetch task cancelled")
            }
        }
//        .backgroundTask(.appRefresh(mesoRefreshID)) {
//            // Schedule
//            // query for mesos
//            // if mesos, send notification
//            //            await withTaskCancellationHandler {
//            //                _ = await prov.loadFeedAsync()
//            //
//            //                let ol = await prov.outlooks
//            //                let mostRecentArticle = ol.max { $0.published < $1.published }
//            //
//            //                let mesos = prov.meso
//            //
//            //                let mgr = NotificationManager()
//            //                await mgr.notify(for: mostRecentArticle, with: message)
//            //            } onCancel: {
//            //                logger.warning("Background data fetch task cancelled")
//            //            }
//            
//            //            var nearbyMesos: [MesoscaleDiscussion] {
//            //                return spcProvider.meso.filter {
//            //                    let poly = MKPolygon(coordinates: $0.coordinates, count: $0.coordinates.count)
//            //                    return PolygonHelpers.inPoly(user: locationProvider.resolvedUserLocation, polygon: poly)
//            //                }
//            //            }
//        }
        .onChange(of: scenePhase) { _, newPhase in
            locationMgr.updateMode(for: newPhase)
            showLocationPermissionAlert = (locationMgr.authStatus == .denied || locationMgr.authStatus == .restricted)
            
            if newPhase == .background {
                scheduleNextAppRefresh()
            } else if newPhase == .active {
                Task {
                    let center = UNUserNotificationCenter.current()
                    
                    do {
                        try await center.requestAuthorization(options: [.alert, .sound, .badge])
                    } catch {
                        logger.error("Error requesting notification permission: \(error.localizedDescription)")
                    }
                }
                
                Task {
                    await spcProvider.cleanup()
                    await spcProvider.sync()
                }
            }
        }
    }
    
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    // MARK: - Schedule Next App Refresh
    private func scheduleNextAppRefresh() {
        logger.debug("Checking if we need to schedule an app refresh")
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            logger.debug("Pending tasks: \(requests.count)")
            
            guard requests.isEmpty else { return } // If we don't have any pending requests, schedule a new one
            
            let sch = Scheduler(scheduleType: .convective)
            let nextRun = sch.getNextRunTime()
            
            guard let nextRun else { return } // Ensure we received the next runtime from teh scheduler
            
            // Create the task and set its next runtime
            let request = BGAppRefreshTaskRequest(identifier: appRefreshID)
            request.earliestBeginDate = nextRun
            
            do { try BGTaskScheduler.shared.submit(request) }
            catch { logger.error("Error submitting background task: \(error.localizedDescription)")}
        }
    }
}
