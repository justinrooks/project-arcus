//
//  SkyAwareApp.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import SwiftData
import BackgroundTasks
import CoreLocation
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
    @State private var launchPresentation: LaunchPresentationState?
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
            rootContent
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
                    await locationSession.drainPendingLocationUploads()
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
    @ViewBuilder
    var rootContent: some View {
        if onboardingComplete {
            homeContent
        } else {
            onboardingContent
        }
    }

    var homeContent: some View {
        currentHomeView
            .environment(\.dependencies, deps)
            .environment(locationSession)
            .appBackground()
            .onAppear(perform: handleHomeOnAppear)
            .sheet(item: $launchPresentation, content: launchPresentationSheet)
    }

    @ViewBuilder
    var currentHomeView: some View {
        if ProcessInfo.processInfo.environment["UI_TESTS_STATIC_HOME"] == "1" {
            HomeView(
                initialMesos: Self.uiTestSeedMesos,
                initialAlerts: Self.uiTestSeedWatches
            )
        } else {
            HomeView()
        }
    }

    var onboardingContent: some View {
        OnboardingView()
            .environment(\.dependencies, deps)
            .environment(locationSession)
    }

    func handleHomeOnAppear() {
        updateLaunchPresentation()
    }

    @ViewBuilder
    func launchPresentationSheet(_ presentation: LaunchPresentationState) -> some View {
        switch presentation {
        case .disclaimerUpdate:
            disclaimerSheet()
        case .locationRestricted:
            locationPermissionSheet()
        }
    }

    func disclaimerSheet() -> some View {
        NavigationStack {
            DisclaimerView {
                disclaimerVersion = currentDisclaimerVersion
                updateLaunchPresentation()
            }
            .navigationTitle("Updated Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    func locationPermissionSheet() -> some View {
        NavigationStack {
            LocationPermissionView(
                isWorking: false,
                statusMessage: nil,
                onEnable: {
                    locationSession.requestInteractiveAuthorization()
                    launchPresentation = nil
                },
                onSkip: {
                    launchPresentation = nil
                }
            )
            .navigationTitle("Location Restricted")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    func updateLaunchPresentation() {
        launchPresentation = LaunchPresentationState.resolve(
            disclaimerVersion: disclaimerVersion,
            currentDisclaimerVersion: currentDisclaimerVersion,
            authorizationStatus: locationSession.authorizationStatus,
            suppressLocationRestrictedSheet: ProcessInfo.processInfo.environment["UI_TESTS_SUPPRESS_LOCATION_RESTRICTED_SHEET"] == "1"
        )
    }

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

    static var uiTestSeedWatches: [AlertDTO] {
        let warningIssued = Date().addingTimeInterval(-900)
        let issued = Date().addingTimeInterval(-1_800)
        let olderIssued = Date().addingTimeInterval(-2_400)
        let ends = Date().addingTimeInterval(7_200)
        return [
            AlertDTO(
                id: "ui-test-warning-001",
                messageId: "ui-test-warning-message-001",
                currentRevisionSent: warningIssued,
                title: "UI Test Severe Thunderstorm Warning",
                headline: "UI Test Severe Thunderstorm Warning Headline",
                issued: warningIssued,
                expires: ends,
                ends: ends,
                messageType: "Alert",
                sender: "NWS Test Office",
                severity: "Extreme",
                urgency: "Immediate",
                certainty: "Likely",
                description: "UI test warning description for list ordering and accessibility validation. This longer warning title is used to exercise wrapping at accessibility text sizes.",
                instruction: "Seek shelter immediately and stay away from windows.",
                response: "Execute",
                areaSummary: "Tulsa Metro",
                geometryData: nil,
                tornadoDetection: nil,
                tornadoDamageThreat: nil,
                maxWindGust: "70",
                maxHailSize: "2.00",
                windThreat: nil,
                hailThreat: nil,
                thunderstormDamageThreat: "Destructive",
                flashFloodDetection: nil,
                flashFloodDamageThreat: nil
            ),
            AlertDTO(
                id: "ui-test-watch-001",
                messageId: "ui-test-watch-message-001",
                currentRevisionSent: issued,
                title: "Tornado Watch",
                headline: "UI Test Tornado Watch Headline",
                issued: issued,
                expires: ends,
                ends: ends,
                messageType: "Alert",
                sender: "NWS Test Office",
                severity: "Severe",
                urgency: "Immediate",
                certainty: "Likely",
                description: "UI test watch description for navigation and sheet validation. This longer summary text is used to verify that VoiceOver announces the full visible weather content without replacing it with a generic label.",
                instruction: "Seek shelter immediately if threatening weather approaches, move to an interior room on the lowest floor, and stay away from windows until the warning is lifted.",
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
            ),
            AlertDTO(
                id: "ui-test-watch-002",
                messageId: "ui-test-watch-message-002",
                currentRevisionSent: olderIssued,
                title: "UI Test Fire Weather Watch",
                headline: "UI Test Fire Weather Watch Headline",
                issued: olderIssued,
                expires: ends,
                ends: ends,
                messageType: "Alert",
                sender: "NWS Test Office",
                severity: "Moderate",
                urgency: "Expected",
                certainty: "Likely",
                description: "Second UI test watch description for alert center navigation validation.",
                instruction: "Avoid activities that could start fires.",
                response: "Monitor",
                areaSummary: "UI Test Fire Zone",
                geometryData: nil,
                tornadoDetection: nil,
                tornadoDamageThreat: nil,
                maxWindGust: nil,
                maxHailSize: nil,
                windThreat: nil,
                hailThreat: nil,
                thunderstormDamageThreat: nil,
                flashFloodDetection: nil,
                flashFloodDamageThreat: nil
            )
        ]
    }

    static var uiTestSeedMesos: [MdDTO] {
        MD.sampleDiscussionDTOs
    }
}

enum LaunchPresentationState: Identifiable, Equatable {
    case disclaimerUpdate
    case locationRestricted

    var id: Self { self }

    static func resolve(
        disclaimerVersion: Int,
        currentDisclaimerVersion: Int,
        authorizationStatus: CLAuthorizationStatus,
        suppressLocationRestrictedSheet: Bool
    ) -> LaunchPresentationState? {
        if disclaimerVersion < currentDisclaimerVersion {
            return .disclaimerUpdate
        }

        guard suppressLocationRestrictedSheet == false else {
            return nil
        }

        if authorizationStatus.isRestrictedForLaunchPresentation {
            return .locationRestricted
        }

        return nil
    }
}

private extension CLAuthorizationStatus {
    var isRestrictedForLaunchPresentation: Bool {
        self == .denied || self == .restricted
    }
}
