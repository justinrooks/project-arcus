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
    // EnvVars
    @Environment(\.scenePhase) private var scenePhase
    
    // Dependencies
    private let deps = Dependencies.live()
    private let logger = Logger.mainApp
    
    // State
    @State private var didBootstrapBGRefresh = false
    @State private var showDisclaimerUpdate = false
    @State private var showLocationPermissionAlert = false
    private let currentDisclaimerVersion = 1
    
    // App Storage
    @AppStorage(
        "onboardingComplete",
        store: UserDefaults.shared
    ) private var onboardingComplete: Bool = false
    
    @AppStorage(
        "disclaimerAcceptedVersion",
        store: UserDefaults.shared
    ) private var disclaimerVersion = 0
    
    init() {
#if DEBUG
        print(URL.applicationSupportDirectory.path(percentEncoded: false))
#endif
    }
    
    var body: some Scene {
        WindowGroup {
            if onboardingComplete {
                HomeView()
                    .environment(\.dependencies, deps)
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
                    .environment(\.dependencies, deps)
            }
        }
        .modelContainer(deps.modelContainer)
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
                        #warning("Enable nws data cleanup here")
                        // await nwsProvider.cleanup()
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
