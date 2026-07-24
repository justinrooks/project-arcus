import CoreLocation
import Foundation
import Testing
@testable import SkyAware

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
