import Testing
@testable import SkyAware

@Suite("SkyAware motion policy")
struct SkyAwareMotionTests {
    @Test("onboarding uses default animation when motion is allowed")
    func onboardingUsesDefaultAnimationWhenMotionIsAllowed() {
        #expect(SkyAwareMotion.onboardingStep(false) != nil)
    }

    @Test("onboarding disables animation when Reduce Motion is enabled")
    func onboardingDisablesAnimationWhenReduceMotionIsEnabled() {
        #expect(SkyAwareMotion.onboardingStep(true) == nil)
    }
}
