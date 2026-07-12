import CoreLocation
import Foundation
import OSLog
import SwiftData
import Testing
import ArcusCore
@testable import SkyAware

@MainActor
@Suite("Storm Setup Ingestion", .serialized)
struct StormSetupIngestionTests {
    @Test("disabled and quiet runs make no requests")
    func disabledAndQuietRunsMakeNoRequests() async throws {
        let cases: [(String, StormSetupPreferences, StormRiskLevel?, SevereWeatherThreat?, Bool, Bool)] = [
            ("disabled", .init(stormSetupEnabled: false, detailedIngredientsEnabled: false), .enhanced, .hail(probability: 0.30), true, true),
            ("quiet", .init(stormSetupEnabled: true, detailedIngredientsEnabled: false), .allClear, .allClear, false, false)
        ]

        for testCase in cases {
            let context = makeContext()
            let harness = try makeHarness(
                context: context,
                query: StormSetupQueryingFake(response: .success(makeStormSetupDTO(h3Cell: context.h3Cell, expiresAt: fixedNow.addingTimeInterval(3600)))),
                preferences: testCase.1,
                stormRisk: testCase.2 ?? .enhanced,
                severeRisk: testCase.3 ?? .hail(probability: 0.30),
                activeAlerts: testCase.4 ? [Watch.sampleWatchRows[0]] : [],
                activeMesos: testCase.5 ? [MD.sampleDiscussionDTOs[0]] : []
            )

            let snapshot = try await harness.executor.run(
                plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
            )

            let requestCount = await harness.query.requestCount()
            #expect(requestCount == 0, "\(testCase.0)")
            #expect(snapshot.stormSetup == nil, "\(testCase.0)")
        }
    }

    @Test("eligible triggers request exactly once in the expected HTTP mode")
    func eligibleTriggersRequestExactlyOnceInExpectedHTTPMode() async throws {
        let cases: [(String, HomeRefreshTrigger, HTTPExecutionMode)] = [
            ("bootstrap", .bootstrap, .foreground),
            ("foreground prime", .foregroundPrime, .foreground),
            ("foreground activate", .foregroundActivate, .foreground),
            ("manual refresh", .manualRefresh, .foreground),
            ("session tick", .sessionTick, .foreground),
            ("foreground location change", .foregroundLocationChange, .foreground),
            ("background refresh", .backgroundRefresh, .background),
            ("background location change", .backgroundLocationChange, .background),
            ("remote hot alert received", .remoteHotAlertReceived, .background),
            ("remote hot alert opened", .remoteHotAlertOpened, .foreground)
        ]

        for testCase in cases {
            let context = makeContext()
            let dateProvider = MutableDateProvider(fixedNow)
            let query = StormSetupQueryingFake(response: .success(makeStormSetupDTO(h3Cell: context.h3Cell, expiresAt: fixedNow.addingTimeInterval(3600))))
            let harness = try makeHarness(
                context: context,
                query: query,
                dateProvider: dateProvider
            )

            _ = try await harness.executor.run(
                plan: HomeIngestionPlan(request: .init(trigger: testCase.1))
            )

            let requestCount = await query.requestCount()
            let executionModes = await query.executionModes()
            #expect(requestCount == 1, "\(testCase.0)")
            #expect(executionModes == [testCase.2], "\(testCase.0)")
        }
    }

    @Test("fresh cache suppresses request and is returned")
    func freshCacheSuppressesRequestAndIsReturned() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let cached = makeStormSetupDTO(h3Cell: context.h3Cell, expiresAt: fixedNow.addingTimeInterval(3600))
        let harness = try makeHarness(
            context: context,
            query: StormSetupQueryingFake(response: .success(makeStormSetupDTO(h3Cell: context.h3Cell, expiresAt: fixedNow.addingTimeInterval(3600)))),
            dateProvider: dateProvider
        )

        _ = try await harness.projectionStore.updateStormSetup(
            cached.stormSetupCurrentResponse,
            for: context,
            loadedAt: fixedNow.addingTimeInterval(-120)
        )

        let snapshot = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        let requestCount = await harness.query.requestCount()
        #expect(requestCount == 0)
        #expect(snapshot.stormSetup == normalizedStormSetupDTO(cached))
        #expect(snapshot.stormSetupRefreshResult == .skipped)
        let persisted = try #require(await harness.projectionStore.projection(for: context))
        #expect(persisted.stormSetup == normalizedStormSetupDTO(cached))
        #expect(persisted.lastStormSetupLoadAt == fixedNow.addingTimeInterval(-120))
    }

    @Test("successful response is returned and persisted")
    func successfulResponseIsReturnedAndPersisted() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let dto = makeStormSetupDTO(h3Cell: context.h3Cell, expiresAt: fixedNow.addingTimeInterval(3600))
        let harness = try makeHarness(
            context: context,
            query: StormSetupQueryingFake(response: .success(dto)),
            dateProvider: dateProvider
        )

        let snapshot = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        let requestCount = await harness.query.requestCount()
        #expect(requestCount == 1)
        #expect(snapshot.stormSetup == normalizedStormSetupDTO(dto))
        #expect(snapshot.stormSetupRefreshResult == .success)
        let persisted = try #require(await harness.projectionStore.projection(for: context))
        #expect(persisted.stormSetup == normalizedStormSetupDTO(dto))
        #expect(persisted.lastStormSetupLoadAt == fixedNow)
    }

    @Test("aggregate profile present is published with the primary response")
    func aggregateProfilePresentIsPublishedWithPrimaryResponse() async throws {
        let context = makeContext()
        let base = makeStormSetupDTO(h3Cell: context.h3Cell, expiresAt: fixedNow.addingTimeInterval(3600))
        let response = StormSetupCurrentResponse(
            setup: base.stormSetupCurrentResponse.setup,
            ingredients: base.stormSetupCurrentResponse.ingredients,
            profileAnalysis: makeAggregateProfileAnalysisResponse(),
            tornadoViability: base.stormSetupCurrentResponse.tornadoViability
        )
        let harness = try makeHarness(
            context: context,
            query: StormSetupQueryingFake(response: .aggregate(response)),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false)
        )

        let snapshot = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        #expect(await harness.query.requestCount() == 1)
        #expect(snapshot.stormSetupCurrentResponse == response)
        #expect(snapshot.stormSetupCurrentResponse?.profileAnalysis != nil)
    }

    @Test("aggregate profile nil clears older profile data")
    func aggregateProfileNilClearsOlderProfileData() async throws {
        let context = makeContext()
        let cachedDTO = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: fixedNow.addingTimeInterval(-60),
            modelRunTime: fixedNow.addingTimeInterval(-7_200),
            sourceValidTime: fixedNow.addingTimeInterval(-6_840),
            fetchedAt: fixedNow.addingTimeInterval(-6_480)
        )
        let cached = StormSetupCurrentResponse(
            setup: cachedDTO.stormSetupCurrentResponse.setup,
            ingredients: cachedDTO.stormSetupCurrentResponse.ingredients,
            profileAnalysis: makeAggregateProfileAnalysisResponse(),
            tornadoViability: cachedDTO.stormSetupCurrentResponse.tornadoViability
        )
        let primary = makeStormSetupDTO(h3Cell: context.h3Cell, expiresAt: fixedNow.addingTimeInterval(3600))
        let harness = try makeHarness(
            context: context,
            query: StormSetupQueryingFake(response: .success(primary))
        )
        _ = try await harness.projectionStore.updateStormSetup(cached, for: context, loadedAt: fixedNow.addingTimeInterval(-120))

        let snapshot = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        #expect(snapshot.stormSetupCurrentResponse?.profileAnalysis == nil)
        let persisted = try #require(await harness.projectionStore.projection(for: context))
        #expect(persisted.stormSetupCurrentResponse?.profileAnalysis == nil)
    }

    @Test("older successful response does not overwrite newer cached guidance")
    func olderSuccessfulResponseDoesNotOverwriteNewerCachedGuidance() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let cached = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: fixedNow.addingTimeInterval(-30),
            modelRunTime: fixedNow.addingTimeInterval(-20),
            sourceValidTime: fixedNow.addingTimeInterval(-15),
            fetchedAt: fixedNow.addingTimeInterval(-10),
            summary: "cached guidance"
        )
        let olderReplay = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: fixedNow.addingTimeInterval(3600),
            modelRunTime: fixedNow.addingTimeInterval(-120),
            sourceValidTime: fixedNow.addingTimeInterval(-110),
            fetchedAt: fixedNow.addingTimeInterval(10),
            summary: "replayed guidance"
        )
        let harness = try makeHarness(
            context: context,
            query: StormSetupQueryingFake(response: .success(olderReplay)),
            dateProvider: dateProvider
        )

        _ = try await harness.projectionStore.updateStormSetup(
            cached.stormSetupCurrentResponse,
            for: context,
            loadedAt: fixedNow.addingTimeInterval(-600)
        )

        let snapshot = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        let requestCount = await harness.query.requestCount()
        #expect(requestCount == 1)
        #expect(snapshot.stormSetup == nil)
        #expect(snapshot.stormSetupRefreshResult == .success)
        let persisted = try #require(await harness.projectionStore.projection(for: context))
        #expect(persisted.stormSetup == normalizedStormSetupDTO(cached))
        #expect(persisted.lastStormSetupLoadAt == fixedNow.addingTimeInterval(-600))
    }

    @Test("fresh cache suppresses a failed refresh attempt and preserves timestamp")
    func freshCacheSuppressesFailedRefreshAttemptAndPreservesTimestamp() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let cached = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: fixedNow.addingTimeInterval(3600),
            summary: "cached guidance"
        )
        let harness = try makeHarness(
            context: context,
            query: StormSetupQueryingFake(response: .failure(TestError.failed)),
            dateProvider: dateProvider
        )

        _ = try await harness.projectionStore.updateStormSetup(
            cached.stormSetupCurrentResponse,
            for: context,
            loadedAt: fixedNow.addingTimeInterval(-600)
        )

        let snapshot = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        let requestCount = await harness.query.requestCount()
        #expect(requestCount == 0)
        #expect(snapshot.stormSetup == normalizedStormSetupDTO(cached))
        #expect(snapshot.stormSetupRefreshResult == .skipped)
        let persisted = try #require(await harness.projectionStore.projection(for: context))
        #expect(persisted.stormSetup == normalizedStormSetupDTO(cached))
        #expect(persisted.lastStormSetupLoadAt == fixedNow.addingTimeInterval(-600))
    }

    @Test("timeout preserves cached persistence and does not throw")
    func timeoutPreservesCachedPersistenceAndDoesNotThrow() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let cached = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: fixedNow.addingTimeInterval(-60),
            summary: "diagnostic cache"
        )
        let gate = CancellationGate()
        let query = StormSetupQueryingFake(response: .success(makeStormSetupDTO(h3Cell: context.h3Cell, expiresAt: fixedNow.addingTimeInterval(3600))), gate: gate)
        let harness = try makeHarness(
            context: context,
            query: query,
            dateProvider: dateProvider,
            stormSetupForegroundTimeout: 0.05
        )

        _ = try await harness.projectionStore.updateStormSetup(
            cached.stormSetupCurrentResponse,
            for: context,
            loadedAt: fixedNow.addingTimeInterval(-600)
        )

        let snapshot = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )
        await gate.open()

        let requestCount = await query.requestCount()
        #expect(requestCount == 1)
        #expect(snapshot.stormSetup == nil)
        #expect(snapshot.stormSetupRefreshResult == .timeout)
        let persisted = try #require(await harness.projectionStore.projection(for: context))
        #expect(persisted.stormSetup == normalizedStormSetupDTO(cached))
        #expect(persisted.lastStormSetupLoadAt == fixedNow.addingTimeInterval(-600))
    }

    @Test("cancellation preserves cached persistence and does not throw")
    func cancellationPreservesCachedPersistenceAndDoesNotThrow() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let cached = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: fixedNow.addingTimeInterval(-60),
            summary: "diagnostic cache"
        )
        let gate = CancellationGate()
        let query = StormSetupQueryingFake(response: .success(makeStormSetupDTO(h3Cell: context.h3Cell, expiresAt: fixedNow.addingTimeInterval(3600))), gate: gate)
        let harness = try makeHarness(
            context: context,
            query: query,
            dateProvider: dateProvider,
            stormSetupForegroundTimeout: 1.0
        )

        _ = try await harness.projectionStore.updateStormSetup(
            cached.stormSetupCurrentResponse,
            for: context,
            loadedAt: fixedNow.addingTimeInterval(-600)
        )

        let task = Task { @MainActor in
            try await harness.executor.run(
                plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
            )
        }

        let requestStarted = await waitUntil(timeout: 5) {
            let requestCount = await query.requestCount()
            return requestCount == 1
        }
        #expect(requestStarted)
        task.cancel()
        await gate.open()

        let snapshot = try await task.value

        #expect(snapshot.stormSetup == nil)
        #expect(snapshot.stormSetupRefreshResult == .cancelled)
        let persisted = try #require(await harness.projectionStore.projection(for: context))
        #expect(persisted.stormSetup == normalizedStormSetupDTO(cached))
        #expect(persisted.lastStormSetupLoadAt == fixedNow.addingTimeInterval(-600))
    }

    @Test("expired cache is not returned after failure")
    func expiredCacheIsNotReturnedAfterFailure() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let expired = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: fixedNow.addingTimeInterval(-60),
            summary: "expired guidance"
        )
        let harness = try makeHarness(
            context: context,
            query: StormSetupQueryingFake(response: .failure(TestError.failed)),
            dateProvider: dateProvider
        )

        _ = try await harness.projectionStore.updateStormSetup(
            expired.stormSetupCurrentResponse,
            for: context,
            loadedAt: fixedNow.addingTimeInterval(-600)
        )

        let snapshot = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        #expect(snapshot.stormSetup == nil)
        #expect(snapshot.stormSetupRefreshResult == .failure)
        let persisted = try #require(await harness.projectionStore.projection(for: context))
        #expect(persisted.stormSetup == normalizedStormSetupDTO(expired))
        #expect(persisted.lastStormSetupLoadAt == fixedNow.addingTimeInterval(-600))
    }

    @Test("mismatched response H3 is not persisted or returned")
    func mismatchedResponseH3IsNotPersistedOrReturned() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let response = makeStormSetupDTO(
            h3Cell: context.h3Cell + 1,
            expiresAt: fixedNow.addingTimeInterval(3600)
        )
        let harness = try makeHarness(
            context: context,
            query: StormSetupQueryingFake(response: .success(response)),
            dateProvider: dateProvider
        )

        let snapshot = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        #expect(snapshot.stormSetup == nil)
        #expect(snapshot.stormSetupRefreshResult == .h3Mismatch)
        let persisted = try #require(await harness.projectionStore.projection(for: context))
        #expect(persisted.stormSetup == nil)
        #expect(persisted.lastStormSetupLoadAt == nil)
    }

    @Test("failed attempt backoff suppresses a second session tick request")
    func failedAttemptBackoffSuppressesSecondSessionTickRequest() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let query = StormSetupQueryingFake(response: .failure(TestError.failed))
        let harness = try makeHarness(
            context: context,
            query: query,
            dateProvider: dateProvider,
            stormSetupFailedAttemptBackoff: 300
        )

        _ = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .sessionTick))
        )
        _ = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .sessionTick))
        )

        let requestCount = await query.requestCount()
        #expect(requestCount == 1)
    }

    @Test("foreground refresh bypasses failed-attempt backoff")
    func foregroundRefreshBypassesFailedAttemptBackoff() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let query = StormSetupQueryingFake(response: .failure(TestError.failed))
        let harness = try makeHarness(
            context: context,
            query: query,
            dateProvider: dateProvider,
            stormSetupFailedAttemptBackoff: 300
        )

        _ = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .sessionTick))
        )
        _ = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        let requestCountAfterReplay = await query.requestCount()
        #expect(requestCountAfterReplay == 2)
    }

    @Test("backoff for location A does not suppress location B")
    func backoffForLocationADoesNotSuppressLocationB() async throws {
        let locationA = makeContext(h3Cell: 111_111, timestamp: 100)
        let locationB = makeContext(
            latitude: 40.02,
            longitude: -104.87,
            h3Cell: 222_222,
            timestamp: 120
        )
        let dateProvider = MutableDateProvider(fixedNow)
        let query = StormSetupQueryingFake(response: .failure(TestError.failed))
        let harness = try makeHarness(
            context: locationA,
            query: query,
            dateProvider: dateProvider,
            stormSetupFailedAttemptBackoff: 300
        )

        harness.locationSession.currentContext = locationA
        harness.locationSession.preparedContext = locationA
        _ = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        harness.locationSession.currentContext = locationB
        harness.locationSession.preparedContext = locationB
        await query.setResponse(.success(makeStormSetupDTO(h3Cell: locationB.h3Cell, expiresAt: fixedNow.addingTimeInterval(3600))))

        _ = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        let requestCountAfterSessionTick = await query.requestCount()
        #expect(requestCountAfterSessionTick == 2)
    }

    @Test("successful refresh clears the failed-attempt condition")
    func successfulRefreshClearsTheFailedAttemptCondition() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let query = StormSetupQueryingFake(response: .failure(TestError.failed))
        let harness = try makeHarness(
            context: context,
            query: query,
            dateProvider: dateProvider,
            stormSetupFailedAttemptBackoff: 300
        )

        _ = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        dateProvider.date = fixedNow.addingTimeInterval(601)
        await query.setResponse(.success(makeStormSetupDTO(h3Cell: context.h3Cell, expiresAt: dateProvider.date.addingTimeInterval(-60))))

        _ = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        _ = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        let requestCount = await query.requestCount()
        #expect(requestCount == 3)
    }

    @Test("stale replay preserves failed-attempt backoff")
    func staleReplayPreservesFailedAttemptBackoff() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let cached = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: fixedNow.addingTimeInterval(-60),
            modelRunTime: fixedNow.addingTimeInterval(-300),
            sourceValidTime: fixedNow.addingTimeInterval(-300),
            fetchedAt: fixedNow.addingTimeInterval(-300),
            summary: "cached guidance"
        )
        let staleResponse = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: fixedNow.addingTimeInterval(3600)
        )
        let query = StormSetupQueryingFake(response: .failure(TestError.failed))
        let harness = try makeHarness(
            context: context,
            query: query,
            dateProvider: dateProvider,
            stormSetupFailedAttemptBackoff: 300
        )

        _ = try await harness.projectionStore.updateStormSetup(
            cached.stormSetupCurrentResponse,
            for: context,
            loadedAt: fixedNow.addingTimeInterval(-600)
        )

        _ = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .sessionTick))
        )

        await query.setResponse(.success(staleResponse))

        let staleSnapshot = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        #expect(staleSnapshot.stormSetupRefreshResult == .success)
        #expect(staleSnapshot.stormSetup == nil)
        let requestCountAfterReplay = await query.requestCount()
        #expect(requestCountAfterReplay == 2)

        _ = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .sessionTick))
        )

        let requestCountAfterSessionTick = await query.requestCount()
        #expect(requestCountAfterSessionTick == 2)
    }

    @Test("suspended request leaves persistence unchanged while in flight")
    func suspendedRequestLeavesPersistenceUnchangedWhileInFlight() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let cached = makeStormSetupDTO(
            h3Cell: context.h3Cell,
            expiresAt: fixedNow.addingTimeInterval(-60),
            summary: "diagnostic cache"
        )
        let gate = CancellationGate()
        let query = StormSetupQueryingFake(response: .success(makeStormSetupDTO(h3Cell: context.h3Cell, expiresAt: fixedNow.addingTimeInterval(3600))), gate: gate)
        let harness = try makeHarness(
            context: context,
            query: query,
            dateProvider: dateProvider,
            stormSetupForegroundTimeout: 1.0
        )

        _ = try await harness.projectionStore.updateStormSetup(
            cached.stormSetupCurrentResponse,
            for: context,
            loadedAt: fixedNow.addingTimeInterval(-600)
        )

        let task = Task { @MainActor in
            try await harness.executor.run(
                plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
            )
        }

        let requestStarted = await waitUntil(timeout: 5) {
            let requestCount = await query.requestCount()
            return requestCount == 1
        }
        #expect(requestStarted)

        let inFlightProjection = try #require(await harness.projectionStore.projection(for: context))
        #expect(inFlightProjection.stormSetup == normalizedStormSetupDTO(cached))
        #expect(inFlightProjection.lastStormSetupLoadAt == fixedNow.addingTimeInterval(-600))

        await gate.open()
        _ = try await task.value
    }

    @Test("storm setup failure does not block weather, risks, alerts, or mesos")
    func stormSetupFailureDoesNotBlockWeatherRisksAlertsOrMesos() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let weather = FakeWeatherClient(result: .success(sampleWeather()))
        let query = StormSetupQueryingFake(response: .failure(TestError.failed))
        let harness = try makeHarness(
            context: context,
            query: query,
            weather: weather,
            dateProvider: dateProvider
        )

        let snapshot = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )

        #expect(snapshot.weather != nil)
        #expect(snapshot.stormRisk == .enhanced)
        #expect(snapshot.severeRisk == .hail(probability: 0.30))
        #expect(snapshot.fireRisk == .elevated)
        #expect(snapshot.alerts == [Watch.sampleWatchRows[0]])
        #expect(snapshot.mesos.isEmpty == false)
        #expect(snapshot.stormSetup == nil)
        #expect(snapshot.stormSetupRefreshResult == .failure)
        let callCount = await weather.callCount()
        #expect(callCount == 1)
    }

    @Test("storm setup timeout does not block weather, risks, alerts, or mesos")
    func stormSetupTimeoutDoesNotBlockWeatherRisksAlertsOrMesos() async throws {
        let context = makeContext()
        let dateProvider = MutableDateProvider(fixedNow)
        let gate = CancellationGate()
        let weather = FakeWeatherClient(result: .success(sampleWeather()))
        let query = StormSetupQueryingFake(response: .success(makeStormSetupDTO(h3Cell: context.h3Cell, expiresAt: fixedNow.addingTimeInterval(3600))), gate: gate)
        let harness = try makeHarness(
            context: context,
            query: query,
            weather: weather,
            dateProvider: dateProvider,
            stormSetupForegroundTimeout: 0.05
        )

        let snapshot = try await harness.executor.run(
            plan: HomeIngestionPlan(request: .init(trigger: .foregroundActivate))
        )
        await gate.open()

        #expect(snapshot.weather != nil)
        #expect(snapshot.stormRisk == .enhanced)
        #expect(snapshot.severeRisk == .hail(probability: 0.30))
        #expect(snapshot.fireRisk == .elevated)
        #expect(snapshot.alerts == [Watch.sampleWatchRows[0]])
        #expect(snapshot.mesos.isEmpty == false)
        #expect(snapshot.stormSetup == nil)
        #expect(snapshot.stormSetupRefreshResult == .timeout)
        let callCount = await weather.callCount()
        #expect(callCount == 1)
    }

    private func makeHarness(
        context: LocationContext,
        query: StormSetupQueryingFake? = nil,
        weather: FakeWeatherClient = FakeWeatherClient(result: .success(sampleWeather())),
        spc: StormSetupTestSpcProvider = StormSetupTestSpcProvider(),
        alerts: StormSetupTestArcusProvider = StormSetupTestArcusProvider(),
        locationSession: FakeLocationSession? = nil,
        preferences: StormSetupPreferences = .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
        dateProvider: MutableDateProvider = MutableDateProvider(fixedNow),
        stormRisk: StormRiskLevel = .enhanced,
        severeRisk: SevereWeatherThreat = .hail(probability: 0.30),
        activeAlerts: [AlertDTO] = [Watch.sampleWatchRows[0]],
        activeMesos: [MdDTO] = [MD.sampleDiscussionDTOs[0]],
        stormSetupForegroundTimeout: TimeInterval = 5,
        stormSetupFailedAttemptBackoff: TimeInterval = 5 * 60
    ) throws -> StormSetupHarness {
        let container = try TestStore.container(for: [HomeProjection.self])
        let projectionStore = HomeProjectionStore(modelContainer: container)
        let session = locationSession ?? FakeLocationSession(currentContext: context, preparedContext: context)
        let stormSetupSpc = StormSetupTestSpcProvider(
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            activeMesos: activeMesos
        )
        let arcusProvider = StormSetupTestArcusProvider(activeAlerts: activeAlerts)
        let stormSetupQuery = query ?? StormSetupQueryingFake(
            response: .success(makeStormSetupDTO(h3Cell: context.h3Cell, expiresAt: fixedNow.addingTimeInterval(3600)))
        )
        let preferencesReader: @Sendable () async -> StormSetupPreferences = { preferences }
        let executor = HomeIngestionExecutor(
            environment: .init(
                logger: Logger(subsystem: "SkyAwareTests", category: "StormSetupIngestionTests"),
                spcSync: stormSetupSpc,
                arcusAlertSync: arcusProvider,
                weatherClient: weather,
                locationSession: session,
                snapshotStore: HomeSnapshotStore(
                    spcRisk: stormSetupSpc,
                    spcOutlook: stormSetupSpc,
                    arcusAlerts: arcusProvider
                ),
                projectionStore: projectionStore,
                widgetSnapshotRefresher: nil,
                stormSetupQuerying: stormSetupQuery,
                stormSetupPreferencesReader: preferencesReader,
                stormSetupCurrentDate: { dateProvider.date },
                stormSetupForegroundTimeout: stormSetupForegroundTimeout,
                stormSetupFailedAttemptBackoff: stormSetupFailedAttemptBackoff
            )
        )

        return StormSetupHarness(
            executor: executor,
            projectionStore: projectionStore,
            query: stormSetupQuery,
            weather: weather,
            locationSession: session,
            dateProvider: dateProvider
        )
    }

    private func makeContext(
        latitude: Double = 39.75,
        longitude: Double = -104.44,
        h3Cell: Int64 = 123_456,
        timestamp: TimeInterval = 100
    ) -> LocationContext {
        let snapshot = LocationSnapshot(
            coordinates: .init(latitude: latitude, longitude: longitude),
            timestamp: Date(timeIntervalSince1970: timestamp),
            accuracy: 25,
            placemarkSummary: "Bennett, CO",
            h3Cell: h3Cell
        )
        let grid = GridPointSnapshot(
            nwsId: "BOU/10,20",
            latitude: snapshot.coordinates.latitude,
            longitude: snapshot.coordinates.longitude,
            gridId: "BOU",
            gridX: 10,
            gridY: 20,
            forecastURL: nil,
            forecastHourlyURL: nil,
            forecastGridDataURL: nil,
            observationStationsURL: nil,
            city: "Bennett",
            state: "CO",
            timeZoneId: "America/Denver",
            radarStationId: nil,
            forecastZone: "COZ038",
            countyCode: "COC005",
            fireZone: "COZ214",
            countyLabel: "Arapahoe",
            fireZoneLabel: "Front Range"
        )
        return LocationContext(snapshot: snapshot, h3Cell: snapshot.h3Cell ?? 123_456, grid: grid)
    }

    private func makeStormSetupDTO(
        h3Cell: Int64,
        expiresAt: Date,
        modelRunTime: Date? = nil,
        sourceValidTime: Date? = nil,
        fetchedAt: Date? = nil,
        summary: String? = "The setup is strongly supportive."
    ) -> StormSetupDTO {
        let resolvedModelRunTime = modelRunTime ?? fixedNow.addingTimeInterval(-3600)
        let resolvedSourceValidTime = sourceValidTime ?? fixedNow
        let resolvedFetchedAt = fetchedAt ?? fixedNow

        return StormSetupDTO(
            h3Cell: h3Cell,
            freshness: .init(
                isStale: false,
                isDegraded: false,
                modelRunTime: resolvedModelRunTime,
                sourceValidTime: resolvedSourceValidTime,
                forecastHour: 3,
                fetchedAt: resolvedFetchedAt,
                expiresAt: expiresAt
            ),
            source: .init(
                model: "HRRR",
                product: "Storm Setup",
                domain: "severe",
                fieldSetVersion: "1",
                sourceKind: "production",
                runTime: resolvedModelRunTime,
                validTime: resolvedSourceValidTime,
                forecastHour: 3,
                bbox: .init(toplat: 41.5, leftlon: -104.3, rightlon: -96.2, bottomlat: 36.8),
                primaryDownloadURL: "https://example.invalid/storm-setup"
            ),
            raw: .init(
                mlcapeJkg: 1850,
                mucapeJkg: 2200.5,
                sbcapeJkg: 1700,
                mlcinJkg: -42,
                srh01kmM2s2: 125.5,
                srh03kmM2s2: 175,
                shear06kmKt: 42,
                mllclM: 980,
                tempDewPtDeltaF: 4.5,
                threeCapeJkg: 95
            ),
            assessment: .init(
                overall: "strong",
                summary: summary,
                instability: "supportive",
                moisture: "supportive",
                lowLevelRotation: "conditional",
                deepShear: "strong",
                cloudBase: "weak",
                capInhibition: "weak",
                limitingFactors: ["capping"],
                confidence: "high",
                primaryDrivers: ["instability", "shear"],
                stormMode: "supportive",
                stormModeHint: "supportive",
                trend: "conditional",
                compositeSignal: "strong"
            ),
            anvilEvidence: .init(
                status: "available",
                scp: .init(support: "supportive"),
                stp: .init(support: "conditional"),
                ship: .init(support: "weak"),
                diagnostics: .init(
                    hasEffectiveLayer: true,
                    hasStormMotion: false,
                    qualityProfileLevelCount: 3,
                    warnings: ["watch heating"]
                )
            ),
            centroid: .init(latitude: 39.5, longitude: -100.0),
            surfaceHeightMslM: 1132.4
        )
    }

}

private struct StormSetupHarness {
    let executor: HomeIngestionExecutor
    let projectionStore: HomeProjectionStore
    let query: StormSetupQueryingFake
    let weather: FakeWeatherClient
    let locationSession: FakeLocationSession
    let dateProvider: MutableDateProvider
}

private actor CancellationGate {
    private var isOpen = false

    func wait() async throws {
        while isOpen == false {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    func open() {
        isOpen = true
    }
}

private extension StormSetupDTO {
    var stormSetupCurrentResponse: StormSetupCurrentResponse {
        .init(
            setup: .init(
                h3Cell: h3Cell,
                centroid: .init(latitude: centroid?.latitude ?? 0, longitude: centroid?.longitude ?? 0),
                source: .init(
                    model: .hrrr,
                    product: .wrfsfc,
                    domain: .conus,
                    runTime: freshness.modelRunTime,
                    forecastHour: freshness.forecastHour,
                    validTime: freshness.sourceValidTime,
                    fieldSetVersion: .tornadoV1,
                    bbox: source.bbox.map {
                        .init(
                            leftlon: $0.leftlon,
                            rightlon: $0.rightlon,
                            toplat: $0.toplat,
                            bottomlat: $0.bottomlat
                        )
                    },
                    primaryDownloadURL: URL(string: source.primaryDownloadURL ?? "https://example.invalid/storm-setup"),
                    idxURL: nil
                ),
                surfaceHeightMslM: surfaceHeightMslM,
                freshness: .init(
                    sourceValidTime: freshness.sourceValidTime,
                    modelRunTime: freshness.modelRunTime,
                    forecastHour: freshness.forecastHour,
                    fetchedAt: freshness.fetchedAt,
                    expiresAt: freshness.expiresAt,
                    isStale: freshness.isStale,
                    isDegraded: freshness.isDegraded
                )
            ),
            ingredients: .init(
                canonical: .init(
                    sbcapeJkg: raw.sbcapeJkg,
                    mlcapeJkg: raw.mlcapeJkg,
                    mucapeJkg: raw.mucapeJkg,
                    mlcinJkg: raw.mlcinJkg,
                    dcapeJkg: nil,
                    mllclM: raw.mllclM,
                    tempDewPtDeltaF: raw.tempDewPtDeltaF,
                    threeCapeJkg: raw.threeCapeJkg,
                    lclLfcSeparationM: nil,
                    lapseRate03kmCkm: nil,
                    lapseRate700500mbCkm: nil,
                    shear06kmKt: raw.shear06kmKt,
                    shear03kmKt: nil,
                    shear01kmKt: nil,
                    effectiveShearKt: nil,
                    srh01kmM2s2: raw.srh01kmM2s2,
                    srh03kmM2s2: raw.srh03kmM2s2,
                    effectiveSrhM2s2: nil,
                    supercellComposite: nil,
                    significantTornadoFixed: nil,
                    significantTornadoEffective: nil,
                    significantHail: nil,
                    bunkersRightMotion: nil,
                    bunkersLeftMotion: nil,
                    stormRelativeWind46km: nil,
                    meanWind850300mb: nil,
                    diagnostics: nil,
                    effectiveBulkShearMs: nil,
                    effectiveLayer: nil,
                    stormMotion: nil
                ),
                diagnostics: .empty
            ),
            profileAnalysis: nil,
            tornadoViability: .init(
                overall: .supportive,
                realization: .realized,
                primaryFailureMode: .none,
                confidence: .moderate,
                summary: assessment.summary ?? "",
                details: .init(
                    stormViability: .supportive,
                    supercellViability: .strong,
                    tornadoEfficiency: .supportive,
                    inhibition: .weak,
                    instability: .supportive,
                    moisture: .supportive,
                    cloudBase: .weak,
                    deepShear: .strong,
                    lowLevelRotation: .conditional,
                    lowLevelStretching: .supportive,
                    cloudBaseEfficiency: .supportive,
                    supercellComposite: .strong,
                    tornadoComposite: .supportive,
                    stormMode: .supportive
                ),
                limitingFactors: [.strongCap]
            )
        )
    }
}

private func normalizedStormSetupDTO(_ dto: StormSetupDTO) -> StormSetupDTO {
    StormSetupDTO(response: dto.stormSetupCurrentResponse)
}

private actor StormSetupQueryingFake: StormSetupQuerying {
    enum Response {
        case success(StormSetupDTO)
        case aggregate(StormSetupCurrentResponse)
        case failure(Error)
    }

    private var response: Response
    private let gate: CancellationGate?
    private var requests: [QueryRecord] = []

    struct QueryRecord: Sendable, Equatable {
        let h3Cell: Int64
        let executionMode: HTTPExecutionMode
    }

    init(response: Response, gate: CancellationGate? = nil) {
        self.response = response
        self.gate = gate
    }

    func fetchCurrentStormSetup(h3Cell: Int64) async throws -> StormSetupCurrentResponse {
        requests.append(.init(h3Cell: h3Cell, executionMode: HTTPExecutionMode.current))
        if let gate {
            try await gate.wait()
        }

        switch response {
        case .success(let stormSetup):
            return stormSetup.stormSetupCurrentResponse
        case .aggregate(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func requestCount() -> Int {
        requests.count
    }

    func executionModes() -> [HTTPExecutionMode] {
        requests.map(\.executionMode)
    }

    func setResponse(_ response: Response) {
        self.response = response
    }
}

private func makeAggregateProfileAnalysisResponse() -> AnvilAnalyzeProfileResponse {
    .init(
        effectiveLayer: .init(status: "available", basePressureMb: 900, topPressureMb: 750, baseMetersAgl: 800, topMetersAgl: 1_800),
        stormMotion: .init(status: "available", bunkersRight: nil),
        mucape: 2_200,
        mlcape: 1_850,
        mlcin: -42,
        mllclMetersAgl: 980,
        effectiveSrh: 135,
        effectiveBulkShearMs: 24.5,
        scp: 0.7,
        stpCin: 0.9,
        stpFixed: 1.2,
        ship: 2.1,
        srh01km: nil,
        srh03km: nil,
        sbcape: nil,
        sbcin: nil,
        bulkShear06kmMs: nil,
        lapserate03km: nil,
        threeCapeJkg: nil,
        quality: .init(profileLevelCount: 36, warnings: [])
    )
}

private actor StormSetupTestSpcProvider: SpcSyncing, SpcRiskQuerying, SpcOutlookQuerying {
    private var syncMesoscaleCalls = 0
    private var syncMapProductsCalls = 0
    private var syncConvectiveOutlooksCalls = 0
    private var stormRiskCalls = 0
    private var severeRiskCalls = 0
    private var fireRiskCalls = 0
    private var activeMesosCalls = 0
    private var outlookCalls = 0

    private let stormRisk: StormRiskLevel
    private let severeRisk: SevereWeatherThreat
    private let fireRisk: FireRiskLevel
    private let activeMesos: [MdDTO]
    private let outlooks: [ConvectiveOutlookDTO]
    private let mapSyncOutcome: SpcMapSyncOutcome

    init(
        stormRisk: StormRiskLevel = .enhanced,
        severeRisk: SevereWeatherThreat = .hail(probability: 0.30),
        fireRisk: FireRiskLevel = .elevated,
        activeMesos: [MdDTO] = [MD.sampleDiscussionDTOs[0]],
        outlooks: [ConvectiveOutlookDTO] = [],
        mapSyncOutcome: SpcMapSyncOutcome = .accepted
    ) {
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
        self.activeMesos = activeMesos
        self.outlooks = outlooks
        self.mapSyncOutcome = mapSyncOutcome
    }

    func sync() async {}

    func syncMapProducts() async {
        syncMapProductsCalls += 1
    }

    func syncMapProductsOutcome() async -> SpcMapSyncOutcome {
        syncMapProductsCalls += 1
        return mapSyncOutcome
    }

    func syncTextProducts() async {}

    func syncConvectiveOutlooks() async {
        syncConvectiveOutlooksCalls += 1
    }

    func syncMesoscaleDiscussions() async {
        syncMesoscaleCalls += 1
    }

    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel {
        stormRiskCalls += 1
        return stormRisk
    }

    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat {
        severeRiskCalls += 1
        return severeRisk
    }

    func getActiveMesos(at time: Date, for point: CLLocationCoordinate2D) async throws -> [MdDTO] {
        activeMesosCalls += 1
        return activeMesos
    }

    func getFireRisk(for point: CLLocationCoordinate2D) async throws -> FireRiskLevel {
        fireRiskCalls += 1
        return fireRisk
    }

    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO? {
        outlookCalls += 1
        return outlooks.max(by: { $0.published < $1.published })
    }

    func getConvectiveOutlooks() async throws -> [ConvectiveOutlookDTO] {
        outlookCalls += 1
        return outlooks
    }
}

private actor StormSetupTestArcusProvider: ArcusAlertSyncing, ArcusAlertQuerying {
    private var syncCalls = 0
    private var queryCalls = 0
    private let activeAlerts: [AlertDTO]

    init(activeAlerts: [AlertDTO] = [Watch.sampleWatchRows[0]]) {
        self.activeAlerts = activeAlerts
    }

    func sync(context: LocationContext) async {
        syncCalls += 1
    }

    func syncRemoteAlert(id: String, revisionSent: Date?) async {}

    func getActiveAlerts(context: LocationContext) async throws -> [AlertDTO] {
        queryCalls += 1
        return activeAlerts
    }

    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry] {
        []
    }

    func getAlert(id: String) async throws -> AlertDTO? {
        nil
    }
}

private actor FakeWeatherClient: HomeWeatherQuerying {
    private let result: HomeWeatherRefreshResult
    private var calls = 0

    init(result: HomeWeatherRefreshResult) {
        self.result = result
    }

    func currentWeather(for location: CLLocation) async -> HomeWeatherRefreshResult {
        calls += 1
        return result
    }

    func callCount() -> Int {
        calls
    }
}

@MainActor
private final class FakeLocationSession: HomeLocationContextPreparing, HomeContextPreparing {
    var currentContext: LocationContext?
    var preparedContext: LocationContext?

    init(currentContext: LocationContext?, preparedContext: LocationContext?) {
        self.currentContext = currentContext
        self.preparedContext = preparedContext
    }

    func prepareCurrentLocationContext(
        requiresFreshLocation: Bool,
        showsAuthorizationPrompt: Bool,
        uploadSource: LocationUploadSource?,
        uploadReason: LocationUploadReason?,
        authorizationTimeout: Double,
        locationTimeout: Double,
        maximumAcceptedLocationAge: TimeInterval,
        placemarkTimeout: Double
    ) async -> LocationContext? {
        preparedContext
    }

    func currentPreparedContext() async -> LocationContext? {
        currentContext
    }
}

private final class MutableDateProvider: @unchecked Sendable {
    var date: Date

    init(_ date: Date) {
        self.date = date
    }
}

private enum TestError: Error {
    case failed
}

private let fixedNow = Date(timeIntervalSinceReferenceDate: 1_000_000)

@MainActor
private func waitUntil(
    timeout: TimeInterval,
    pollInterval: TimeInterval = 0.01,
    condition: @escaping @MainActor () async -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() {
            return true
        }
        try? await Task.sleep(for: .seconds(pollInterval))
    }
    return await condition()
}

private func sampleWeather() -> SummaryWeather {
    SummaryWeather(
        temperature: .init(value: 72, unit: .fahrenheit),
        symbolName: "sun.max.fill",
        conditionText: "Clear",
        asOf: fixedNow,
        dewPoint: .init(value: 54, unit: .fahrenheit),
        humidity: 0.45,
        windSpeed: .init(value: 15, unit: .milesPerHour),
        windGust: .init(value: 24, unit: .milesPerHour),
        windDirection: "NW",
        pressure: .init(value: 29.92, unit: .inchesOfMercury),
        pressureTrend: "steady"
    )
}
