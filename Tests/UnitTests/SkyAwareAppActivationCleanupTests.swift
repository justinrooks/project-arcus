import Foundation
import Testing
@testable import SkyAware

@Suite("SkyAware App Activation Cleanup")
struct SkyAwareAppActivationCleanupTests {
    @Test("shouldRunActivationCleanup_enforcesHourlyThrottle")
    func shouldRunActivationCleanupEnforcesHourlyThrottle() {
        let now = Date(timeIntervalSinceReferenceDate: 2_000_000)
        let minimumInterval = ActivationCleanupThrottle.minimumInterval

        #expect(ActivationCleanupThrottle.shouldRun(lastRunAt: 0, now: now))
        #expect(
            ActivationCleanupThrottle.shouldRun(
                lastRunAt: now.timeIntervalSinceReferenceDate - minimumInterval + 1,
                now: now
            ) == false
        )
        #expect(
            ActivationCleanupThrottle.shouldRun(
                lastRunAt: now.timeIntervalSinceReferenceDate - minimumInterval,
                now: now
            )
        )
    }
}
