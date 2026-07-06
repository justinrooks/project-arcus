import Foundation
import Testing
@testable import SkyAware

@Suite("Storm Setup Profile Analysis Policy")
struct StormSetupProfileAnalysisPolicyTests {
    @Test("effective detailed ingredients and cache state drive fetch eligibility")
    func fetchEligibilityRespectsEffectiveDetailedIngredientsAndCacheState() {
        let primary = makePrimary()
        let cached = makeCachedPayload()

        let cases: [(String, StormSetupPreferences, StormSetupDTO?, HomeProjectionStormSetupProfileAnalysisPayload?, Bool)] = [
            (
                "storm setup off suppresses fetch",
                .init(stormSetupEnabled: false, detailedIngredientsEnabled: false),
                primary,
                nil,
                false
            ),
            (
                "detailed ingredients off suppresses fetch",
                .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
                primary,
                nil,
                false
            ),
            (
                "effective detailed ingredients with no cache permits fetch",
                .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
                primary,
                nil,
                true
            ),
            (
                "missing primary still permits fetch",
                .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
                nil,
                nil,
                true
            ),
            (
                "usable cache suppresses fetch",
                .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
                primary,
                cached,
                false
            )
        ]

        for (label, preferences, primary, cached, expected) in cases {
            #expect(
                StormSetupProfileAnalysisPolicy.shouldFetch(
                    preferences: preferences,
                    primary: primary,
                    cachedPayload: cached,
                    now: now
                ) == expected,
                "\(label)"
            )
        }
    }

    @Test("usable cache requires exact identity and unexpired primary and payload")
    func usableCacheRequiresExactIdentityAndFreshness() {
        let primary = makePrimary()
        let usableCache = makeCachedPayload()

        let cases: [(String, StormSetupDTO?, HomeProjectionStormSetupProfileAnalysisPayload?, Bool)] = [
            ("exact identity match is usable before expiry", primary, usableCache, true),
            ("run-time mismatch is rejected", makePrimary(runTime: runTime.addingTimeInterval(60)), usableCache, false),
            ("valid-time mismatch is rejected", makePrimary(validTime: validTime.addingTimeInterval(60)), usableCache, false),
            ("forecast-hour mismatch is rejected", makePrimary(forecastHour: forecastHour + 1), usableCache, false),
            (
                "changed primary identity immediately rejects old cache",
                makePrimary(runTime: runTime.addingTimeInterval(60)),
                usableCache,
                false
            ),
            ("cached expiry in the past is rejected", primary, makeCachedPayload(expiresAt: past), false),
            ("primary expiry in the past is rejected", makePrimary(expiresAt: past), usableCache, false),
            ("exact expiry is rejected", primary, makeCachedPayload(expiresAt: now), false)
        ]

        for (label, primary, cache, expected) in cases {
            #expect(
                StormSetupProfileAnalysisPolicy.usableCachedPayload(
                    preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
                    primary: primary,
                    cachedPayload: cache,
                    now: now
                ) == (expected ? cache : nil),
                "\(label)"
            )
        }
    }

    @Test("missing primary source metadata fails closed for cache matching and persistence")
    func missingPrimarySourceMetadataFailsClosedForCacheMatchingAndPersistence() {
        let primary = makePrimary(runTime: nil, validTime: nil, forecastHour: nil)
        let dto = StormSetupProfileAnalysisDTO(
            request: .init(
                runTime: primary.source.runTime,
                validTime: primary.source.validTime,
                forecastHour: primary.source.forecastHour
            ),
            response: response
        )
        let cache = makeCachedPayload()

        #expect(
            StormSetupProfileAnalysisPolicy.makePersistedPayload(
                from: dto,
                primary: primary,
                fetchedAt: fetchedAt
            ) == nil
        )
        #expect(
            StormSetupProfileAnalysisPolicy.usableCachedPayload(
                preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
                primary: primary,
                cachedPayload: cache,
                now: now
            ) == nil
        )
    }

    @Test("incoming profile analysis rejects incomplete or mismatched request identity")
    func incomingProfileAnalysisRejectsIncompleteOrMismatchedRequestIdentity() {
        let primary = makePrimary()

        let cases: [(String, StormSetupProfileAnalysisDTO, Bool)] = [
            ("missing request identity is rejected", .init(request: nil, response: response), false),
            (
                "missing run-time is rejected",
                .init(request: .init(runTime: nil, validTime: validTime, forecastHour: forecastHour), response: response),
                false
            ),
            (
                "missing valid-time is rejected",
                .init(request: .init(runTime: runTime, validTime: nil, forecastHour: forecastHour), response: response),
                false
            ),
            (
                "missing forecast-hour is rejected",
                .init(request: .init(runTime: runTime, validTime: validTime, forecastHour: nil), response: response),
                false
            ),
            (
                "run-time mismatch is rejected",
                .init(request: .init(runTime: runTime.addingTimeInterval(60), validTime: validTime, forecastHour: forecastHour), response: response),
                false
            ),
            (
                "valid-time mismatch is rejected",
                .init(request: .init(runTime: runTime, validTime: validTime.addingTimeInterval(60), forecastHour: forecastHour), response: response),
                false
            ),
            (
                "forecast-hour mismatch is rejected",
                .init(request: .init(runTime: runTime, validTime: validTime, forecastHour: forecastHour + 1), response: response),
                false
            )
        ]

        for (label, dto, expected) in cases {
            #expect(
                StormSetupProfileAnalysisPolicy.makePersistedPayload(
                    from: dto,
                    primary: primary,
                    fetchedAt: fetchedAt
                ) == (expected ? expectedEnvelope : nil),
                "\(label)"
            )
        }
    }

    @Test("matching incoming data creates the canonical persisted envelope")
    func matchingIncomingDataCreatesTheCanonicalPersistedEnvelope() {
        let primary = makePrimary()
        let dto = StormSetupProfileAnalysisDTO(request: .init(runTime: runTime, validTime: validTime, forecastHour: forecastHour), response: response)

        let envelope = StormSetupProfileAnalysisPolicy.makePersistedPayload(
            from: dto,
            primary: primary,
            fetchedAt: fetchedAt
        )

        #expect(envelope == expectedEnvelope)
        #expect(envelope?.response == response)
        #expect(envelope?.modelRunTime == primary.source.runTime)
        #expect(envelope?.validTime == primary.source.validTime)
        #expect(envelope?.forecastHour == primary.source.forecastHour)
        #expect(envelope?.fetchedAt == fetchedAt)
        #expect(envelope?.expiresAt == primary.freshness.expiresAt)
    }

    @Test("expired primary rejects incoming data and disabled preferences do not alter stored cache")
    func expiredPrimaryRejectsIncomingDataAndDisabledPreferencesDoNotAlterStoredCache() {
        let primary = makePrimary(expiresAt: past)
        let dto = StormSetupProfileAnalysisDTO(request: .init(runTime: runTime, validTime: validTime, forecastHour: forecastHour), response: response)
        let storedCache = makeCachedPayload()

        #expect(
            StormSetupProfileAnalysisPolicy.makePersistedPayload(
                from: dto,
                primary: primary,
                fetchedAt: fetchedAt
            ) == nil
        )
        #expect(
            StormSetupProfileAnalysisPolicy.usableCachedPayload(
                preferences: .init(stormSetupEnabled: false, detailedIngredientsEnabled: true),
                primary: primary,
                cachedPayload: storedCache,
                now: now
            ) == nil
        )
        #expect(storedCache == expectedEnvelope)
    }
}

private let now = Date(timeIntervalSinceReferenceDate: 2_000_000)
private let past = now.addingTimeInterval(-1)
private let future = now.addingTimeInterval(1)
private let runTime = Date(timeIntervalSinceReferenceDate: 1_999_000)
private let validTime = Date(timeIntervalSinceReferenceDate: 1_999_180)
private let forecastHour = 3
private let fetchedAt = now.addingTimeInterval(-0.5)

private let response = StormSetupProfileAnalysisDTO.Response(
    mlcape: 1_850,
    mucape: 2_200.5,
    mlcin: -42,
    mllclMetersAgl: -0.0,
    scp: 0.7,
    stpFixed: 1.2,
    stpCin: 0.9,
    ship: 2.1,
    effectiveSrh: 135,
    effectiveBulkShearMs: 24.5,
    effectiveLayer: .init(status: "available", basePressureMb: 915, topPressureMb: 750, baseMetersAgl: 850, topMetersAgl: 1_800),
    stormMotion: .init(
        status: "available",
        bunkersRight: .init(
            uMs: 8.4,
            vMs: -4.2,
            speedMs: 9.4,
            uKt: 16.3,
            vKt: -8.2,
            speedKt: 18.3,
            directionTowardDeg: 215
        ),
        uMs: 6.2,
        vMs: -2.4,
        speedMs: 6.6,
        uKt: 12.1,
        vKt: -4.7,
        speedKt: 12.8,
        directionTowardDeg: 201
    ),
    quality: .init(profileLevelCount: 36, warnings: ["profile trimmed", "debug ignored"])
)

private let expectedEnvelope = HomeProjectionStormSetupProfileAnalysisPayload(
    response: response,
    modelRunTime: runTime,
    validTime: validTime,
    forecastHour: forecastHour,
    fetchedAt: fetchedAt,
    expiresAt: Date(timeIntervalSinceReferenceDate: 2_000_900)
)

private func makePrimary(
    runTime: Date? = runTime,
    validTime: Date? = validTime,
    forecastHour: Int? = forecastHour,
    expiresAt: Date = Date(timeIntervalSinceReferenceDate: 2_000_900)
) -> StormSetupDTO {
    StormSetupDTO(
        h3Cell: 613_160_066_540_896_255,
        freshness: .init(
            isStale: false,
            isDegraded: false,
            modelRunTime: runTime,
            sourceValidTime: validTime,
            forecastHour: forecastHour,
            fetchedAt: fetchedAt,
            expiresAt: expiresAt
        ),
        source: .init(
            model: "hrrr",
            product: "storm-setup",
            domain: "anvil",
            fieldSetVersion: "v1",
            sourceKind: "analysis",
            runTime: runTime,
            validTime: validTime,
            forecastHour: forecastHour,
            bbox: .init(toplat: 40, leftlon: -105, rightlon: -104, bottomlat: 39),
            primaryDownloadURL: nil
        ),
        raw: .init(
            mlcapeJkg: 1850,
            mucapeJkg: 2200.5,
            sbcapeJkg: nil,
            mlcinJkg: -42,
            srh01kmM2s2: 135,
            srh03kmM2s2: nil,
            shear06kmKt: 24.5,
            mllclM: -0.0,
            tempDewPtDeltaF: nil,
            threeCapeJkg: nil
        ),
        assessment: .init(
            overall: "strong",
            summary: "Strong ingredients",
            instability: nil,
            moisture: nil,
            lowLevelRotation: nil,
            deepShear: nil,
            cloudBase: nil,
            capInhibition: nil,
            limitingFactors: nil,
            confidence: nil,
            primaryDrivers: nil,
            stormMode: nil,
            stormModeHint: nil,
            trend: nil,
            compositeSignal: nil
        ),
        anvilEvidence: nil,
        centroid: nil,
        surfaceHeightMslM: 1_000
    )
}

private func makeCachedPayload(
    runTime: Date = runTime,
    validTime: Date = validTime,
    forecastHour: Int = forecastHour,
    fetchedAt: Date = fetchedAt,
    expiresAt: Date = Date(timeIntervalSinceReferenceDate: 2_000_900)
) -> HomeProjectionStormSetupProfileAnalysisPayload {
    HomeProjectionStormSetupProfileAnalysisPayload(
        response: response,
        modelRunTime: runTime,
        validTime: validTime,
        forecastHour: forecastHour,
        fetchedAt: fetchedAt,
        expiresAt: expiresAt
    )
}
