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
    
    // State
    @State private var didBootstrapBGRefresh = false
    
    // Location
    @MainActor private let provider = LocationProvider()
    @MainActor private let locationMgr: LocationManager
    
    // Repos
    private let outlookRepo: ConvectiveOutlookRepo
    private let mesoRepo: MesoRepo
    private let watchRepo: WatchRepo
    private let stormRiskRepo: StormRiskRepo
    private let severeRiskRepo: SevereRiskRepo
    private let healthStore: BgHealthStore
    
    // Providers
    private let spcProvider: SpcProvider
    
    // Background
    private let orchestrator: BackgroundOrchestrator
    private let refreshPolicy: RefreshPolicy
    private let cadencePolicy: CadencePolicy
    
    // EnvVars
    @Environment(\.scenePhase) private var scenePhase
    
    // Shared SwiftData context
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([ConvectiveOutlook.self, MD.self, WatchModel.self, StormRisk.self, SevereRisk.self, BgRunSnapshot.self])
        let config = ModelConfiguration("SkyAware_Data", schema: schema) //isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            Logger.mainApp.debug("ModelContainer created for schema: SkyAware_Data")
            return container
        } catch {
            Logger.mainApp.critical("Failed to create ModelContainer: \(error.localizedDescription, privacy: .public)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
#if DEBUG
        print(URL.applicationSupportDirectory.path(percentEncoded: false))
#endif
        logger.info("App init started")
        
        // Setup Location Monitoring
        let sink: LocationSink = { [provider] update in await provider.send(update: update) }
        locationMgr = LocationManager(onUpdate: sink)
        logger.info("LocationManager configured")
        
        // Configure the network cache
        URLCache.shared = .skyAwareCache
        logger.debug("URLCache configured for SkyAware")
        
        // Create our data layer repos
        outlookRepo    = ConvectiveOutlookRepo(modelContainer: sharedModelContainer)
        mesoRepo       = MesoRepo(modelContainer: sharedModelContainer)
        watchRepo      = WatchRepo(modelContainer: sharedModelContainer)
        stormRiskRepo  = StormRiskRepo(modelContainer: sharedModelContainer)
        severeRiskRepo = SevereRiskRepo(modelContainer: sharedModelContainer)
        healthStore    = BgHealthStore(modelContainer: sharedModelContainer)
        
        logger.debug("Repositories initialized")
        
        let spc = SpcProvider(outlookRepo: outlookRepo,
                               mesoRepo: mesoRepo,
                               watchRepo: watchRepo,
                               stormRiskRepo: stormRiskRepo,
                               severeRiskRepo: severeRiskRepo,
                               client: SpcHttpClient())
        spcProvider = spc
        logger.debug("SPC Provider initialized")
        
        let refresh: RefreshPolicy = .init()
        refreshPolicy = refresh
        logger.info("Refresh policy configured")
        
        logger.debug("Composing morning summary engine")
        let morning = MorningEngine(
            rule: AmRangeLocalRule(),
            gate: MorningGate(store: DefaultStore()),
            composer: MorningComposer(),
            sender: MorningSender()
        )
        cadencePolicy = CadencePolicy()
        orchestrator = BackgroundOrchestrator(
            spcProvider: spc,
            locationProvider: provider,
            policy: refresh,
            engine: morning,
            health: healthStore,
            cadence: cadencePolicy
        )
        logger.info("Providers ready; background orchestrator configured")
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
            logger.info("Background app refresh started (id: \(self.appRefreshID, privacy: .public))")
            let result = await orchestrator.run()
            logger.info("Background app refresh completed with result: \(String(describing: result), privacy: .public)")
            
            // Schedule the next run
            let scheduler = BackgroundScheduler(refreshId: appRefreshID)
            await scheduler.scheduleNextAppRefresh(nextRun: result.next)
            logger.info("Scheduled next app refresh at: \(result.next)")
        }
        .onChange(of: scenePhase) { _, newPhase in
            logger.info("Scene phase changed to: \(String(describing: newPhase), privacy: .public)")
            locationMgr.updateMode(for: newPhase)
            
            switch newPhase {
            case .background:
                Task {
                    let scheduler = BackgroundScheduler(refreshId: appRefreshID)
                    let next = refreshPolicy.getNextRunTime(for: .normal(60))
                    logger.info("App entered background; attempting to schedule next app refresh proactively: \(next.toShortTime())")
                    await scheduler.scheduleNextAppRefresh(nextRun: next)
                }
            case .inactive: // Swallow inactive state
                break
            case .active:
                // If its our first run, spin off a task to set up a background task
                // so we always have one
                if !didBootstrapBGRefresh {
                    didBootstrapBGRefresh = true
                    
                    // Schedule a background task greedy, so we don't have old data
                    Task.detached(priority: .utility) {
                        logger.notice("Seeding initial background task")
                        let scheduler = BackgroundScheduler(refreshId: appRefreshID)
                        await scheduler.ensureScheduled(using: refreshPolicy)
                        logger.info("Background refresh scheduled")
                    }
                }
                
                // Opportunistically fetch and cleanup when activating the app to get us the
                // latest data.
                // TODO: Need to gate this so it only happens every hour or so, doesn't need
                //       to happen on every single activation.
                Task {
                    logger.notice("Starting background job history cleanup")
                    try? await healthStore.purge()
                    logger.notice("Starting provider cleanup and sync")
                    await spcProvider.cleanup()
                    logger.info("Provider cleanup finished")
                    await spcProvider.sync()
                    logger.info("Provider sync finished")
                }
                
                // Spin off a task to check notification settings
                Task.detached {
                    let center = UNUserNotificationCenter.current()
                    let settings = await center.notificationSettings()
                    logger.info("Current notification authorization status: \(String(describing: settings.authorizationStatus), privacy: .public)")
                    if settings.authorizationStatus == .notDetermined {
                        do {
                            try await center.requestAuthorization(options: [.alert, .sound, .badge])
                            logger.notice("Notification authorization requested: user responded (status may update asynchronously)")
                        } catch {
                            logger.error("Error requesting notification permission: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
            @unknown default:
                logger.warning("Phase transition error. Unknown phase")
                break
            }
        }
    }
    
//    private var isPreview: Bool {
//        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
//    }
}

