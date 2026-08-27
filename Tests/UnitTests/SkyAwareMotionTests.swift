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

    @Test("resolving ambient effects run when motion is allowed")
    func resolvingAmbientEffectsRunWhenMotionIsAllowed() {
        #expect(LoadingView.shouldAnimateAmbientEffects(reduceMotion: false))
    }

    @Test("resolving ambient effects stop when Reduce Motion is enabled")
    func resolvingAmbientEffectsStopWhenReduceMotionIsEnabled() {
        #expect(LoadingView.shouldAnimateAmbientEffects(reduceMotion: true) == false)
    }
}
