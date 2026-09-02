import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import SkyAware

@Suite("App startup recovery")
@MainActor
struct AppStartupTests {
    @Test("storage recovery restores disk history before constructing dependencies")
    func retryRestoresDiskStoreBeforeComposingDependencies() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let schema = Schema([BgRunSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, url: root.appendingPathComponent("test.store"))
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            let context = ModelContext(container)
            context.insert(BgRunSnapshot(runId: "before-lock", startedAt: .now))
            try context.save()
        }
        var storageAvailable = false
        var compositions = 0
        var restoredContainer: ModelContainer?
        let startup = AppStartup(
            makeDependencies: {
                let result = try SkyAwarePersistentStoreBootstrap.open(
                    schema: schema,
                    configuration: configuration,
                    isProtectedDataAvailable: storageAvailable,
                    makeContainer: { schema, configuration, _ in
                        #expect(configuration.isStoredInMemoryOnly == false)
                        guard storageAvailable else { throw CocoaError(.fileReadNoPermission) }
                        return try ModelContainer(for: schema, configurations: configuration)
                    }
                )
                restoredContainer = result.container
                compositions += 1
                return .unconfigured
            },
            protectedDataAvailable: { storageAvailable }
        )

        #expect(startup.retry() == nil)
        #expect(startup.status == .waitingForProtectedData)
        #expect(compositions == 0)
        storageAvailable = true
        #expect(startup.retry() != nil)
        #expect(startup.status == .ready)
        #expect(compositions == 1)
        let container = try #require(restoredContainer)
        let runs = try ModelContext(container).fetch(FetchDescriptor<BgRunSnapshot>())
        #expect(runs.map(\.runId) == ["before-lock"])
    }

    @Test("concurrent retries and reentrant callbacks install dependencies exactly once")
    func overlappingRetriesInitializeOnce() async {
        var compositions = 0
        var readyCallbacks = 0
        var reenter: (() -> Void)?
        let expected = Dependencies.unconfigured
        let startup = AppStartup(makeDependencies: {
            compositions += 1
            reenter?()
            return expected
        }, onReady: { _ in readyCallbacks += 1 })
        reenter = { [weak startup] in startup?.retry() }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask { @MainActor in startup.retry() }
            }
        }
        #expect(startup.dependencies === expected)
        #expect(compositions == 1)
        #expect(readyCallbacks == 1)
    }

    @Test("persistent failures remain retryable and never publish a ready graph")
    func persistentFailureStaysUnavailable() {
        var attempts = 0
        let startup = AppStartup(makeDependencies: {
            attempts += 1
            throw CocoaError(.fileReadNoPermission)
        }, protectedDataAvailable: { true }, onReady: { _ in
            Issue.record("Failed startup must not install handlers")
        })
        #expect(startup.retry() == nil)
        #expect(startup.retry() == nil)
        #expect(startup.status == .unavailable)
        #expect(attempts == 2)
    }

    @Test("the latest notification open survives blocked startup and is consumed once after recovery")
    func deferredNotificationResumesOnce() {
        var storageAvailable = false
        let startup = AppStartup(makeDependencies: {
            guard storageAvailable else { throw CocoaError(.fileReadNoPermission) }
            return .unconfigured
        })
        startup.retry()
        startup.deferNotificationOpen(.init(alertID: "older"))
        startup.deferNotificationOpen(.init(alertID: "latest"))
        startup.markHomePresented()
        #expect(startup.hasPresentedHome == false)
        #expect(startup.takePendingNotificationOpen() == nil)
        storageAvailable = true
        startup.retry()
        #expect(startup.takePendingNotificationOpen() == nil)
        startup.markHomePresented()
        #expect(startup.takePendingNotificationOpen()?.alertID == "latest")
        #expect(startup.takePendingNotificationOpen() == nil)
    }
}

@Suite("Launch presentation state")
struct LaunchPresentationStateTests {
    @Test("prefers the disclaimer sheet when both launch conditions apply")
    func prefersDisclaimerWhenBothLaunchConditionsApply() {
        let presentation = LaunchPresentationState.resolve(
            disclaimerVersion: 0,
            currentDisclaimerVersion: 1,
            authorizationStatus: .restricted,
            suppressLocationRestrictedSheet: false
        )

        #expect(presentation == .disclaimerUpdate)
    }

    @Test("presents the disclaimer sheet when the accepted version is stale")
    func presentsDisclaimerWhenVersionIsStale() {
        let presentation = LaunchPresentationState.resolve(
            disclaimerVersion: 0,
            currentDisclaimerVersion: 1,
            authorizationStatus: .authorizedWhenInUse,
            suppressLocationRestrictedSheet: false
        )

        #expect(presentation == .disclaimerUpdate)
    }

    @Test("presents the restricted-location sheet when the disclaimer is current")
    func presentsRestrictedLocationWhenDisclaimerIsCurrent() {
        let presentation = LaunchPresentationState.resolve(
            disclaimerVersion: 1,
            currentDisclaimerVersion: 1,
            authorizationStatus: .restricted,
            suppressLocationRestrictedSheet: false
        )

        #expect(presentation == .locationRestricted)
    }

    @Test("suppresses the restricted-location sheet when the test flag is set")
    func suppressesRestrictedLocationWhenRequested() {
        let presentation = LaunchPresentationState.resolve(
            disclaimerVersion: 1,
            currentDisclaimerVersion: 1,
            authorizationStatus: .restricted,
            suppressLocationRestrictedSheet: true
        )

        #expect(presentation == nil)
    }

    @Test("does not present a launch sheet when neither condition applies")
    func doesNotPresentLaunchSheetWhenNothingApplies() {
        let presentation = LaunchPresentationState.resolve(
            disclaimerVersion: 1,
            currentDisclaimerVersion: 1,
            authorizationStatus: .authorizedWhenInUse,
            suppressLocationRestrictedSheet: false
        )

        #expect(presentation == nil)
    }
}

@Suite("Onboarding step progression")
struct OnboardingStepTests {
    @Test("welcome advances to disclaimer and disclaimer advances to location permission")
    func welcomeAndDisclaimerAdvanceInOrder() {
        #expect(OnboardingStep.welcome.nextStep() == .disclaimer)
        #expect(OnboardingStep.disclaimer.nextStep() == .locationPermission)
    }

    @Test("location permission advances to always when authorized and notifications otherwise")
    func locationPermissionBranchesByAuthorizationOutcome() {
        #expect(
            OnboardingStep.locationPermission.nextStep(locationAuthorizationStatus: .authorizedWhenInUse) == .alwaysUpgrade
        )
        #expect(OnboardingStep.locationPermission.nextStep() == .notificationPermission)
        #expect(
            OnboardingStep.locationPermission.nextStep(locationAuthorizationStatus: .denied) == .notificationPermission
        )
    }

    @Test("always upgrade and notification complete the flow")
    func terminalStepsCompleteTheFlow() {
        #expect(OnboardingStep.alwaysUpgrade.nextStep() == .notificationPermission)
        #expect(OnboardingStep.notificationPermission.nextStep() == nil)
    }
}

@Suite("Onboarding remote setup availability")
struct OnboardingRemoteSetupDecisionTests {
    @Test("ineligible notification authorization does not continue into remote setup")
    func ineligibleNotificationAuthorizationDoesNotContinue() {
        #expect(
            OnboardingRemoteSetupDecision.shouldContinue(
                remoteRegistrationEligible: false,
                arcusSignalPushEnabled: true
            ) == false
        )
    }

    @Test("unavailable Arcus configuration does not continue into remote setup")
    func unavailableArcusConfigurationDoesNotContinue() {
        #expect(
            OnboardingRemoteSetupDecision.shouldContinue(
                remoteRegistrationEligible: true,
                arcusSignalPushEnabled: false
            ) == false
        )
    }

    @Test("eligible authorization with Arcus configuration continues into remote setup")
    func eligibleAuthorizationWithConfigurationContinues() {
        #expect(
            OnboardingRemoteSetupDecision.shouldContinue(
                remoteRegistrationEligible: true,
                arcusSignalPushEnabled: true
            )
        )
    }
}

@Suite("Arcus signal configuration")
struct ArcusSignalConfigurationTests {
    @Test("missing configuration is unavailable")
    func missingConfigurationIsUnavailable() {
        #expect(ArcusSignalConfiguration.configuredBaseURL(rawValue: nil) == nil)
    }

    @Test("blank configuration is unavailable", arguments: ["", "   ", "\n\t"])
    func blankConfigurationIsUnavailable(rawValue: String) {
        #expect(ArcusSignalConfiguration.configuredBaseURL(rawValue: rawValue) == nil)
    }

    @Test("unexpanded build setting is unavailable")
    func unexpandedBuildSettingIsUnavailable() {
        #expect(ArcusSignalConfiguration.configuredBaseURL(rawValue: "$(ARCUS_SIGNAL_URL)") == nil)
    }

    @Test("malformed, hostless, and unsupported URLs are unavailable", arguments: [
        "not a url",
        "https:///api",
        "file:///tmp/arcus",
        "ftp://arcus.example.com"
    ])
    func invalidURLIsUnavailable(rawValue: String) {
        #expect(ArcusSignalConfiguration.configuredBaseURL(rawValue: rawValue) == nil)
    }

    @Test("HTTP and HTTPS configurations are accepted", arguments: [
        ("http://arcus.example.com", "http://arcus.example.com"),
        ("https://arcus.example.com", "https://arcus.example.com"),
        (" \n https://arcus.example.com \t", "https://arcus.example.com")
    ])
    func validURLIsAccepted(rawValue: String, expectedURL: String) {
        #expect(ArcusSignalConfiguration.configuredBaseURL(rawValue: rawValue) == URL(string: expectedURL))
    }
}
