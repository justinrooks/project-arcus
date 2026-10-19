import Foundation
import Testing
@testable import SkyAware

@Suite("App Review Request Ledger", .serialized)
@MainActor
struct AppReviewRequestLedgerTests {
    private static let suiteName = "AppReviewRequestLedgerTests"
    @Test("eligibility begins at four successful manual refreshes")
    func eligibilityRequiresFourSuccessfulRefreshes() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        let ledger = AppReviewRequestLedger(userDefaults: defaults)

        for _ in 0..<3 {
            ledger.recordSuccessfulManualRefresh()
        }
        #expect(ledger.isEligible(appVersion: "1.4.0", onboardingComplete: true, hasActiveAlerts: false) == false)

        ledger.recordSuccessfulManualRefresh()
        #expect(ledger.isEligible(appVersion: "1.4.0", onboardingComplete: true, hasActiveAlerts: false))
    }

    @Test("onboarding and active alerts suppress eligibility")
    func eligibilityRespectsOnboardingAndActiveAlerts() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        let ledger = AppReviewRequestLedger(userDefaults: defaults)
        for _ in 0..<4 { ledger.recordSuccessfulManualRefresh() }

        #expect(ledger.isEligible(appVersion: "1.4.0", onboardingComplete: false, hasActiveAlerts: false) == false)
        #expect(ledger.isEligible(appVersion: "1.4.0", onboardingComplete: true, hasActiveAlerts: true) == false)
    }

    @Test("attempt is persisted once per app version")
    func attemptedVersionIsPersisted() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        let ledger = AppReviewRequestLedger(userDefaults: defaults)
        for _ in 0..<4 { ledger.recordSuccessfulManualRefresh() }

        ledger.recordAttempted(appVersion: "1.4.0")
        #expect(ledger.isEligible(appVersion: "1.4.0", onboardingComplete: true, hasActiveAlerts: false) == false)
        #expect(ledger.isEligible(appVersion: "1.5.0", onboardingComplete: true, hasActiveAlerts: false))

        let reopenedLedger = AppReviewRequestLedger(userDefaults: defaults)
        #expect(reopenedLedger.successfulManualRefreshCount == 4)
        #expect(reopenedLedger.isEligible(appVersion: "1.4.0", onboardingComplete: true, hasActiveAlerts: false) == false)
    }

    @Test("scheduled request waits two seconds then records the attempt before requesting")
    func schedule_waitsAndRecordsAttemptBeforeRequesting() async {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        let ledger = AppReviewRequestLedger(userDefaults: defaults)
        for _ in 0..<4 { ledger.recordSuccessfulManualRefresh() }
        var requested = false
        var observedDelay: Duration?

        let task = AppReviewRequestSchedule.makeTask(
            appVersion: "1.4.0",
            ledger: ledger,
            sleeper: { delay in observedDelay = delay },
            isStillEligible: {
                ledger.isEligible(appVersion: "1.4.0", onboardingComplete: true, hasActiveAlerts: false)
            },
            requestReview: {
                requested = true
                #expect(ledger.isEligible(appVersion: "1.4.0", onboardingComplete: true, hasActiveAlerts: false) == false)
            }
        )
        await task.value

        #expect(observedDelay == .seconds(2))
        #expect(requested)
    }

    @Test("scheduled request rechecks eligibility after the delay")
    func schedule_suppressesRequestWhenEligibilityChangesDuringDelay() async {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        let ledger = AppReviewRequestLedger(userDefaults: defaults)
        for _ in 0..<4 { ledger.recordSuccessfulManualRefresh() }
        var isEligible = true
        var sleeperEntered = false
        var resumeSleep: CheckedContinuation<Void, Error>?
        var requested = false

        let task = AppReviewRequestSchedule.makeTask(
            appVersion: "1.4.0",
            ledger: ledger,
            sleeper: { _ in
                sleeperEntered = true
                try await withCheckedThrowingContinuation { continuation in
                    resumeSleep = continuation
                }
            },
            isStillEligible: { isEligible },
            requestReview: { requested = true }
        )
        while !sleeperEntered { await Task.yield() }
        isEligible = false
        resumeSleep?.resume()
        await task.value

        #expect(requested == false)
        #expect(ledger.isEligible(appVersion: "1.4.0", onboardingComplete: true, hasActiveAlerts: false))
    }

    @Test("cancelling the scheduled request prevents the native action")
    func schedule_cancellationPreventsRequest() async {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        let ledger = AppReviewRequestLedger(userDefaults: defaults)
        for _ in 0..<4 { ledger.recordSuccessfulManualRefresh() }
        var sleeperEntered = false
        var resumeSleep: CheckedContinuation<Void, Error>?
        var requested = false

        let task = AppReviewRequestSchedule.makeTask(
            appVersion: "1.4.0",
            ledger: ledger,
            sleeper: { _ in
                sleeperEntered = true
                try await withCheckedThrowingContinuation { continuation in
                    resumeSleep = continuation
                }
            },
            isStillEligible: { true },
            requestReview: { requested = true }
        )
        while !sleeperEntered { await Task.yield() }
        task.cancel()
        resumeSleep?.resume()
        await task.value

        #expect(requested == false)
        #expect(ledger.isEligible(appVersion: "1.4.0", onboardingComplete: true, hasActiveAlerts: false))
    }

    private func makeDefaults() -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else {
            fatalError("Unable to create isolated defaults for AppReviewRequestLedgerTests")
        }
        return defaults
    }
}
