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
    @UIApplicationDelegateAdaptor(SkyAwareAppDelegate.self) private var appDelegate
    
    // EnvVars
    @Environment(\.scenePhase) private var scenePhase
    
    // Dependencies
    private let deps: Dependencies
    @State private var locationSession: LocationSession
    @State private var remoteAlertPresentationState: RemoteAlertPresentationState
    @State private var runtimeConnectivityState: RuntimeConnectivityState
    private let logger = Logger.appMain
    
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
    
    @MainActor
    init() {
        Self.applyUITestDefaultsOverridesIfNeeded()

        let runtimeConnectivityState = RuntimeConnectivityState()
        runtimeConnectivityState.startMonitoringIfNeeded()

        let deps = Dependencies.live(
            arcusReachabilityTracker: ArcusSignalReachabilityTracker { availability in
                await MainActor.run {
                    runtimeConnectivityState.updateArcusSignalAvailability(availability)
                }
            }
        )
        self.deps = deps
        let remoteAlertPresentationState = RemoteAlertPresentationState()
        _runtimeConnectivityState = State(initialValue: runtimeConnectivityState)
        _remoteAlertPresentationState = State(initialValue: remoteAlertPresentationState)
        Self.applyUITestLocationOverridesIfNeeded(locationSession: deps.locationSession)
        _locationSession = State(initialValue: deps.locationSession)
        let remoteAlertWidgetSnapshotRefreshDriver: RemoteAlertWidgetSnapshotRefreshDriver? = {
            guard let widgetSnapshotStore = try? WidgetSnapshotStore() else {
                return nil
            }
            let widgetSnapshotRefresher = WidgetSnapshotRefreshCoordinator(store: widgetSnapshotStore)
            return RemoteAlertWidgetSnapshotRefreshDriver(
                projectionStore: deps.homeProjectionStore,
                widgetSnapshotRefresher: widgetSnapshotRefresher
            )
        }()
        SkyAwareAppDelegate.install(
            remoteHotAlertHandler: RemoteHotAlertHandler(
                coordinator: deps.homeIngestionCoordinator,
                arcusAlerts: deps.arcusProvider,
                presentationState: remoteAlertPresentationState,
                widgetSnapshotRefreshDriver: remoteAlertWidgetSnapshotRefreshDriver
            )
        )
#if DEBUG
        Logger.appMain.debug("Application support directory: \(URL.applicationSupportDirectory.path(percentEncoded: false), privacy: .public)")
#endif
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingComplete {
                    Group {
                        if ProcessInfo.processInfo.environment["UI_TESTS_STATIC_HOME"] == "1" {
                            HomeView(initialWatches: Self.uiTestSeedWatches)
                        } else {
                            HomeView()
                        }
                    }
                        .environment(\.dependencies, deps)
                        .environment(locationSession)
                        .appBackground()
                        .onAppear {
                            if disclaimerVersion < currentDisclaimerVersion {
                                showDisclaimerUpdate = true
                            }
                            let suppressLocationRestrictedSheet = ProcessInfo.processInfo.environment["UI_TESTS_SUPPRESS_LOCATION_RESTRICTED_SHEET"] == "1"
                            if (locationSession.authorizationStatus == .denied || locationSession.authorizationStatus == .restricted) &&
                                suppressLocationRestrictedSheet == false {
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
                                LocationPermissionView(
                                    isWorking: false,
                                    statusMessage: nil,
                                    onEnable: {
                                        locationSession.requestInteractiveAuthorization()
                                        showLocationPermissionAlert = false
                                    },
                                    onSkip: {
                                        showLocationPermissionAlert = false
                                    }
                                )
                                .navigationTitle("Location Restricted")
                                .navigationBarTitleDisplayMode(.inline)
                            }
                            .interactiveDismissDisabled() // Can't swipe away
                        }
                } else {
                    OnboardingView()
                        .environment(\.dependencies, deps)
                        .environment(locationSession)
                }
            }
            .environment(remoteAlertPresentationState)
            .environment(runtimeConnectivityState)
            .onAppear {
                locationSession.handleScenePhaseChange(scenePhase)
            }
        }
        .modelContainer(deps.modelContainer)
        .backgroundTask(.appRefresh(deps.appRefreshID)) {
            logger.notice("Background app refresh started (id: \(deps.appRefreshID, privacy: .public))")
            let result = await deps.orchestrator.run()
            logger.notice("Background app refresh completed with result: \(String(describing: result), privacy: .public)")
            
            // Schedule the next run
            await deps.scheduler.scheduleNextAppRefresh(nextRun: result.next)
            logger.notice("Scheduled next app refresh at: \(result.next, privacy: .public)")
        }
        .onChange(of: scenePhase) { _, newPhase in
            logger.debug("Scene phase changed to: \(String(describing: newPhase), privacy: .public)")
            locationSession.handleScenePhaseChange(newPhase)
            
            switch newPhase {
            case .background:
                Task {
                    let scheduler = BackgroundScheduler(refreshId: deps.appRefreshID)
                    let next = deps.refreshPolicy.getNextRunTime(for: .normal(60))
                    logger.notice("App entered background; attempting to schedule next app refresh proactively: \(next.shorten(withDateStyle: .none), privacy: .public)")
                    await scheduler.scheduleNextAppRefresh(nextRun: next)
                }
            case .inactive: // Swallow inactive state
                break
            case .active:
                Task(priority: .utility) {
                    let installationId = await InstallationIdentityStore.shared.installationId()
                    logger.debug("Installation ID ready with \(installationId.count, privacy: .public) chars")
                    await RemoteNotificationRegistrar.shared.registerForRemoteNotificationsIfAuthorized(context: "scene-active")
                }
                
                // If its our first run, spin off a task to set up a background task
                // so we always have one
                if !didBootstrapBGRefresh {
                    didBootstrapBGRefresh = true
                    
                    // Schedule a background task greedy, so we start on the right foot
                    Task(priority: .background) {
                        logger.notice("Seeding initial background task")
                        let scheduler = BackgroundScheduler(refreshId: deps.appRefreshID)
                        await scheduler.ensureScheduled(using: deps.refreshPolicy)
                        logger.notice("Background refresh scheduled")
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
                        logger.notice("Starting activation cleanup")
                        try? await deps.healthStore.purge()
                        logger.notice("Starting SPC cleanup")
                        await deps.spcProvider.cleanup()
                        logger.info("SPC cleanup finished")
                        await deps.arcusProvider.cleanup()
                        logger.info("Arcus alert cleanup finished")
                        
                        // HomeView owns foreground startup refresh and map product sync.
                        // Keep app-level activation work focused on cleanup/scheduling.
                        logger.info("Activation cleanup finished; HomeView will drive foreground data refresh")
                    }
                }
            @unknown default:
                logger.warning("Phase transition error. Unknown phase")
                break
            }
        }
    }
}

private extension SkyAwareApp {
    @MainActor
    static func applyUITestDefaultsOverridesIfNeeded() {
        let env = ProcessInfo.processInfo.environment
        let shouldResetOnboarding = env["UI_TESTS_RESET_ONBOARDING"] == "1"
        let shouldForceOnboardingComplete = env["UI_TESTS_FORCE_ONBOARDING_COMPLETE"] == "1"

        guard shouldResetOnboarding || shouldForceOnboardingComplete else { return }

        let suiteName = "com.justinrooks.skyaware"
        guard let sharedDefaults = UserDefaults(suiteName: suiteName) else { return }

        if shouldResetOnboarding {
            sharedDefaults.removePersistentDomain(forName: suiteName)
        }

        if shouldForceOnboardingComplete {
            sharedDefaults.set(true, forKey: "onboardingComplete")
            sharedDefaults.set(1, forKey: "disclaimerAcceptedVersion")
            UserDefaults.standard.set(true, forKey: "onboardingComplete")
            UserDefaults.standard.set(1, forKey: "disclaimerAcceptedVersion")
        } else {
            sharedDefaults.set(false, forKey: "onboardingComplete")
            sharedDefaults.set(0, forKey: "disclaimerAcceptedVersion")
            UserDefaults.standard.removeObject(forKey: "onboardingComplete")
            UserDefaults.standard.removeObject(forKey: "disclaimerAcceptedVersion")
        }

        sharedDefaults.synchronize()
        UserDefaults.standard.synchronize()
    }

    @MainActor
    static func applyUITestLocationOverridesIfNeeded(locationSession: LocationSession) {
        switch ProcessInfo.processInfo.environment["UI_TESTS_LOCATION_AUTH_MODE"] {
        case "restricted":
            locationSession.authorizationStatus = .denied
            locationSession.currentContext = nil
            locationSession.startupState = .failed("location-unavailable")
        case "authorized":
            locationSession.authorizationStatus = .authorizedWhenInUse
            if case .failed = locationSession.startupState {
                locationSession.startupState = .acquiringLocation
            }
        default:
            break
        }
    }

    static var uiTestSeedWatches: [WatchRowDTO] {
        let issued = Date().addingTimeInterval(-1_800)
        let ends = Date().addingTimeInterval(7_200)
        return [
            WatchRowDTO(
                id: "ui-test-watch-001",
                messageId: "ui-test-watch-message-001",
                currentRevisionSent: issued,
                title: "UI Test Tornado Watch",
                headline: "UI Test Tornado Watch Headline",
                issued: issued,
                expires: ends,
                ends: ends,
                messageType: "Alert",
                sender: "NWS Test Office",
                severity: "Severe",
                urgency: "Immediate",
                certainty: "Likely",
                description: "UI test watch description for navigation and sheet validation.",
                instruction: "Seek shelter if threatening weather approaches.",
                response: "Execute",
                areaSummary: "UI Test County",
                geometryData: nil,
                tornadoDetection: "Radar indicated",
                tornadoDamageThreat: "Possible",
                maxWindGust: "70",
                maxHailSize: "1.00",
                windThreat: nil,
                hailThreat: nil,
                thunderstormDamageThreat: nil,
                flashFloodDetection: nil,
                flashFloodDamageThreat: nil
            )
        ]
    }
}
