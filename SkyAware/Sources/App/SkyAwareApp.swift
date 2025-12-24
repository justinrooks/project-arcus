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
    private let deps = Dependencies.live()
//    private let appRefreshID = "com.skyaware.app.refresh"
    private let logger = Logger.mainApp
    
    // State
    @State private var didBootstrapBGRefresh = false
    @State private var showDisclaimerUpdate = false
    @State private var showLocationPermissionAlert = false
    
    // Location
//    @MainActor private let provider = LocationProvider()
//    @MainActor private let locationMgr: LocationManager
//    private let gridProvider: GridPointProvider
    
    // Repos
//    private let outlookRepo: ConvectiveOutlookRepo
//    private let mesoRepo: MesoRepo
//    private let watchRepo: WatchRepo
//    private let stormRiskRepo: StormRiskRepo
//    private let severeRiskRepo: SevereRiskRepo
//    private let healthStore: BgHealthStore
    
    // Providers
//    private let spcProvider: SpcProvider
//    private let nwsProvider: NwsProvider
    
    // Background
//    private let scheduler:BackgroundScheduler
//    private let orchestrator: BackgroundOrchestrator
//    private let refreshPolicy: RefreshPolicy
//    private let cadencePolicy: CadencePolicy
    
    // EnvVars
    @Environment(\.scenePhase) private var scenePhase
    
    // App Storage
    @AppStorage(
        "onboardingComplete",
        store: UserDefaults.shared
    ) private var onboardingComplete: Bool = false
    
    @AppStorage(
        "disclaimerAcceptedVersion",
        store: UserDefaults.shared
    ) private var disclaimerVersion = 0
    
    // Shared SwiftData context
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([ConvectiveOutlook.self, MD.self, WatchModel.self, StormRisk.self, SevereRisk.self, BgRunSnapshot.self, Watch.self])
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
    
    let currentDisclaimerVersion = 1
    
    init() {
#if DEBUG
        print(URL.applicationSupportDirectory.path(percentEncoded: false))
#endif
//        logger.info("App init started")
//        
//        // Setup Location Monitoring
//        let sink: LocationSink = { [provider] update in await provider.send(update: update) }
//        locationMgr = LocationManager(onUpdate: sink)
//        logger.info("LocationManager configured")
//        
//        // Configure the network cache
//        URLCache.shared = .skyAwareCache
//        logger.debug("URLCache configured for SkyAware")
//        
//        let nwsClient = NwsHttpClient()
//        
//        gridProvider = GridPointProvider(client: nwsClient, locationProvider: provider)
//        logger.info("GridPoint provider configured")
//        
//        // Create our data layer repos
//        outlookRepo    = ConvectiveOutlookRepo(modelContainer: sharedModelContainer)
//        mesoRepo       = MesoRepo(modelContainer: sharedModelContainer)
//        watchRepo      = WatchRepo(modelContainer: sharedModelContainer)
//        stormRiskRepo  = StormRiskRepo(modelContainer: sharedModelContainer)
//        severeRiskRepo = SevereRiskRepo(modelContainer: sharedModelContainer)
//        healthStore    = BgHealthStore(modelContainer: sharedModelContainer)
//        
//        logger.debug("Repositories initialized")
//        
//        let spc = SpcProvider(outlookRepo: outlookRepo,
//                               mesoRepo: mesoRepo,
//                               watchRepo: watchRepo,
//                               stormRiskRepo: stormRiskRepo,
//                               severeRiskRepo: severeRiskRepo,
//                               client: SpcHttpClient())
//        spcProvider = spc
//        logger.debug("SPC Provider initialized")
//        
//        let nws = NwsProvider(
//            watchRepo: watchRepo,
//            client: nwsClient)
//        nwsProvider = nws
//        logger.debug("NWS Provider initialized")
//        
//        let refresh: RefreshPolicy = .init()
//        refreshPolicy = refresh
//        cadencePolicy = CadencePolicy()
//        logger.info("Refresh policy & cadence configured")
//        
//        logger.debug("Composing morning summary engine")
//        let morning = MorningEngine(
//            rule: AmRangeLocalRule(),
//            gate: MorningGate(store: DefaultStore()),
//            composer: MorningComposer(),
//            sender: Sender()
//        )
//        
//        logger.debug("Composing meso notification engine")
//        let meso = MesoEngine(
//            rule: MesoRule(),
//            gate: MesoGate(store: DefaultMesoStore()),
//            composer: MesoComposer(),
//            sender: Sender(),
//            spc: spc
//        )
//        
//        @AppStorage(
//            "morningSummaryEnabled",
//            store: UserDefaults.shared
//        ) var morningSummaryEnabled: Bool = true
//        
//        @AppStorage(
//            "mesoNotificationEnabled",
//            store: UserDefaults.shared
//        ) var mesoNotificationEnabled: Bool = true
//
//        orchestrator = BackgroundOrchestrator(
//            spcProvider: spc,
//            locationProvider: provider,
//            policy: refresh,
//            engine: morning,
//            mesoEngine: meso,
//            health: healthStore,
//            cadence: cadencePolicy,
//            notificationSettings: .init(morningSummariesEnabled: morningSummaryEnabled,
//                                        mesoNotificationsEnabled: mesoNotificationEnabled)
//        )
//        
//        scheduler = BackgroundScheduler(refreshId: appRefreshID)
//        logger.info("Providers ready; background orchestrator configured")
    }
    
    var body: some Scene {
        WindowGroup {
            if onboardingComplete {
                AppRootView()
                    .environment(\.dependencies, deps)
//                    spcProvider: deps.spcProvider,
//                    nwsProvider: deps.nwsProvider,
//                    locationMgr: deps.locationManager,
//                    locationProv: deps.locationProvider
//                )
                .appBackground()
                .onAppear {
                    if disclaimerVersion < currentDisclaimerVersion {
                        showDisclaimerUpdate = true
                    }
                    if deps.locationManager.authStatus == .denied || deps.locationManager.authStatus == .restricted {
                        showLocationPermissionAlert = true
                    }
                }
                .sheet(isPresented: $showDisclaimerUpdate) {
                    // Just show the disclaimer screen in a sheet
                    NavigationStack {
                        DisclaimerView {
                            disclaimerVersion = currentDisclaimerVersion
                            showDisclaimerUpdate = false
                        }
                        .navigationTitle("Updated Disclaimer")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .interactiveDismissDisabled() // Can't swipe away
                }
                .sheet(isPresented: $showLocationPermissionAlert) {
                    // Just show the location screen in a sheet
                    NavigationStack {
                        LocationPermissionView(locationMgr: deps.locationManager) {
                            showLocationPermissionAlert = false
                        }
                        .navigationTitle("Location Restricted")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .interactiveDismissDisabled() // Can't swipe away
                }
            } else {
                OnboardingView(locationMgr: deps.locationManager)
                    .environment(\.spcSync, deps.spcProvider)
            }
        }
        .modelContainer(sharedModelContainer)
        .backgroundTask(.appRefresh(deps.appRefreshID)) {
            logger.info("Background app refresh started (id: \(deps.appRefreshID, privacy: .public))")
            let result = await deps.orchestrator.run()
            logger.info("Background app refresh completed with result: \(String(describing: result), privacy: .public)")
            
            // Schedule the next run
            await deps.scheduler.scheduleNextAppRefresh(nextRun: result.next)
            logger.info("Scheduled next app refresh at: \(result.next)")
        }
        .onChange(of: scenePhase) { _, newPhase in
            logger.info("Scene phase changed to: \(String(describing: newPhase), privacy: .public)")
            deps.locationManager.updateMode(for: newPhase)
            
            switch newPhase {
            case .background:
                Task {
                    let scheduler = BackgroundScheduler(refreshId: deps.appRefreshID)
                    let next = deps.refreshPolicy.getNextRunTime(for: .normal(60))
                    logger.info("App entered background; attempting to schedule next app refresh proactively: \(next.shorten(withDateStyle: .none))")
                    await scheduler.scheduleNextAppRefresh(nextRun: next)
                }
            case .inactive: // Swallow inactive state
                break
            case .active:
                // If its our first run, spin off a task to set up a background task
                // so we always have one
                if !didBootstrapBGRefresh {
                    didBootstrapBGRefresh = true
                    
                    // Schedule a background task greedy, so we start on the right foot
                    Task(priority: .background) {
                        logger.notice("Seeding initial background task")
                        let scheduler = BackgroundScheduler(refreshId: deps.appRefreshID)
                        await scheduler.ensureScheduled(using: deps.refreshPolicy)
                        logger.info("Background refresh scheduled")
                    }
                }
                
                // Opportunistically fetch and cleanup when activating the app to get us the
                // latest data.
                // Going to rely on the summary view to get most of the data since its the heart
                // of the app and what gets accessed first. 
                // TODO: Need to gate this so it only happens every hour or so, doesn't need
                //       to happen on every single activation.
                if onboardingComplete {
                    Task {
                        logger.notice("Starting data cleanup")
                        try? await deps.healthStore.purge()
                        logger.notice("Starting spc provider cleanup and sync")
                        await deps.spcProvider.cleanup()
                        logger.info("Spc provider cleanup finished")
//                        await nwsProvider.cleanup()
                        logger.info("Nws provider cleanup finished")
                        
                        // Changed this to just grab the mapping products in the background
                        // the summary view will load the text products for now. May need to
                        // tweak this if timing is an issue, that that flow seems better.
                        await deps.spcProvider.syncMapProducts()
                        logger.info("Spc map product sync finished")
//                        await spcProvider.sync()
//                        logger.info("Provider sync finished")
//                        logger.info("Need to grab watches here too...")
                    }
                }
            @unknown default:
                logger.warning("Phase transition error. Unknown phase")
                break
            }
        }
    }
}
