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
    private let provider = LocationProvider()
    @State private var locationMgr: LocationManager
    
    // Repos
    private let outlookRepo: ConvectiveOutlookRepo
    private let mesoRepo: MesoRepo
    private let watchRepo: WatchRepo
    private let stormRiskRepo: StormRiskRepo
    private let severeRiskRepo: SevereRiskRepo
    
    @State private var spcProvider: SpcProvider

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
        let loc = LocationManager(onUpdate: sink)
        
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
        _locationMgr = .init(wrappedValue: loc)
        _spcProvider = .init(wrappedValue: spc1)
    }
    
    var body: some Scene {
        WindowGroup {
            iPhoneHomeView()
                .environment(\.spcService, spcProvider)
                .environment(\.locationClient, makeLocationClient(provider: provider))
                .alert("Location Permission Needed",
                       isPresented: .constant(locationMgr.authStatus == .denied)) {
//                    Button("Settings") { locCoord.openSettings() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Enable location to see nearby weather risks and alerts.")
                }
        }
        .modelContainer(sharedModelContainer)
        .backgroundTask(.appRefresh(appRefreshID)) {
            await scheduleNextAppRefresh() // Ensure we schedule again
            
            await withTaskCancellationHandler {
                do {
                    let snap = await provider.snapshot()
                    
                    if let coord = snap?.coordinates {
                        await spcProvider.sync()
                        
                        let outlook = try await spcProvider.getLatestConvectiveOutlook()
                        
                        async let severeRiskv1 = spcProvider.getSevereRisk(for: coord)
                        async let stormRiskv1 = spcProvider.getStormRisk(for: coord)
                        
//                        let message = "Storm Activity: \(try await stormRiskv1.summary)\n\nSevere Activity: \(try await severeRiskv1.summary)\n\nFor: \(snap?.placemarkSummary, default: "Unknown")"
                        let message = "Latest severe weather outlook for \(snap?.placemarkSummary, default: "Unknown"):\nStorm Activity: \(try await stormRiskv1.summary)\nSevere Activity: \(try await severeRiskv1.summary)"
                        
                        let mgr = NotificationManager()
                        await mgr.notify(for: outlook, with: message)
                    }
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
            if newPhase == .background {
                scheduleNextAppRefresh()
//                locCoord.setBackground()
            } else if newPhase == .active {
//                locCoord.setForeground()
                Task {
                    let center = UNUserNotificationCenter.current()
                    
                    do {
                        try await center.requestAuthorization(options: [.alert, .sound, .badge])
                        scheduleNextAppRefresh()
                    } catch {
                        logger.error("Error requesting notification permission: \(error.localizedDescription)")
                    }
                }
                
                Task {
                    await spcProvider.cleanup()
                    await spcProvider.sync()
                }
            }
            
            //            if newPhase == .background {
            //                // Optionally re-schedule when going to background
            //                scheduleNextAppRefresh(earliest: Date().addingTimeInterval(30 * 60)) // placeholder; replace using CadencePlanner
            //            }
        }
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
