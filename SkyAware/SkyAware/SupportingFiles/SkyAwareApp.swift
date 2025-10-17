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
    private let logger = Logger.mainApp
    
    // Location
    @MainActor private let provider = LocationProvider()
    @MainActor private let locationMgr: LocationManager
    
    // Repos
    private let outlookRepo: ConvectiveOutlookRepo
    private let mesoRepo: MesoRepo
    private let watchRepo: WatchRepo
    private let stormRiskRepo: StormRiskRepo
    private let severeRiskRepo: SevereRiskRepo
    
    private let spcProvider: SpcProvider
    
    // Background
    private let orchestrator: BackgroundOrchestrator
    
    // EnvVars
    @Environment(\.scenePhase) private var scenePhase
    
    // Shared SwiftData context
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([ConvectiveOutlook.self, MD.self, WatchModel.self, StormRisk.self, SevereRisk.self])
        let config = ModelConfiguration("SkyAware_Data", schema: schema) //isStoredInMemoryOnly: false)
        do { return try ModelContainer(for: schema, configurations: config) }
        catch { fatalError("Could not create ModelContainer: \(error)") }
    }()
    
    init() {
#if DEBUG
        print(URL.applicationSupportDirectory.path(percentEncoded: false))
#endif
        
        // Setup Location Monitoring
        let sink: LocationSink = { [provider] update in await provider.send(update: update) }
        locationMgr = LocationManager(onUpdate: sink)
        
        // Configure the network cache
        URLCache.shared = .skyAwareCache
        
        // Create our data layer repos
        outlookRepo    = ConvectiveOutlookRepo(modelContainer: sharedModelContainer)
        mesoRepo       = MesoRepo(modelContainer: sharedModelContainer)
        watchRepo      = WatchRepo(modelContainer: sharedModelContainer)
        stormRiskRepo  = StormRiskRepo(modelContainer: sharedModelContainer)
        severeRiskRepo = SevereRiskRepo(modelContainer: sharedModelContainer)
        
        let spc = SpcProvider(outlookRepo: outlookRepo,
                               mesoRepo: mesoRepo,
                               watchRepo: watchRepo,
                               stormRiskRepo: stormRiskRepo,
                               severeRiskRepo: severeRiskRepo,
                               client: SpcHttpClient())
        spcProvider = spc
        orchestrator = BackgroundOrchestrator(spcProvider: spc, locationProvider: provider)
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView(
                spcProvider: spcProvider,
                locationMgr: locationMgr,
                locationProv: provider
            )
        }
        .modelContainer(sharedModelContainer)
        .backgroundTask(.appRefresh(appRefreshID)) {
            // 1. Kick off the tasks
            let result = await orchestrator.run()
            
            // 2. Schedule the next
            let scheduler = Scheduler()
            scheduler.scheduleNextAppRefresh(result)
        }
        .onChange(of: scenePhase) { _, newPhase in
            locationMgr.updateMode(for: newPhase)
            
            if newPhase == .background {
                let scheduler = Scheduler()
                scheduler.scheduleNextAppRefresh(.success)
            } else if newPhase == .active {
                Task.detached {
                    let center = UNUserNotificationCenter.current()
                    let settings = await center.notificationSettings()
                    if settings.authorizationStatus == .notDetermined {
                        do {
                            try await center.requestAuthorization(options: [.alert, .sound, .badge])
                        } catch {
                            logger.error("Error requesting notification permission: \(error.localizedDescription)")
                        }
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
}
