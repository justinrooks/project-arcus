import Foundation
import Testing
@testable import SkyAware

@Suite("ForegroundDurableContextReusePolicy")
struct ForegroundDurableContextReusePolicyTests {
    private let policy = ForegroundDurableContextReusePolicy()
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("a recent context with matching trusted H3 and grid evidence reuses immediately and refreshes behind")
    func reusesEligibleContext() {
        let decision = decide()

        #expect(decision == .reuseAndRefreshBehind)
        #expect(decision.uploadDisposition == .none)
    }

    @Test("reuse age is inclusive at the live-location freshness boundary")
    func reuseAgeBoundary() {
        #expect(decide(age: ForegroundDurableContextReusePolicy.maximumReuseAge) == .reuseAndRefreshBehind)
        #expect(decide(age: ForegroundDurableContextReusePolicy.maximumReuseAge + 0.1) == .resolveFreshLocation)
        #expect(decide(age: -1) == .resolveFreshLocation)
    }

    @Test("authorization must be unchanged since capture")
    func authorizationChangeInvalidatesReuse() {
        #expect(decide(authorization: .whenInUse, capturedAuthorization: .always) == .resolveFreshLocation)
        #expect(decide(authorization: .always, capturedAuthorization: .whenInUse) == .resolveFreshLocation)
    }

    @Test("unauthorized states do not reuse or resolve location")
    func unavailableAuthorizationSkipsLocationWork() {
        for authorization in [
            ForegroundDurableContextReusePolicy.Authorization.denied,
            .restricted,
            .notDetermined,
            .unknown
        ] {
            #expect(decide(authorization: authorization) == .skipLocationDependentWork)
        }
    }

    @Test("movement, missing evidence, and H3 or grid mismatches require fresh resolution")
    func movementAndCompatibilityInvalidateReuse() {
        for movement in [
            ForegroundDurableContextReusePolicy.MovementEvidence.significantLocationChange,
            .explicitInvalidation
        ] {
            #expect(decide(movementEvidence: movement) == .resolveFreshLocation)
        }
        #expect(policy.decide(input(currentContext: nil)) == .resolveFreshLocation)
        #expect(decide(currentH3Cell: 999) == .resolveFreshLocation)
        #expect(decide(currentGridId: "PUB") == .resolveFreshLocation)
        #expect(decide(currentGridX: 11) == .resolveFreshLocation)
    }

    @Test("a coordinate-specific NWS point URL does not invalidate matching grid-cell reuse")
    func pointURLDriftDoesNotInvalidateGridCompatibility() {
        #expect(decide(currentNwsId: "BOU/40.0000,-105.0000") == .reuseAndRefreshBehind)
    }

    @Test("current v1 durable entries always resolve fresh")
    func legacyV1CacheRejectsTheFastPath() {
        #expect(policy.decide(.init(
            authorization: .whenInUse,
            cache: .legacyV1,
            currentContext: currentContext(),
            movementEvidence: .none,
            now: now
        )) == .resolveFreshLocation)
    }

    @Test("cache H3 and grid integrity must be complete")
    func incompleteOrIncoherentCacheRequiresFreshResolution() {
        #expect(decide(snapshotH3Cell: nil) == .resolveFreshLocation)
        #expect(decide(snapshotH3Cell: 999) == .resolveFreshLocation)
        #expect(decide(isComplete: false) == .resolveFreshLocation)
        #expect(decide(gridId: "") == .resolveFreshLocation)
    }

    @Test("fresh resolution is the only path eligible to upload")
    func uploadDispositionPreservesReuseTimestamp() {
        #expect(decide(age: ForegroundDurableContextReusePolicy.maximumReuseAge + 1).uploadDisposition
            == .afterFreshResolutionPreservingCaptureTime)
        #expect(decide(authorization: .denied).uploadDisposition == .none)
    }

    @Test("fixed input remains deterministic")
    func fixedInputIsDeterministic() {
        let input = input(currentContext: currentContext())
        #expect(policy.decide(input) == .reuseAndRefreshBehind)
        #expect(policy.decide(input) == .reuseAndRefreshBehind)
    }

    private func decide(
        authorization: ForegroundDurableContextReusePolicy.Authorization = .whenInUse,
        capturedAuthorization: ForegroundDurableContextReusePolicy.Authorization? = nil,
        age: TimeInterval = 1,
        snapshotH3Cell: Int64? = 123_456,
        isComplete: Bool = true,
        gridId: String = "BOU",
        currentContext: ForegroundDurableContextReusePolicy.CurrentContextEvidence? = nil,
        currentH3Cell: Int64 = 123_456,
        currentGridId: String = "BOU",
        currentGridX: Int = 10,
        currentNwsId: String = "BOU/10,20",
        movementEvidence: ForegroundDurableContextReusePolicy.MovementEvidence = .none
    ) -> ForegroundDurableContextReusePolicy.Decision {
        policy.decide(input(
            authorization: authorization,
            capturedAuthorization: capturedAuthorization ?? authorization,
            age: age,
            snapshotH3Cell: snapshotH3Cell,
            isComplete: isComplete,
            gridId: gridId,
            currentContext: currentContext ?? self.currentContext(
                h3Cell: currentH3Cell,
                gridId: currentGridId,
                gridX: currentGridX,
                nwsId: currentNwsId
            ),
            movementEvidence: movementEvidence
        ))
    }

    private func input(
        authorization: ForegroundDurableContextReusePolicy.Authorization = .whenInUse,
        capturedAuthorization: ForegroundDurableContextReusePolicy.Authorization = .whenInUse,
        age: TimeInterval = 1,
        snapshotH3Cell: Int64? = 123_456,
        isComplete: Bool = true,
        gridId: String = "BOU",
        currentContext: ForegroundDurableContextReusePolicy.CurrentContextEvidence? = nil,
        movementEvidence: ForegroundDurableContextReusePolicy.MovementEvidence = .none
    ) -> ForegroundDurableContextReusePolicy.Input {
        .init(
            authorization: authorization,
            cache: .available(.init(
                capturedAt: now.addingTimeInterval(-age),
                authorizationAtCapture: capturedAuthorization,
                snapshotH3Cell: snapshotH3Cell,
                contextH3Cell: 123_456,
                grid: .init(nwsId: "BOU/10,20", gridId: gridId, gridX: 10, gridY: 20),
                isComplete: isComplete
            )),
            currentContext: currentContext,
            movementEvidence: movementEvidence,
            now: now
        )
    }

    private func currentContext(
        h3Cell: Int64 = 123_456,
        gridId: String = "BOU",
        gridX: Int = 10,
        nwsId: String = "BOU/10,20"
    ) -> ForegroundDurableContextReusePolicy.CurrentContextEvidence {
        .init(h3Cell: h3Cell, grid: .init(nwsId: nwsId, gridId: gridId, gridX: gridX, gridY: 20))
    }
}
