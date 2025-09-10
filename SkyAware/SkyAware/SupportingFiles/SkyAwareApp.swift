//
//  SkyAwareApp.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
//import SwiftData
import BackgroundTasks
import OSLog

@main
struct SkyAwareApp: App {
    private let appRefreshID = "com.skyaware.app.refresh"
    private let mesoRefreshID = "com.skyaware.meso.refresh"
    private let logger = Logger.mainApp
    
    @State private var locationProvider: LocationManager
    @State private var prov: SpcProvider
    @State private var summaryProvider: SummaryProvider
    
    //    @State private var locationProvider = LocationManager()
    //    @State private var prov = SpcProvider(service: SpcService(client: SpcClient()))
    //    @State private var summaryProvider = SummaryProvider(provider: prov, location: locationProvider)
    
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        let memoryCapacity = 4 * 1024 * 1024 // 4 MB
        let diskCapacity = 100 * 1024 * 1024 // 100 MB
        URLCache.shared = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "skyaware-dataCache"
        )
        
        let loc = LocationManager()
        let spc = SpcProvider(client: SpcClient())
        let sum = SummaryProvider(provider: spc, location: loc)
        
        _locationProvider = .init(wrappedValue: loc)
        _prov = .init(wrappedValue: spc)
        _summaryProvider = .init(wrappedValue: sum)
    }
    
    //    var sharedModelContainer: ModelContainer = {
    //        let schema = Schema([FeedCache.self])
    //        //        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
    //        do { return try ModelContainer(for: schema, configurations: []) }// configurations: [modelConfiguration] }
    //        catch { fatalError("Could not create ModelContainer: \(error)") }
    //    }()
    
    // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.skyaware.app.refresh"]
    
    var body: some Scene {
        WindowGroup {
            if (locationProvider.isAuthorized) {
                iPhoneHomeView()
                    .environment(prov)
                    .environment(locationProvider)
                    .environment(summaryProvider)
            } else {
                Text("Missing Location Authorization")
            }
        }
        //        .modelContainer(sharedModelContainer)
        .backgroundTask(.appRefresh(appRefreshID)) {
            await scheduleNextAppRefresh() // Ensure we schedule again
            
            await withTaskCancellationHandler {
                _ = await prov.loadFeedAsync()
                
                let stormRisk = await summaryProvider.getStormRisk()
                let severeRisk = await summaryProvider.getSevereRisk()
                
                let message = "Storm Activity: \(stormRisk.summary)\nSevere Activity: \(severeRisk.summary)"
                
                let ol = await prov.outlooks
                let mostRecentArticle = ol.max { $0.published < $1.published }
                
                let mgr = NotificationManager()
                await mgr.notify(for: mostRecentArticle, with: message)
            } onCancel: {
                logger.warning("Background data fetch task cancelled")
            }
        }
        .backgroundTask(.appRefresh(mesoRefreshID)) {
            // Schedule
            // query for mesos
            // if mesos, send notification
//            await withTaskCancellationHandler {
//                _ = await prov.loadFeedAsync()
//                
//                let ol = await prov.outlooks
//                let mostRecentArticle = ol.max { $0.published < $1.published }
//                
//                let mesos = prov.meso
//                
//                let mgr = NotificationManager()
//                await mgr.notify(for: mostRecentArticle, with: message)
//            } onCancel: {
//                logger.warning("Background data fetch task cancelled")
//            }
            
//            var nearbyMesos: [MesoscaleDiscussion] {
//                return spcProvider.meso.filter {
//                    let poly = MKPolygon(coordinates: $0.coordinates, count: $0.coordinates.count)
//                    return PolygonHelpers.inPoly(user: locationProvider.resolvedUserLocation, polygon: poly)
//                }
//            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                scheduleNextAppRefresh()
            } else if newPhase == .active {
                Task {
                    let center = UNUserNotificationCenter.current()

                    do {
                        try await center.requestAuthorization(options: [.alert, .sound, .badge])
                        scheduleNextAppRefresh()
                    } catch {
                        logger.error("Error requesting notification permission: \(error.localizedDescription)")
                    }
                }
            }
            
            //            if newPhase == .background {
            //                // Optionally re-schedule when going to background
            //                scheduleNextAppRefresh(earliest: Date().addingTimeInterval(30 * 60)) // placeholder; replace using CadencePlanner
            //            }
        }
    }
    

    
    // MARK - Schedule Next App Refresh
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
