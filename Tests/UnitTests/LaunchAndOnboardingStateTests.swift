import CoreLocation
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
