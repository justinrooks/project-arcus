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
import ArcusCore

// e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.skyaware.app.refresh"]

@main
struct SkyAwareApp: App {
    @UIApplicationDelegateAdaptor(SkyAwareAppDelegate.self) private var appDelegate
    
    // EnvVars
    @Environment(\.scenePhase) private var scenePhase
    
    // Dependencies
    @State private var startup: AppStartup

    private var deps: Dependencies? { startup.dependencies }
    @State private var remoteAlertPresentationState: RemoteAlertPresentationState
    @State private var runtimeConnectivityState: RuntimeConnectivityState
    private let logger = Logger.appMain
    
    // State
    @State private var didBootstrapBGRefresh = false
    @State private var launchPresentation: LaunchPresentationState?
    private let currentDisclaimerVersion = 1

    private var isUITestStaticHome: Bool {
        ProcessInfo.processInfo.environment["UI_TESTS_STATIC_HOME"] == "1"
    }

    private var isUITestNoCacheResolving: Bool {
        isUITestStaticHome && ProcessInfo.processInfo.environment["UI_TESTS_NO_CACHE_RESOLVING"] == "1"
    }
    
    // App Storage
    @AppStorage(
        "onboardingComplete",
        store: UserDefaults.shared
    ) private var onboardingComplete: Bool = false
    
    @AppStorage(
        "disclaimerAcceptedVersion",
        store: UserDefaults.shared
    ) private var disclaimerVersion = 0

    @AppStorage(
        "activationCleanupLastRunAt",
        store: UserDefaults.shared
    ) private var activationCleanupLastRunAt: Double = 0
    
    @MainActor
    init() {
        Self.applyUITestDefaultsOverridesIfNeeded()

        let runtimeConnectivityState = RuntimeConnectivityState()
        runtimeConnectivityState.startMonitoringIfNeeded()

        let remoteAlertPresentationState = RemoteAlertPresentationState()
        _runtimeConnectivityState = State(initialValue: runtimeConnectivityState)
        _remoteAlertPresentationState = State(initialValue: remoteAlertPresentationState)
        let startup = AppStartup(
            makeDependencies: {
#if DEBUG
                if ProcessInfo.processInfo.environment["UI_TESTS_STATIC_HOME"] == "1",
                   ProcessInfo.processInfo.environment["UI_TESTS_STORAGE_UNAVAILABLE"] == "1" {
                    throw CocoaError(.fileReadNoPermission)
                }
#endif
                return try Dependencies.live(
                    arcusReachabilityTracker: ArcusSignalReachabilityTracker { availability in
                        await MainActor.run {
                            runtimeConnectivityState.updateArcusSignalAvailability(availability)
                        }
                    }
                )
            },
            onReady: { deps in
                Self.applyUITestLocationOverridesIfNeeded(locationSession: deps.locationSession)
                Self.applyUITestStormSetupFixtureIfNeeded(locationSession: deps.locationSession)
                let widgetDriver = (try? WidgetSnapshotStore()).map {
                    RemoteAlertWidgetSnapshotRefreshDriver(
                        projectionStore: deps.homeProjectionStore,
                        widgetSnapshotRefresher: WidgetSnapshotRefreshCoordinator(store: $0)
                    )
                }
                SkyAwareAppDelegate.install(
                    remoteHotAlertHandler: RemoteHotAlertHandler(
                        coordinator: deps.homeIngestionCoordinator,
                        arcusAlerts: deps.arcusProvider,
                        presentationState: remoteAlertPresentationState,
                        widgetSnapshotRefreshDriver: widgetDriver,
                        allowsBackgroundIngestion: deps.allowsBackgroundPersistence
                    )
                )
            }
        )
        _startup = State(initialValue: startup)
        SkyAwareAppDelegate.install(startup: startup)
        startup.retry()
#if DEBUG
        Logger.appMain.debug("Application support directory: \(URL.applicationSupportDirectory.path(percentEncoded: false), privacy: .public)")
#endif
    }
    
    var body: some Scene {
        WindowGroup {
            LaunchSplashContainer {
                rootContent
            }
                .preferredColorScheme(Self.uiTestPreferredColorScheme)
                .environment(remoteAlertPresentationState)
                .environment(runtimeConnectivityState)
        }
        .backgroundTask(.appRefresh(Dependencies.liveAppRefreshID)) {
            let attemptID = UUID().uuidString
            logger.notice("Background refresh invoked attempt=\(attemptID, privacy: .public)")
            guard let deps = await startup.retry() else {
                let reason = await startup.failureDiagnostic ?? "startup-not-ready"
                await BackgroundRefreshExecution.reject(attemptID: attemptID, reason: reason) {
                    await BackgroundScheduler(refreshId: Dependencies.liveAppRefreshID)
                        .ensureScheduled(using: RefreshPolicy())
                }
                return
            }
            await BackgroundRefreshExecution.run(
                attemptID: attemptID,
                allowsBackgroundPersistence: deps.allowsBackgroundPersistence,
                scheduleFallback: {
                    await deps.scheduler.ensureScheduled(using: deps.refreshPolicy)
                },
                runPersistentLifecycle: {
                    logger.notice("Background app refresh started (id: \(deps.appRefreshID, privacy: .public))")
                    let lifecycle = BackgroundRefreshLifecycle(
                        beginRun: {
                            let run = await deps.orchestrator.beginRun()
                            logger.notice("Background refresh admitted attempt=\(attemptID, privacy: .public) run=\(run.runId, privacy: .public)")
                            return run
                        },
                        scheduleFallback: {
                            await deps.scheduler.ensureScheduled(using: deps.refreshPolicy)
                        },
                        runOrchestration: { run in
                            await deps.orchestrator.run(run)
                        },
                        scheduleAuthoritative: { nextRun in
                            await deps.scheduler.scheduleEvaluatedNextAppRefresh(nextRun: nextRun)
                        },
                        logger: logger
                    )
                    _ = await lifecycle.run()
                }
            )
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard isUITestStaticHome == false else { return }
            logger.debug("Scene phase changed to: \(String(describing: newPhase), privacy: .public)")
            if newPhase == .active { startup.retry() }
            deps?.locationSession.handleScenePhaseChange(newPhase)
            
            switch newPhase {
            case .background:
                Task {
                    let scheduler = BackgroundScheduler(refreshId: Dependencies.liveAppRefreshID)
                    logger.notice("App entered background; ensuring background refresh is seeded if needed")
                    _ = await scheduler.ensureScheduled(using: RefreshPolicy())
                }
            case .inactive: // Swallow inactive state
                break
            case .active:
                Task(priority: .utility) {
                    let installationId = await InstallationIdentityStore.shared.installationId()
                    logger.debug("Installation ID ready with \(installationId.count, privacy: .public) chars")
                    await RemoteNotificationRegistrar.shared.registerForRemoteNotificationsIfAuthorized(context: "scene-active")
                    await deps?.locationSession.drainPendingLocationUploads()
                }
                
                // If its our first run, spin off a task to set up a background task
                // so we always have one
                if !didBootstrapBGRefresh {
                    didBootstrapBGRefresh = true
                    
                    // Schedule a background task greedy, so we start on the right foot
                    Task(priority: .background) {
                        logger.notice("Seeding initial background task")
                        let scheduler = BackgroundScheduler(refreshId: Dependencies.liveAppRefreshID)
                        let outcome = await scheduler.ensureScheduled(using: RefreshPolicy())
                        if outcome.preservesSuccessor {
                            logger.notice("Initial background refresh scheduling preserved a successor")
                        } else {
                            logger.error("Initial background refresh scheduling failed: \(String(describing: outcome), privacy: .public)")
                        }
                    }
                }
                
                // Opportunistically fetch and cleanup when activating the app to get us the
                // latest data.
                // Going to rely on the summary view to get most of the data since its the heart
                // of the app and what gets accessed first.
                // Gate cleanup so activation does not repeatedly contend with foreground refresh.
                if onboardingComplete {
                    scheduleActivationCleanupIfNeeded()
                }
            @unknown default:
                logger.warning("Phase transition error. Unknown phase")
                break
            }
        }
    }
}

enum BackgroundRefreshExecution {
    enum AdmissionOutcome: Equatable {
        case lifecycleExecuted
        case blocked(reason: String, scheduling: BackgroundScheduler.SchedulingOutcome)
    }

    @discardableResult
    static func run(
        attemptID: String = UUID().uuidString,
        allowsBackgroundPersistence: @Sendable () async -> Bool,
        scheduleFallback: @Sendable () async -> BackgroundScheduler.SchedulingOutcome,
        runPersistentLifecycle: @Sendable () async -> Void
    ) async -> AdmissionOutcome {
        guard await allowsBackgroundPersistence() else {
            return await reject(attemptID: attemptID, reason: "nonpersistent-storage", scheduleFallback: scheduleFallback)
        }
        await runPersistentLifecycle()
        return .lifecycleExecuted
    }

    @discardableResult
    static func reject(
        attemptID: String,
        reason: String,
        scheduleFallback: @Sendable () async -> BackgroundScheduler.SchedulingOutcome
    ) async -> AdmissionOutcome {
        // Emit rejection before awaiting the scheduler so an interrupted attempt remains visible.
        Logger.appMain.error("Background refresh blocked attempt=\(attemptID, privacy: .public) reason=\(reason, privacy: .public)")
        let outcome = await scheduleFallback()
        if outcome.preservesSuccessor {
            Logger.appMain.notice("Blocked refresh successor attempt=\(attemptID, privacy: .public) outcome=\(String(describing: outcome), privacy: .public)")
        } else {
            Logger.appMain.error("Blocked refresh successor attempt=\(attemptID, privacy: .public) outcome=\(String(describing: outcome), privacy: .public)")
        }
        return .blocked(reason: reason, scheduling: outcome)
    }
}

private extension SkyAwareApp {
    @ViewBuilder
    var rootContent: some View {
        if let deps {
            Group {
                if onboardingComplete {
                    homeContent(deps: deps)
                } else {
                    onboardingContent(deps: deps)
                }
            }
            .modelContainer(deps.modelContainer)
            .onAppear {
                guard isUITestStaticHome == false else { return }
                deps.locationSession.handleScenePhaseChange(scenePhase)
                if scenePhase == .active {
                    Task { await deps.locationSession.drainPendingLocationUploads() }
                    if onboardingComplete { scheduleActivationCleanupIfNeeded() }
                }
            }
        } else {
            ContentUnavailableView {
                Label("Unable to open SkyAware", systemImage: "exclamationmark.circle")
            } description: {
                Text(startup.status == .waitingForProtectedData
                     ? "Unlock your device to try again."
                     : "Your saved data is temporarily unavailable. Please try again.")
            } actions: {
                Button("Try Again") { startup.retry() }
                    .accessibilityIdentifier("startup-retry")
            }
            .appBackground()
        }
    }

    func homeContent(deps: Dependencies) -> some View {
        currentHomeView
            .environment(\.dependencies, deps)
            .environment(deps.locationSession)
            .appBackground()
            .onAppear(perform: handleHomeOnAppear)
            .sheet(item: $launchPresentation, content: launchPresentationSheet)
    }

    @ViewBuilder
    var currentHomeView: some View {
        if isUITestNoCacheResolving {
            HomeView()
        } else if isUITestStaticHome {
            if let fixture = Self.uiTestStormSetupFixture {
                HomeView(
                    initialStormRisk: fixture.stormRisk,
                    initialStormSetup: fixture.stormSetup,
                    initialStormSetupCurrentResponse: fixture.currentResponse,
                    initialStormSetupRefreshKey: fixture.context.refreshKey,
                    initialMesos: Self.uiTestLaunchMesos,
                    initialAlerts: Self.uiTestLaunchWatches,
                    initialRefreshInFlight: fixture.isRefreshInFlight
                )
            } else {
                HomeView(
                    initialMesos: Self.uiTestLaunchMesos,
                    initialAlerts: Self.uiTestLaunchWatches
                )
            }
        } else {
            HomeView()
        }
    }

    func onboardingContent(deps: Dependencies) -> some View {
        OnboardingView()
            .environment(\.dependencies, deps)
            .environment(deps.locationSession)
    }

    func handleHomeOnAppear() {
        updateLaunchPresentation()
        startup.markHomePresented()
        SkyAwareAppDelegate.resumePendingNotificationOpen()
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
                    deps?.locationSession.requestInteractiveAuthorization()
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
        guard let locationSession = deps?.locationSession else { return }
        launchPresentation = LaunchPresentationState.resolve(
            disclaimerVersion: disclaimerVersion,
            currentDisclaimerVersion: currentDisclaimerVersion,
            authorizationStatus: locationSession.authorizationStatus,
            suppressLocationRestrictedSheet: ProcessInfo.processInfo.environment["UI_TESTS_SUPPRESS_LOCATION_RESTRICTED_SHEET"] == "1"
        )
    }

    static let activationCleanupMinimumInterval: TimeInterval = 60 * 60

    func scheduleActivationCleanupIfNeeded(now: Date = .now) {
        guard let deps else { return }
        guard ActivationCleanupThrottle.shouldRun(
            lastRunAt: activationCleanupLastRunAt,
            now: now
        ) else {
            logger.debug("Skipping activation cleanup; last run was within the minimum interval")
            return
        }

        activationCleanupLastRunAt = now.timeIntervalSinceReferenceDate

        Task(priority: .utility) {
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

        applyUITestBooleanOverride(
            env["UI_TESTS_STORM_SETUP_ENABLED"],
            forKey: "stormSetupEnabled",
            in: sharedDefaults
        )
        applyUITestBooleanOverride(
            env["UI_TESTS_DETAILED_INGREDIENTS_ENABLED"],
            forKey: "detailedIngredientsEnabled",
            in: sharedDefaults
        )
#if DEBUG
        applyUITestBooleanOverride(
            env["UI_TESTS_STORM_SETUP_FORCE_DISPLAY"],
            forKey: "stormSetupForceDisplay",
            in: sharedDefaults
        )
#endif
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

    @MainActor
    static func applyUITestStormSetupFixtureIfNeeded(locationSession: LocationSession) {
        guard let fixture = uiTestStormSetupFixture else { return }
        guard locationSession.authorizationStatus.isLocationAuthorized else { return }

        locationSession.currentSnapshot = fixture.context.snapshot
        locationSession.currentContext = fixture.context
        locationSession.startupState = .ready
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

    static var uiTestLaunchWatches: [AlertDTO] {
        ProcessInfo.processInfo.environment["UI_TESTS_EMPTY_ALERTS"] == "1" ? [] : uiTestSeedWatches
    }

    static var uiTestLaunchMesos: [MdDTO] {
        ProcessInfo.processInfo.environment["UI_TESTS_EMPTY_ALERTS"] == "1" ? [] : uiTestSeedMesos
    }

    static var uiTestPreferredColorScheme: ColorScheme? {
        guard ProcessInfo.processInfo.environment["UI_TESTS_STATIC_HOME"] == "1" else {
            return nil
        }

        switch ProcessInfo.processInfo.environment["UI_TESTS_COLOR_SCHEME"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "dark":
            return .dark
        case "light":
            return .light
        default:
            return nil
        }
    }

    private static var uiTestStormSetupFixture: UITestStormSetupFixture? {
        guard ProcessInfo.processInfo.environment["UI_TESTS_STATIC_HOME"] == "1" else {
            return nil
        }

        return switch ProcessInfo.processInfo.environment["UI_TESTS_STORM_SETUP_FIXTURE"] {
        case "supportive": .supportive
        case "weak": .weak
        case "analyzing": .analyzing
        case "unavailable": .unavailable
        case "analysis-not-needed": .analysisNotNeeded
        default: nil
        }
    }

    private static func applyUITestBooleanOverride(
        _ rawValue: String?,
        forKey key: String,
        in defaults: UserDefaults
    ) {
        guard let rawValue else { return }

        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "1":
            defaults.set(true, forKey: key)
        case "0":
            defaults.set(false, forKey: key)
        default:
            break
        }
    }
}

private struct UITestStormSetupFixture {
    let context: LocationContext
    let stormSetup: StormSetupDTO?
    let profileAnalysis: AnvilAnalyzeProfileResponse?
    let stormRisk: StormRiskLevel?
    let isRefreshInFlight: Bool

    var currentResponse: StormSetupCurrentResponse? {
        stormSetup.map { $0.stormSetupCurrentResponse(profileAnalysis: profileAnalysis) }
    }

    static let supportive = UITestStormSetupFixture(
        context: .init(
            snapshot: .init(
                coordinates: .init(latitude: 39.75, longitude: -104.44),
                timestamp: uiTestDate("2026-07-03T18:00:00Z"),
                accuracy: 20,
                placemarkSummary: "Bennett, CO",
                h3Cell: 0x882681b485fffff
            ),
            h3Cell: 0x882681b485fffff,
            grid: .init(
                nwsId: "https://api.weather.gov/points/39.75,-104.44",
                latitude: 39.75,
                longitude: -104.44,
                gridId: "BOU",
                gridX: 56,
                gridY: 66,
                forecastURL: nil,
                forecastHourlyURL: nil,
                forecastGridDataURL: nil,
                observationStationsURL: nil,
                city: "Bennett",
                state: "CO",
                timeZoneId: "America/Denver",
                radarStationId: "KFTG",
                forecastZone: "COZ039",
                countyCode: "COC005",
                fireZone: "COZ246",
                countyLabel: "Arapahoe County",
                fireZoneLabel: "East Central Colorado"
            )
        ),
        stormSetup: .init(
            h3Cell: 0x882681b485fffff,
            freshness: .init(
                isStale: false,
                isDegraded: false,
                modelRunTime: uiTestDate("2026-07-03T12:00:00Z"),
                sourceValidTime: uiTestDate("2026-07-03T18:00:00Z"),
                forecastHour: 6,
                fetchedAt: uiTestDate("2026-07-03T18:04:00Z"),
                expiresAt: .distantFuture
            ),
            source: .init(
                model: "HRRR",
                product: "Storm Setup",
                domain: "severe",
                fieldSetVersion: "1",
                sourceKind: "production",
                runTime: uiTestDate("2026-07-03T12:00:00Z"),
                validTime: uiTestDate("2026-07-03T18:00:00Z"),
                forecastHour: 6,
                bbox: .init(toplat: 41.5, leftlon: -104.3, rightlon: -96.2, bottomlat: 36.8),
                primaryDownloadURL: "https://example.invalid/storm-setup"
            ),
            raw: .init(
                mlcapeJkg: 1825,
                mucapeJkg: 2210,
                sbcapeJkg: 1680,
                mlcinJkg: -38,
                srh01kmM2s2: 142,
                srh03kmM2s2: 198,
                shear06kmKt: 44,
                mllclM: 965,
                tempDewPtDeltaF: 4.5,
                threeCapeJkg: 101
            ),
            assessment: .init(
                overall: "supportive",
                summary: "The setup is supportive with several ingredients lining up for a short-term severe-weather threat.",
                instability: "supportive",
                moisture: "supportive",
                lowLevelRotation: "supportive",
                deepShear: "strong",
                cloudBase: "supportive",
                capInhibition: "weak",
                limitingFactors: ["Capping may slow initiation"],
                confidence: "high",
                primaryDrivers: ["deep shear", "low-level rotation", "moisture"],
                stormMode: "supportive",
                stormModeHint: "supportive",
                trend: "conditional",
                compositeSignal: "supportive"
            ),
            anvilEvidence: .init(
                status: "available",
                scp: .init(support: "supportive"),
                stp: .init(support: "strong"),
                ship: .init(support: "conditional"),
                diagnostics: .init(
                    hasEffectiveLayer: true,
                    hasStormMotion: true,
                    qualityProfileLevelCount: 12,
                    warnings: ["pressure-level diagnostics trimmed"]
                )
            ),
            centroid: .init(latitude: 39.6, longitude: -104.0),
            surfaceHeightMslM: 1600
        ),
        profileAnalysis: Self.makeProfileAnalysisResponse(),
        stormRisk: .marginal,
        isRefreshInFlight: false
    )

    static var weak: UITestStormSetupFixture {
        let setup = supportive.stormSetup!
        return .init(
            context: supportive.context,
            stormSetup: .init(
                h3Cell: setup.h3Cell,
                freshness: setup.freshness,
                source: setup.source,
                raw: setup.raw,
                assessment: .init(
                    overall: "weak",
                    summary: "The setup has limited support for a notable severe-weather threat.",
                    instability: setup.assessment.instability,
                    moisture: setup.assessment.moisture,
                    lowLevelRotation: setup.assessment.lowLevelRotation,
                    deepShear: setup.assessment.deepShear,
                    cloudBase: setup.assessment.cloudBase,
                    capInhibition: setup.assessment.capInhibition,
                    limitingFactors: setup.assessment.limitingFactors,
                    confidence: setup.assessment.confidence,
                    primaryDrivers: setup.assessment.primaryDrivers,
                    stormMode: setup.assessment.stormMode,
                    stormModeHint: setup.assessment.stormModeHint,
                    trend: setup.assessment.trend,
                    compositeSignal: setup.assessment.compositeSignal
                ),
                anvilEvidence: setup.anvilEvidence,
                centroid: setup.centroid,
                surfaceHeightMslM: setup.surfaceHeightMslM
            ),
            profileAnalysis: nil,
            stormRisk: .marginal,
            isRefreshInFlight: false
        )
    }

    static let analyzing = UITestStormSetupFixture(
        context: supportive.context,
        stormSetup: nil,
        profileAnalysis: nil,
        stormRisk: .marginal,
        isRefreshInFlight: true
    )

    static let unavailable = UITestStormSetupFixture(
        context: supportive.context,
        stormSetup: nil,
        profileAnalysis: nil,
        stormRisk: .marginal,
        isRefreshInFlight: false
    )

    static let analysisNotNeeded = UITestStormSetupFixture(
        context: supportive.context,
        stormSetup: nil,
        profileAnalysis: nil,
        stormRisk: nil,
        isRefreshInFlight: false
    )

    private static func makeProfileAnalysisResponse() -> AnvilAnalyzeProfileResponse {
        AnvilAnalyzeProfileResponse(
            effectiveLayer: .init(
                status: "found",
                basePressureMb: 915,
                topPressureMb: 750,
                baseMetersAgl: 850,
                topMetersAgl: 1_800
            ),
            stormMotion: .init(
                status: "available",
                bunkersRight: .init(
                    uKt: 16.3,
                    vKt: -8.2,
                    speedKt: 18.3,
                    directionTowardDeg: 215,
                    uMs: 8.4,
                    vMs: -4.2,
                    speedMs: 9.4
                )
            ),
            mucape: 2_200.5,
            mlcape: 1_850,
            mlcin: -42,
            mllclMetersAgl: 980,
            effectiveSrh: 135,
            effectiveBulkShearMs: 24.5,
            scp: 0.7,
            stpCin: 0.9,
            stpFixed: 1.2,
            ship: 2.1,
            srh01km: nil,
            srh03km: nil,
            sbcape: nil,
            sbcin: nil,
            bulkShear06kmMs: nil,
            lapserate03km: nil,
            threeCapeJkg: nil,
            quality: .init(
                profileLevelCount: 36,
                warnings: ["pressure-level diagnostics trimmed"]
            )
        )
    }
}

private extension StormSetupDTO {
    func stormSetupCurrentResponse(profileAnalysis: AnvilAnalyzeProfileResponse?) -> StormSetupCurrentResponse {
        .init(
            setup: .init(
                h3Cell: h3Cell,
                centroid: .init(latitude: centroid?.latitude ?? 0, longitude: centroid?.longitude ?? 0),
                source: .init(
                    model: .hrrr,
                    product: .wrfsfc,
                    domain: .conus,
                    runTime: freshness.modelRunTime,
                    forecastHour: freshness.forecastHour,
                    validTime: freshness.sourceValidTime,
                    fieldSetVersion: .tornadoV1,
                    bbox: source.bbox.map {
                        .init(
                            leftlon: $0.leftlon,
                            rightlon: $0.rightlon,
                            toplat: $0.toplat,
                            bottomlat: $0.bottomlat
                        )
                    },
                    primaryDownloadURL: URL(string: source.primaryDownloadURL ?? "https://example.invalid/storm-setup"),
                    idxURL: nil
                ),
                surfaceHeightMslM: surfaceHeightMslM,
                freshness: .init(
                    sourceValidTime: freshness.sourceValidTime,
                    modelRunTime: freshness.modelRunTime,
                    forecastHour: freshness.forecastHour,
                    fetchedAt: freshness.fetchedAt,
                    expiresAt: freshness.expiresAt,
                    isStale: freshness.isStale,
                    isDegraded: freshness.isDegraded
                )
            ),
            ingredients: .init(
                canonical: .init(
                    sbcapeJkg: raw.sbcapeJkg,
                    mlcapeJkg: raw.mlcapeJkg,
                    mucapeJkg: raw.mucapeJkg,
                    mlcinJkg: raw.mlcinJkg,
                    dcapeJkg: nil,
                    mllclM: raw.mllclM,
                    tempDewPtDeltaF: raw.tempDewPtDeltaF,
                    threeCapeJkg: raw.threeCapeJkg,
                    lclLfcSeparationM: nil,
                    lapseRate03kmCkm: nil,
                    lapseRate700500mbCkm: nil,
                    shear06kmKt: raw.shear06kmKt,
                    shear03kmKt: nil,
                    shear01kmKt: nil,
                    effectiveShearKt: nil,
                    srh01kmM2s2: raw.srh01kmM2s2,
                    srh03kmM2s2: raw.srh03kmM2s2,
                    effectiveSrhM2s2: nil,
                    supercellComposite: nil,
                    significantTornadoFixed: nil,
                    significantTornadoEffective: nil,
                    significantHail: nil,
                    bunkersRightMotion: nil,
                    bunkersLeftMotion: nil,
                    stormRelativeWind46km: nil,
                    meanWind850300mb: nil,
                    diagnostics: nil,
                    effectiveBulkShearMs: nil,
                    effectiveLayer: nil,
                    stormMotion: nil
                ),
                diagnostics: .empty
            ),
            profileAnalysis: profileAnalysis,
            tornadoViability: .init(
                overall: assessment.overall?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "weak"
                    ? .weak
                    : .supportive,
                realization: .realized,
                primaryFailureMode: .none,
                confidence: .moderate,
                summary: assessment.summary ?? "",
                details: .init(
                    stormViability: .supportive,
                    supercellViability: .strong,
                    tornadoEfficiency: .supportive,
                    inhibition: .weak,
                    instability: .supportive,
                    moisture: .supportive,
                    cloudBase: .weak,
                    deepShear: .strong,
                    lowLevelRotation: .conditional,
                    lowLevelStretching: .supportive,
                    cloudBaseEfficiency: .supportive,
                    supercellComposite: .strong,
                    tornadoComposite: .supportive,
                    stormMode: .supportive
                ),
                limitingFactors: [.strongCap]
            )
        )
    }
}

private func uiTestDate(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)!
}

enum ActivationCleanupThrottle {
    static let minimumInterval: TimeInterval = 60 * 60

    static func shouldRun(lastRunAt: Double, now: Date) -> Bool {
        guard lastRunAt > 0 else { return true }
        let lastRun = Date(timeIntervalSinceReferenceDate: lastRunAt)
        return now.timeIntervalSince(lastRun) >= minimumInterval
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
