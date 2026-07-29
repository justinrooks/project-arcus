import Foundation
import Testing
@testable import SkyAware

@Suite("BackgroundLocationContextReusePolicy")
struct BackgroundLocationContextReusePolicyTests {
    private let policy = BackgroundLocationContextReusePolicy()
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("recent accurate context reuses for Always and When-In-Use authorization")
    func reusesEligibleContextForAuthorizedModes() {
        for authorization in [
            BackgroundLocationContextReusePolicy.Authorization.always,
            .whenInUse
        ] {
            #expect(decide(authorization: authorization) == .reuseCachedContext)
        }
    }

    @Test("missing or invalid cache attempts fresh location only with Always authorization")
    func missingOrInvalidCacheRequiresAlwaysForFreshAttempt() {
        for cache in [
            BackgroundLocationContextReusePolicy.CacheState.missing,
            .invalid
        ] {
            #expect(decide(authorization: .always, cache: cache) == .attemptFreshLocation)
            #expect(decide(authorization: .whenInUse, cache: cache) == .skipLocationDependentWork)
        }
    }

    @Test("reuse age boundary is inclusive and context expires beyond the product privacy tolerance")
    func reuseAgeBoundary() {
        #expect(decide(age: BackgroundLocationContextReusePolicy.maximumReuseAge - 1) == .reuseCachedContext)
        #expect(decide(age: BackgroundLocationContextReusePolicy.maximumReuseAge) == .reuseCachedContext)
        #expect(decide(age: BackgroundLocationContextReusePolicy.maximumReuseAge + 1) == .attemptFreshLocation)
    }

    @Test("a delayed When-In-Use launch beyond the product privacy tolerance skips location work")
    func delayedWhenInUseLaunchBeyondPrivacyToleranceSkipsLocationWork() {
        #expect(decide(
            authorization: .whenInUse,
            age: BackgroundLocationContextReusePolicy.maximumReuseAge + 1
        ) == .skipLocationDependentWork)
    }

    @Test("When-In-Use reuses scheduled cadence contexts within the product privacy tolerance")
    func reusesEligibleContextAcrossScheduledCadences() {
        for cadenceAge in [20 * 60, 40 * 60, 60 * 60] {
            #expect(decide(authorization: .whenInUse, age: TimeInterval(cadenceAge)) == .reuseCachedContext)
        }

        #expect(decide(
            authorization: .whenInUse,
            age: BackgroundLocationContextReusePolicy.maximumReuseAge
        ) == .reuseCachedContext)
    }

    @Test("accuracy boundary is inclusive and invalid values cannot reuse")
    func accuracyBoundary() {
        #expect(decide(accuracy: BackgroundLocationContextReusePolicy.maximumHorizontalAccuracy - 0.1) == .reuseCachedContext)
        #expect(decide(accuracy: BackgroundLocationContextReusePolicy.maximumHorizontalAccuracy) == .reuseCachedContext)
        #expect(decide(accuracy: BackgroundLocationContextReusePolicy.maximumHorizontalAccuracy + 0.1) == .attemptFreshLocation)

        for accuracy in [0, -1, Double.infinity, Double.nan] {
            #expect(decide(accuracy: accuracy) == .attemptFreshLocation)
        }
    }

    @Test("movement or explicit invalidation never reuses the old context")
    func movementInvalidatesReuse() {
        for evidence in [
            BackgroundLocationContextReusePolicy.MovementEvidence.significantLocationChange,
            .explicitInvalidation
        ] {
            #expect(decide(movementEvidence: evidence) == .attemptFreshLocation)
            #expect(decide(authorization: .whenInUse, movementEvidence: evidence) == .skipLocationDependentWork)
        }
    }

    @Test("incomplete coordinates and future timestamps are ineligible")
    func invalidContextFieldsAreConservative() {
        #expect(decide(coordinatesAreValid: false) == .attemptFreshLocation)
        #expect(decide(isComplete: false) == .attemptFreshLocation)
        #expect(decide(age: -1) == .attemptFreshLocation)
    }

    @Test("unresolved and unauthorized states do not request location or reuse context")
    func unavailableAuthorizationSkipsLocationDependentWork() {
        for authorization in [
            BackgroundLocationContextReusePolicy.Authorization.denied,
            .restricted,
            .notDetermined,
            .unknown
        ] {
            #expect(decide(authorization: authorization) == .skipLocationDependentWork)
        }
    }

    @Test("fixed inputs always produce the same decision")
    func evaluationIsDeterministic() {
        let input = BackgroundLocationContextReusePolicy.Input(
            authorization: .whenInUse,
            cache: .available(context(age: 60)),
            movementEvidence: .none,
            now: now
        )

        #expect(policy.decide(input) == .reuseCachedContext)
        #expect(policy.decide(input) == .reuseCachedContext)
    }

    private func decide(
        authorization: BackgroundLocationContextReusePolicy.Authorization = .always,
        cache: BackgroundLocationContextReusePolicy.CacheState? = nil,
        age: TimeInterval = 60,
        accuracy: Double = 25,
        coordinatesAreValid: Bool = true,
        isComplete: Bool = true,
        movementEvidence: BackgroundLocationContextReusePolicy.MovementEvidence = .none
    ) -> BackgroundLocationContextReusePolicy.Decision {
        policy.decide(.init(
            authorization: authorization,
            cache: cache ?? .available(context(
                age: age,
                accuracy: accuracy,
                coordinatesAreValid: coordinatesAreValid,
                isComplete: isComplete
            )),
            movementEvidence: movementEvidence,
            now: now
        ))
    }

    private func context(
        age: TimeInterval,
        accuracy: Double = 25,
        coordinatesAreValid: Bool = true,
        isComplete: Bool = true
    ) -> BackgroundLocationContextReusePolicy.CachedContext {
        .init(
            coordinatesAreValid: coordinatesAreValid,
            timestamp: now.addingTimeInterval(-age),
            horizontalAccuracy: accuracy,
            isComplete: isComplete
        )
    }
}
