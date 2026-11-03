import Foundation
import CoreLocation
import Testing
import Synchronization
import ArcusCore
@testable import SkyAware

@Suite("LocationManager")
struct LocationManagerTests {
    fileprivate final class StubAuthorizationManager: CLLocationManager {
        var stubStatus: CLAuthorizationStatus
        var stubAccuracy: CLAccuracyAuthorization
        private(set) var requestWhenInUseCount = 0
        private(set) var requestAlwaysCount = 0
        private(set) var requestLocationCount = 0
        private(set) var significantStartCount = 0
        private(set) var significantStopCount = 0
        override func startMonitoringSignificantLocationChanges() { significantStartCount += 1 }
        override func stopMonitoringSignificantLocationChanges() { significantStopCount += 1 }

        override func requestLocation() { requestLocationCount += 1 }

        init(status: CLAuthorizationStatus, accuracy: CLAccuracyAuthorization = .fullAccuracy) {
            self.stubStatus = status
            self.stubAccuracy = accuracy
            super.init()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var authorizationStatus: CLAuthorizationStatus { stubStatus }
        override var accuracyAuthorization: CLAccuracyAuthorization { stubAccuracy }

        override func requestWhenInUseAuthorization() {
            requestWhenInUseCount += 1
        }

        override func requestAlwaysAuthorization() {
            requestAlwaysCount += 1
        }
    }

    @MainActor
    private final class ControlledStreams {
        var receivers: [@MainActor @Sendable (CLLocation) async -> Void] = []
        var completions: [CheckedContinuation<Void, any Error>?] = []
        var returned: [Int] = []
        var cancelled: [Int] = []

        func run(_ receive: @escaping @MainActor @Sendable (CLLocation) async -> Void) async throws {
            let index = receivers.count
            receivers.append(receive)
            defer {
                returned.append(index)
                if Task.isCancelled { cancelled.append(index) }
            }
            try await withCheckedThrowingContinuation { completions.append($0) }
        }

        func finish(_ index: Int, failing: Bool = false) {
            let continuation = completions[index]
            completions[index] = nil
            if failing { continuation?.resume(throwing: CLError(.locationUnknown)) }
            else { continuation?.resume() }
        }
    }

    @Test @MainActor
    func retiredStreamCannotClearReplacementOrDeliver() async throws {
        let core = StubAuthorizationManager(status: .authorizedAlways)
        let streams = ControlledStreams()
        let (deliveries, record) = AsyncStream<Void>.makeStream()
        let manager = LocationManager(
            manager: core, onUpdate: { _ in record.yield(()); return .accepted },
            foregroundUpdates: { try await streams.run($0) }
        )
        manager.updateMode(for: .active)
        try #require(await waitUntil { streams.receivers.count == 1 })
        manager.updateMode(for: .background)
        manager.updateMode(for: .active)
        try #require(await waitUntil { streams.receivers.count == 2 })
        streams.finish(0)
        try #require(await waitUntil { streams.returned.contains(0) })
        manager.updateMode(for: .active)
        #expect(streams.receivers.count == 2)
        let location = CLLocation(latitude: 39, longitude: -104)
        await streams.receivers[0](location)
        await streams.receivers[1](location)
        manager.updateMode(for: .inactive)
        await streams.receivers[1](location)
        record.finish()
        var count = 0
        for await _ in deliveries { count += 1 }
        #expect(count == 1)
        streams.finish(1)
        try #require(await waitUntil { streams.returned.contains(1) })
        #expect(streams.cancelled == [0, 1])
        manager.stopAll()
    }

    @Test(arguments: [false, true]) @MainActor
    func unexpectedTerminationWaitsForEligibleModeUpdate(failing: Bool) async throws {
        let core = StubAuthorizationManager(status: .authorizedWhenInUse)
        let streams = ControlledStreams()
        let manager = LocationManager(
            manager: core, onUpdate: { _ in .accepted },
            foregroundUpdates: { try await streams.run($0) }
        )
        manager.updateMode(for: .active)
        try #require(await waitUntil { streams.receivers.count == 1 })
        streams.finish(0, failing: failing)
        try #require(await waitUntil { streams.returned.contains(0) })
        #expect(streams.receivers.count == 1)
        manager.updateMode(for: .active)
        try #require(await waitUntil { streams.receivers.count == 2 })
        manager.updateMode(for: .active)
        #expect(streams.receivers.count == 2)
        streams.finish(1, failing: failing)
        try #require(await waitUntil { streams.returned.contains(1) })
        core.stubStatus = .denied
        manager.updateMode(for: .active)
        #expect(streams.receivers.count == 2)
        manager.stopAll()
    }

    @Test(arguments: [CLAuthorizationStatus.denied, .authorizedWhenInUse]) @MainActor
    func backgroundMonitoringRestartsAfterStopAndRespectsRevocation(revoked: CLAuthorizationStatus) {
        let core = StubAuthorizationManager(status: .authorizedAlways)
        let manager = LocationManager(manager: core, onUpdate: { _ in .accepted })
        manager.updateMode(for: .background)
        manager.stopAll()
        manager.updateMode(for: .background)
        #expect(core.significantStartCount == 2)
        core.stubStatus = revoked
        manager.updateMode(for: .inactive)
        #expect(core.significantStopCount >= 2)
        manager.updateMode(for: .background)
        #expect(core.significantStartCount == 2)
    }

    @Test(arguments: [false, true]) @MainActor
    func backgroundAdmissionCompletesBeforeDiscretionaryHandler(inactive: Bool) async throws {
        let core = StubAuthorizationManager(status: .authorizedAlways)
        let (events, record) = AsyncStream<String>.makeStream()
        let manager = LocationManager(
            manager: core,
            onUpdate: { _ in record.yield("wrong-lane"); return .rejected },
            onBackgroundUpdate: { _ in
                record.yield("presence-retained")
                return .accepted
            }
        )
        manager.setBackgroundLocationChangeHandler {
            record.yield("weather")
            record.finish()
        }
        manager.updateMode(for: .background)
        if inactive { manager.updateMode(for: .inactive) }
        manager.locationManager(core, didUpdateLocations: [
            CLLocation(latitude: 39.75, longitude: -104.99)
        ])
        var iterator = events.makeAsyncIterator()
        #expect(await iterator.next() == "presence-retained")
        #expect(await iterator.next() == "weather")
        manager.stopAll()
    }

    @Test @MainActor
    func backgroundOneShotCompletesBeforeBlockedWeather() async {
        let core = StubAuthorizationManager(status: .authorizedAlways)
        let manager = LocationManager(manager: core, onUpdate: { _ in .accepted })
        let (weatherGate, releaseWeather) = AsyncStream<Void>.makeStream()
        manager.setBackgroundLocationChangeHandler { for await _ in weatherGate { } }
        manager.updateMode(for: .background)
        let caller = Task { await manager.refreshCurrentLocation() }
        #expect(await waitUntil { core.requestLocationCount == 1 })
        manager.locationManager(core, didUpdateLocations: [CLLocation(latitude: 39, longitude: -104)])
        let accepted = await result(of: caller, sut: manager, manager: core)
        releaseWeather.finish()
        #expect(accepted)
        manager.stopAll()
    }

    @Test(arguments: [false, true]) @MainActor
    func reducedAccuracyRejectsQueuedCallbacks(background: Bool) async {
        let core = StubAuthorizationManager(status: .authorizedAlways)
        let delivered = DeliveryCounter()
        let manager = LocationManager(manager: core, onUpdate: { _ in await delivered.accept() })
        manager.updateMode(for: background ? .background : .active)
        let caller = Task { await manager.refreshCurrentLocation() }
        #expect(await waitUntil { core.requestLocationCount == 1 })
        core.stubAccuracy = .reducedAccuracy
        manager.locationManager(core, didUpdateLocations: [CLLocation(latitude: 39, longitude: -104)])
        #expect(await result(of: caller, sut: manager, manager: core) == false)
        #expect(await delivered.count == 0)
        #expect(await manager.refreshCurrentLocation() == false)
        #expect(core.requestLocationCount == 1)
        manager.stopAll()
    }

    private actor DeliveryCounter {
        var count = 0
        func accept() -> LocationAcceptance { count += 1; return .accepted }
    }

    @Test(arguments: [CLAuthorizationStatus.denied, .authorizedWhenInUse]) @MainActor
    func queuedBackgroundDeliveryRechecksAuthorization(revoked: CLAuthorizationStatus) async {
        let core = StubAuthorizationManager(status: .authorizedAlways)
        let delivered = DeliveryCounter()
        let manager = LocationManager(manager: core, onUpdate: { _ in await delivered.accept() })
        manager.updateMode(for: .background)
        let caller = Task { await manager.refreshCurrentLocation() }
        #expect(await waitUntil { core.requestLocationCount == 1 })
        // The callback was queued before the authorization-change delegate updates mode.
        core.stubStatus = revoked
        manager.updateMode(for: .background) // Monitoring is already stopped before queued delivery.
        manager.locationManager(core, didUpdateLocations: [CLLocation(latitude: 39, longitude: -104)])
        #expect(await result(of: caller, sut: manager, manager: core) == false)
        #expect(await delivered.count == 0)
        #expect(core.requestWhenInUseCount == 0 && core.requestAlwaysCount == 0)
        manager.stopAll()
    }

    fileprivate struct OfflineGeocoder: LocationGeocoding {
        func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String { "Test" }
    }

    private actor PresenceRecorder: LocationPresenceEnqueuing {
        var observations: [LocationSnapshot] = []
        var gate: CheckedContinuation<Void, Never>?
        var hold = false
        func holdAdmission() { hold = true }
        func release() { hold = false; gate?.resume(); gate = nil }
        let retained: Bool
        init(retained: Bool = true) { self.retained = retained }
        func enqueuePresence(_ observation: LocationSnapshot, source: LocationUploadSource,
                             reason: LocationUploadReason) async -> Bool {
            observations.append(observation)
            if hold { await withCheckedContinuation { gate = $0 } }
            return retained
        }
    }

    @Test(arguments: [false, true]) @MainActor
    func backgroundAdmissionRejectsCachedOlderAndDuplicateEvidence(retained: Bool) async {
        let provider = LocationProvider(geocoder: OfflineGeocoder())
        let recorder = PresenceRecorder(retained: retained)
        let now = Date.now
        func update(_ seconds: TimeInterval) -> LocationUpdate {
            .init(coordinates: .init(latitude: 39.75, longitude: -104.99),
                  timestamp: now.addingTimeInterval(seconds), accuracy: 10)
        }
        let cached = await LocationPresenceRuntime.acceptBackgroundUpdate(
            update(-3600), provider: provider, enqueuer: recorder, now: now)
        #expect(cached == .rejected)
        let accepted = await LocationPresenceRuntime.acceptBackgroundUpdate(
            update(0), provider: provider, enqueuer: recorder, now: now)
        #expect(accepted == .accepted)
        let duplicate = await LocationPresenceRuntime.acceptBackgroundUpdate(
            update(0), provider: provider, enqueuer: recorder, now: now)
        #expect(duplicate == .redundant)
        let older = await LocationPresenceRuntime.acceptBackgroundUpdate(
            update(-60), provider: provider, enqueuer: recorder, now: now)
        #expect(older == .rejected)
        #expect(await recorder.observations.count == 1)
    }

    @Test(arguments: [false, true]) @MainActor
    func processAdmissionSeparatesAcceptanceFromRetention(retained: Bool) async {
        let now = Date.now
        let provider = LocationProvider(geocoder: OfflineGeocoder(), nowProvider: { now })
        let recorder = PresenceRecorder(retained: retained)
        let admission = LocationPresenceAdmission(provider: provider, foreground: recorder,
            background: recorder, now: { now })
        let update = LocationUpdate(coordinates: .init(latitude: 39.75, longitude: -104.99),
            timestamp: now, accuracy: 10)
        await recorder.holdAdmission()
        let foreground = Task { await admission.accept(update, source: .foregroundLocationChange) }
        while await recorder.observations.isEmpty { await Task.yield() }
        let background = await admission.accept(update, source: .backgroundLocationChange)
        #expect(background.retention == .notAttempted)
        #expect(await recorder.observations.count == 1)
        await recorder.release()
        let results = [await foreground.value, background]
        #expect(results.filter { $0.acceptance == .accepted }.count == 1)
        #expect(results.filter { $0.retention == (retained ? .retained : .failed) }.count == 1)
        #expect(await recorder.observations.count == 1)
        let future = LocationUpdate(coordinates: update.coordinates, timestamp: now.addingTimeInterval(1), accuracy: 10)
        #expect(await admission.accept(future, source: .foregroundLocationChange).acceptance == .rejected)
        let invalid = LocationUpdate(coordinates: update.coordinates, timestamp: now, accuracy: -1)
        #expect(await admission.accept(invalid, source: .foregroundLocationChange).acceptance == .rejected)
        #expect(await provider.snapshot()?.timestamp == now)
    }

    @MainActor
    private func waitUntil(
        timeout: Duration = .seconds(1),
        interval: Duration = .milliseconds(10),
        _ condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(for: interval)
        }
        return condition()
    }

    @MainActor
    private final class ManualTimeouts {
        let (started, didStart) = AsyncStream<Int>.makeStream()
        private var nextID = 0
        private var deadlines: [Int: AsyncStream<Void>.Continuation] = [:]

        func sleep(_ duration: Duration) async throws {
            let id = nextID
            nextID += 1
            let (ticks, tick) = AsyncStream<Void>.makeStream()
            deadlines[id] = tick
            defer { deadlines.removeValue(forKey: id) }
            didStart.yield(id)
            for await _ in ticks { return }
            throw CancellationError()
        }

        func expire(_ id: Int) {
            deadlines[id]?.yield(())
            deadlines[id]?.finish()
        }
    }

    @MainActor
    private func result(
        of caller: Task<Bool, Never>, sut: LocationManager, manager: StubAuthorizationManager
    ) async -> Bool {
        // Failure-only watchdog: ordering below uses explicit registrations and clock ticks.
        var neededRescue = false
        let rescue = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            neededRescue = true
            sut.locationManager(manager, didFailWithError: CLError(.locationUnknown))
        }
        let value = await caller.value
        rescue.cancel()
        #expect(!neededRescue, "Caller required a later delegate callback to unwind")
        return value
    }

    @MainActor
    @Test("one-shot success requires accepted evidence", arguments: [LocationAcceptance.accepted, .redundant, .rejected])
    func oneShotWait_reflectsAcceptance(acceptance: LocationAcceptance) async throws {
        let manager = StubAuthorizationManager(status: .authorizedWhenInUse)
        let clock = ManualTimeouts()
        let sut = LocationManager(manager: manager, onUpdate: { _ in acceptance }, oneShotTimeoutSleep: clock.sleep)
        let caller = Task { await sut.refreshCurrentLocation() }
        var starts = clock.started.makeAsyncIterator()
        _ = await starts.next()
        sut.locationManager(manager, didUpdateLocations: [CLLocation(latitude: 40, longitude: -105)])
        #expect(await result(of: caller, sut: sut, manager: manager) == (acceptance == .accepted))
    }

    @MainActor
    @Test("one-shot wait exits without a delegate callback", arguments: [false, true])
    func oneShotWait_exitsWithoutCallback(cancel: Bool) async throws {
        let manager = StubAuthorizationManager(status: .authorizedWhenInUse)
        let clock = ManualTimeouts()
        let sut = LocationManager(manager: manager, onUpdate: { _ in .accepted }, oneShotTimeoutSleep: clock.sleep)
        let caller = Task { await sut.refreshCurrentLocation() }
        var starts = clock.started.makeAsyncIterator()
        let deadline = try #require(await starts.next())
        if cancel { caller.cancel() } else { clock.expire(deadline) }
        #expect(await result(of: caller, sut: sut, manager: manager) == false)
    }

    @MainActor
    @Test("cancellation before registration does not start a location request")
    func oneShotWait_cancelledBeforeRegistration() async {
        let manager = StubAuthorizationManager(status: .authorizedWhenInUse)
        let sut = LocationManager(manager: manager, onUpdate: { _ in .accepted })
        let caller = Task { await sut.refreshCurrentLocation() }
        caller.cancel() // The task cannot enter the main actor until this test suspends.
        #expect(await result(of: caller, sut: sut, manager: manager) == false)
        #expect(manager.requestLocationCount == 0)
    }

    @MainActor
    @Test("retiring one caller preserves a coalesced caller", arguments: [false, true], [false, true])
    func oneShotWait_preservesOtherCaller(cancel: Bool, delegateSuccess: Bool) async throws {
        let manager = StubAuthorizationManager(status: .authorizedWhenInUse)
        let clock = ManualTimeouts()
        let sut = LocationManager(manager: manager, onUpdate: { _ in .accepted }, oneShotTimeoutSleep: clock.sleep)
        var starts = clock.started.makeAsyncIterator()
        let first = Task { await sut.refreshCurrentLocation() }
        let firstDeadline = try #require(await starts.next())
        var secondResult: Bool?
        let second = Task {
            let value = await sut.refreshCurrentLocation()
            secondResult = value
            return value
        }
        _ = await starts.next()
        #expect(manager.requestLocationCount == 1)
        if cancel { first.cancel() } else { clock.expire(firstDeadline) }
        #expect(await result(of: first, sut: sut, manager: manager) == false)
        #expect(secondResult == nil)
        if delegateSuccess {
            sut.locationManager(manager, didUpdateLocations: [CLLocation(latitude: 40, longitude: -105)])
        } else {
            sut.locationManager(manager, didFailWithError: CLError(.locationUnknown))
        }
        #expect(await result(of: second, sut: sut, manager: manager) == delegateSuccess)
    }

    @MainActor
    @Test("acceptance racing retirement preserves independent deliveries", arguments: [false, true], [false, true])
    func oneShotWait_deliveryCapturesWaiterOwnership(cancel: Bool, laterSuccess: Bool) async throws {
        let manager = StubAuthorizationManager(status: .authorizedWhenInUse)
        let clock = ManualTimeouts()
        let (acceptances, accepting) = AsyncStream<AsyncStream<Void>.Continuation>.makeStream()
        let sut = LocationManager(manager: manager, onUpdate: { _ in
            let (releases, release) = AsyncStream<Void>.makeStream()
            accepting.yield(release)
            for await _ in releases { break }
            return .accepted
        }, oneShotTimeoutSleep: clock.sleep)
        var starts = clock.started.makeAsyncIterator()
        var deliveries = acceptances.makeAsyncIterator()
        let first = Task { await sut.refreshCurrentLocation() }
        let firstDeadline = try #require(await starts.next())
        let retained = Task { await sut.refreshCurrentLocation() }
        _ = await starts.next()
        sut.locationManager(manager, didUpdateLocations: [CLLocation(latitude: 40, longitude: -105)])
        let release = try #require(await deliveries.next())
        if cancel { first.cancel() } else { clock.expire(firstDeadline) }
        #expect(await result(of: first, sut: sut, manager: manager) == false)
        var laterResult: Bool?
        let later = Task {
            let value = await sut.refreshCurrentLocation()
            laterResult = value
            return value
        }
        _ = await starts.next()
        #expect(manager.requestLocationCount == 2)
        if laterSuccess {
            release.finish()
            #expect(await result(of: retained, sut: sut, manager: manager))
            #expect(laterResult == nil)
            sut.locationManager(manager, didUpdateLocations: [CLLocation(latitude: 41, longitude: -105)])
            let releaseLater = try #require(await deliveries.next())
            releaseLater.finish()
        } else {
            // A newer acquisition failure must not retire an earlier fix awaiting acceptance.
            sut.locationManager(manager, didFailWithError: CLError(.locationUnknown))
            #expect(await result(of: later, sut: sut, manager: manager) == false)
            release.finish()
            #expect(await result(of: retained, sut: sut, manager: manager))
        }
        #expect(await result(of: later, sut: sut, manager: manager) == laterSuccess)
    }

    @MainActor
    @Test("late callbacks and retired deadlines do not double resume; subsequent request succeeds")
    func oneShotWait_lateCallbacksAndNextRequest() async throws {
        let manager = StubAuthorizationManager(status: .authorizedWhenInUse)
        let clock = ManualTimeouts()
        let (updates, updated) = AsyncStream<Bool>.makeStream()
        let sut = LocationManager(manager: manager, onUpdate: { updated.yield($0.forceAcceptance); return .accepted },
                                  oneShotTimeoutSleep: clock.sleep)
        var starts = clock.started.makeAsyncIterator()
        var deliveries = updates.makeAsyncIterator()
        let first = Task { await sut.refreshCurrentLocation() }
        let firstDeadline = try #require(await starts.next())
        clock.expire(firstDeadline)
        #expect(await result(of: first, sut: sut, manager: manager) == false)
        sut.locationManager(manager, didUpdateLocations: [CLLocation(latitude: 40, longitude: -105)])
        #expect(await deliveries.next() == false)
        let next = Task { await sut.refreshCurrentLocation() }
        let nextDeadline = try #require(await starts.next())
        sut.locationManager(manager, didUpdateLocations: [CLLocation(latitude: 40, longitude: -105)])
        #expect(await result(of: next, sut: sut, manager: manager))
        clock.expire(firstDeadline)
        clock.expire(nextDeadline)
        #expect(manager.requestLocationCount == 2)
    }

    @MainActor
    @Test("authorization callback updates cached authStatus")
    func locationManagerDidChangeAuthorization_updatesAuthStatus() async throws {
        let manager = StubAuthorizationManager(status: .notDetermined)
        let sut = LocationManager(manager: manager, onUpdate: { _ in .accepted })
        #expect(sut.authStatus == .notDetermined)

        manager.stubStatus = .authorizedAlways
        sut.locationManagerDidChangeAuthorization(manager)

        let updated = await waitUntil {
            sut.authStatus == .authorizedAlways
        }
        #expect(updated == true)
    }

    @MainActor
    @Test("authorization callback updates cached accuracyAuthorization")
    func locationManagerDidChangeAuthorization_updatesAccuracyAuthorization() async throws {
        let manager = StubAuthorizationManager(status: .authorizedWhenInUse, accuracy: .fullAccuracy)
        let sut = LocationManager(manager: manager, onUpdate: { _ in .accepted })
        #expect(sut.accuracyAuthorization == .fullAccuracy)

        manager.stubAccuracy = .reducedAccuracy
        sut.locationManagerDidChangeAuthorization(manager)

        let updated = await waitUntil {
            sut.accuracyAuthorization == .reducedAccuracy
        }
        #expect(updated == true)
    }

    @MainActor
    @Test("requestAlwaysAuthorizationUpgradeIfNeeded requests always when currently authorized while in use")
    func requestAlwaysAuthorizationUpgradeIfNeeded_requestsAlwaysAuthorization() {
        let manager = StubAuthorizationManager(status: .authorizedWhenInUse)
        let sut = LocationManager(manager: manager, onUpdate: { _ in .accepted })

        let didRequestUpgrade = sut.requestAlwaysAuthorizationUpgradeIfNeeded()

        #expect(didRequestUpgrade)
        #expect(manager.requestAlwaysCount == 1)
    }

    @MainActor
    @Test("requestAlwaysAuthorizationUpgradeIfNeeded skips when current auth is not while in use")
    func requestAlwaysAuthorizationUpgradeIfNeeded_skipsOtherStates() {
        let disallowedStatuses: [CLAuthorizationStatus] = [
            .authorizedAlways,
            .denied,
            .restricted,
            .notDetermined
        ]

        for status in disallowedStatuses {
            let manager = StubAuthorizationManager(status: status)
            let sut = LocationManager(manager: manager, onUpdate: { _ in .accepted })
            let didRequestUpgrade = sut.requestAlwaysAuthorizationUpgradeIfNeeded()

            #expect(didRequestUpgrade == false)
            #expect(manager.requestAlwaysCount == 0)
        }
    }
}

@Suite("LocationSession")
struct LocationSessionTests {
    @Test @MainActor
    func accuracyRecoveryRejectsCachedEvidence() async throws {
        let (publications, published) = AsyncStream<Void>.makeStream()
        defer { published.finish() }
        let clock = PresenceClock()
        let old = durableContext(timestamp: clock.now.addingTimeInterval(-1))
        let core = LocationManagerTests.StubAuthorizationManager(status: .authorizedAlways)
        let manager = LocationManager(manager: core, onUpdate: { _ in .accepted })
        let resolver = ControlledResolver()
        let client = LocationClient(snapshot: { old.snapshot }, updates: { AsyncStream { $0.finish() } })
        let session = LocationSession(locationClient: client, locationManager: manager,
            locationContextResolver: resolver, locationUploadCoordinator: NoOpLocationUploadCoordinator(),
            presenceNow: { clock.now }, onContextPublished: { published.yield(()) })
        session.currentContext = old
        session.startupState = .ready
        session.handleScenePhaseChange(.active)
        core.stubAccuracy = .reducedAccuracy
        manager.locationManagerDidChangeAuthorization(core)
        try #require(try await withTimeout(timeout: 10) {
            var publication = publications.makeAsyncIterator()
            return await publication.next() != nil
        })
        try #require(session.accuracyAuthorization == .reducedAccuracy && session.currentContext == nil)
        #expect(session.reliabilityState.accuracy == .reduced)
        core.stubAccuracy = .fullAccuracy
        manager.locationManagerDidChangeAuthorization(core)
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .prepare).count == 1 })
        let id = try #require(await resolver.pendingIDs(for: .prepare).first)
        await resolver.complete(id: id, with: .success(old))
        try #require(await waitUntilAsync { session.startupState == .failed("location-evidence-required") })
        #expect(session.currentContext == nil)
        #expect(await resolver.lastPreparationRequiresFresh == true)
        #expect(await resolver.lastPreparationMinimumTimestamp == clock.now)
        let fresh = durableContext(timestamp: clock.now.addingTimeInterval(1))
        let retry = Task { await session.prepareCurrentLocationContext(requiresFreshLocation: false, showsAuthorizationPrompt: false) }
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .prepare).count == 1 })
        let retryID = try #require(await resolver.pendingIDs(for: .prepare).first)
        await resolver.complete(id: retryID, with: .success(fresh))
        #expect(await retry.value == fresh)
    }

    @Test @MainActor
    func permissionRecoveryDoesNotAcquireWithWhenInUseInBackground() async throws {
        let core = LocationManagerTests.StubAuthorizationManager(status: .authorizedAlways)
        let manager = LocationManager(manager: core, onUpdate: { _ in .accepted })
        let resolver = StubResolver(context: durableContext(timestamp: .now), error: nil)
        let session = LocationSession(locationClient: makeLocationClient(provider: LocationProvider()),
            locationManager: manager, locationContextResolver: resolver,
            locationUploadCoordinator: NoOpLocationUploadCoordinator())
        session.handleScenePhaseChange(.background)
        core.stubStatus = .authorizedWhenInUse
        manager.locationManagerDidChangeAuthorization(core)
        try #require(await waitUntilAsync { session.authorizationStatus == .authorizedWhenInUse })
        let context = await session.prepareScheduledBackgroundLocationContext(
            uploadSource: nil, uploadReason: nil, authorizationTimeout: 0.1,
            locationTimeout: 0.1, maximumAcceptedLocationAge: 300, placemarkTimeout: 0.1)
        #expect(context == nil)
        #expect(await resolver.recordedPrepareCallCount() == 0)
    }

    @Test @MainActor
    func sharingCapturesFenceStaleContextAndPermitFreshSameCellRecovery() async throws {
        let clock = PresenceClock()
        clock.now = Date(timeIntervalSince1970: 10)
        let old = durableContext(timestamp: Date(timeIntervalSince1970: 9))
        let updates = AsyncStream<LocationSnapshot>.makeStream()
        defer { updates.continuation.finish() }
        let subscribed = AsyncStream<Void>.makeStream()
        let client = LocationClient(snapshot: { old.snapshot }, updates: {
            subscribed.continuation.yield(())
            return updates.stream
        })
        let manager = LocationManager(manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted })
        let resolver = ControlledResolver()
        let uploads = StubUploadCoordinator()
        let session = LocationSession(locationClient: client, locationManager: manager,
            locationContextResolver: resolver, locationUploadCoordinator: uploads,
            presenceNow: { clock.now })
        session.currentContext = old
        session.startupState = .ready
        session.captureLocationSharingPreferenceChange(enabled: false)
        clock.now = Date(timeIntervalSince1970: 20)
        session.captureLocationSharingPreferenceChange(enabled: true)
        #expect(uploads.evidenceCutoffs.withLock { $0 } == [Date(timeIntervalSince1970: 10), clock.now])
        session.handleScenePhaseChange(.active)
        var iterator = subscribed.stream.makeAsyncIterator()
        _ = await iterator.next()
        subscribed.continuation.finish()
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .prepare).count == 1 })
        let pending = try #require(await resolver.pendingIDs(for: .prepare).first)
        #expect(await resolver.lastPreparationMinimumTimestamp == clock.now)
        await resolver.complete(id: pending, with: .success(old))
        try #require(await waitUntilAsync { session.startupState == .failed("location-evidence-required") })
        #expect(session.currentContext == old) // Accepted Home cache remains available for local presentation.
        let fresh = durableContext(timestamp: Date(timeIntervalSince1970: 21))
        updates.continuation.yield(fresh.snapshot)
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .resolve).count == 1 })
        let resolution = try #require(await resolver.pendingIDs(for: .resolve).first)
        await resolver.complete(id: resolution, with: .success(fresh))
        try #require(await waitUntilAsync { session.startupState == .ready && session.currentContext == fresh })
    }

    @MainActor private final class PresenceClock {
        var now = Date()
    }

    private actor RecordingPresence: LocationPresenceEnqueuing {
        var observations: [(LocationSnapshot, LocationUploadSource, LocationUploadReason)] = []
        var succeeds = true
        func enqueuePresence(_ observation: LocationSnapshot, source: LocationUploadSource,
                             reason: LocationUploadReason) async -> Bool {
            observations.append((observation, source, reason))
            return succeeds
        }
        func setSuccess(_ value: Bool) { succeeds = value }
        func count() -> Int { observations.count }
        func recorded() -> [(LocationSnapshot, LocationUploadSource, LocationUploadReason)] { observations }
    }

    @Test @MainActor
    func processPresenceWithoutHomeAndBoundedRetry() async throws {
        let clock = PresenceClock()
        let presence = RecordingPresence()
        let admission = LocationPresenceAdmission(provider: LocationProvider(), foreground: presence,
            background: presence, now: { clock.now })
        let first = durableContext(timestamp: clock.now).snapshot
        await presence.setSuccess(false)
        #expect(await admission.admit(first, source: .foregroundLocationChange) == .failed)
        #expect(await admission.admit(first, source: .backgroundLocationChange) == .notAttempted)
        clock.now.addTimeInterval(30)
        await presence.setSuccess(true)
        #expect(await admission.admit(first, source: .foregroundLocationChange) == .retained)
        clock.now.addTimeInterval(10)
        #expect(await admission.admit(durableContext(timestamp: clock.now).snapshot,
            source: .backgroundLocationChange) == .notAttempted)
        clock.now.addTimeInterval(300)
        #expect(await admission.admit(durableContext(timestamp: clock.now).snapshot,
            source: .backgroundLocationChange) == .retained)
        #expect(await presence.count() == 3)
    }

    @Test @MainActor
    func consentCutoffResetsCadenceWithoutReplayingOldEvidence() async {
        let clock = PresenceClock()
        let presence = RecordingPresence()
        let admission = LocationPresenceAdmission(provider: LocationProvider(), foreground: presence,
            background: presence, now: { clock.now }, evidenceCutoff: { clock.now })
        let first = durableContext(timestamp: clock.now).snapshot
        #expect(await admission.admit(first, source: .foregroundLocationChange) == .retained)
        clock.now.addTimeInterval(1)
        #expect(await admission.admit(first, source: .foregroundLocationChange) == .notAttempted)
        let fresh = durableContext(timestamp: clock.now).snapshot
        #expect(await admission.admit(fresh, source: .foregroundLocationChange) == .retained)
        #expect(await presence.count() == 2)
    }

    @Test(arguments: [false, true]) @MainActor
    func restoredObservationAdmitsOnFirstActivationUnlessBeforeCutoff(beforeCutoff: Bool) async throws {
        let now = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        let suite = "activation-cache-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let cell = try SwiftyH3Hasher().h3Cell(for: .init(latitude: 39.7392, longitude: -104.9903))
        let snapshot = durableContext(timestamp: now.addingTimeInterval(-120), h3Cell: cell).snapshot
        let cache = LocationSnapshotCache(suiteName: suite)
        cache.save(snapshot)
        let provider = LocationProvider(snapshotCache: cache, nowProvider: { now })
        let presence = RecordingPresence()
        let admission = LocationPresenceAdmission(provider: provider, foreground: presence,
            background: presence, now: { now }, evidenceCutoff: { beforeCutoff ? now : nil })
        await admission.retryForegroundAdmission()
        await admission.retryForegroundAdmission()
        let observations = await presence.recorded()
        #expect(observations.count == (beforeCutoff ? 0 : 1))
        if !beforeCutoff { #expect(observations.first?.0.timestamp == snapshot.timestamp) }
    }

    private actor ActivationPreparationGate {
        var holds: Bool
        var entered = false
        var continuation: CheckedContinuation<Void, Never>?
        init(holds: Bool) { self.holds = holds }
        func read() async -> String {
            entered = true
            if holds { await withCheckedContinuation { continuation = $0 } }
            return "test"
        }
        func release() { holds = false; continuation?.resume(); continuation = nil }
    }

    @Test(arguments: [false, true], [false, true]) @MainActor
    func activationHeldAcrossBackgroundRetainsWithoutForegroundDrain(
        holdPreparation: Bool, reactivateBeforeRelease: Bool
    ) async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let suite = "activation-phase-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let store = UserDefaultsLocationUploadQueueStore(suiteName: suite, key: "pending")
        let held = RecoveringQueueStore(backing: store, fails: false)
        if !holdPreparation { await held.holdSave() }
        let preparation = ActivationPreparationGate(holds: holdPreparation)
        let uploader = CancellablePresenceUploader()
        await uploader.unblock()
        let pusher = LocationSnapshotPusher(locationUploader: uploader,
            preferenceUploader: PresencePreferenceUploader(), installationIdProvider: { "installation" },
            locationUploadEnabledProvider: { true }, authorizationStatusProvider: { .authorizedAlways },
            accuracyAuthorizationProvider: { .fullAccuracy }, osVersionProvider: { await preparation.read() },
            nowProvider: { now }, retryDelaysSeconds: [0], queueStore: held)
        let cell = try SwiftyH3Hasher().h3Cell(for: .init(latitude: 39.7392, longitude: -104.9903))
        let snapshot = durableContext(timestamp: now.addingTimeInterval(-120), h3Cell: cell).snapshot
        let cache = LocationSnapshotCache(suiteName: suite)
        cache.save(snapshot)
        let admission = LocationPresenceAdmission(
            provider: LocationProvider(snapshotCache: cache, nowProvider: { now }),
            foreground: ForegroundPresenceEnqueuer(pusher: pusher),
            background: BackgroundPresenceEnqueuer(pusher: pusher), now: { now })
        let finished = AsyncStream<Void>.makeStream()
        defer { finished.continuation.finish() }
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedAlways),
            onUpdate: { _ in .rejected },
            onForegroundActivation: { eligible in
                await admission.retryForegroundAdmission(isEligible: eligible)
                if eligible() { await pusher.drainPendingUploads() }
                finished.continuation.yield(())
            }, foregroundUpdates: { _ in })
        manager.updateMode(for: .active)
        try #require(await waitUntilAsync {
            if holdPreparation { return await preparation.entered }
            return await held.suspended
        })
        manager.updateMode(for: .background)
        if reactivateBeforeRelease { manager.updateMode(for: .active) }
        await held.releaseSave()
        await preparation.release()
        var iterator = finished.stream.makeAsyncIterator()
        _ = await iterator.next()
        if !reactivateBeforeRelease {
            #expect(await uploader.started == false)
            #expect(await store.loadPendingRequests().count == 1)
            manager.updateMode(for: .active)
        }
        _ = await iterator.next()
        #expect(await uploader.delivered.map(\.capturedAt) == [snapshot.timestamp])
        #expect(await store.loadPendingRequests().isEmpty)
        manager.updateMode(for: .background)
    }

    private struct UnavailablePresenceGeocoder: LocationGeocoding {
        func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String {
            throw URLError(.notConnectedToInternet)
        }
    }

    private actor RecoveringQueueStore: LocationUploadQueueStoring {
        let backing: any LocationUploadQueueStoring
        var fails: Bool
        var hold = false
        var suspended = false
        var gate: CheckedContinuation<Void, Never>?
        func holdSave() { hold = true }
        func releaseSave() { hold = false; gate?.resume(); gate = nil }
        init(backing: any LocationUploadQueueStoring, fails: Bool) { self.backing = backing; self.fails = fails }
        func recover() { fails = false }
        func loadPendingRequests() async -> [PersistedLocationUploadRequest] { await backing.loadPendingRequests() }
        func savePendingRequests(_ requests: [PersistedLocationUploadRequest]) async throws {
            if fails { throw URLError(.cannotWriteToFile) }
            if hold {
                suspended = true
                await withCheckedContinuation { gate = $0 }
            }
            try await backing.savePendingRequests(requests)
        }
    }

    private actor CancellablePresenceUploader: LocationSnapshotUploading {
        var blocked = true
        var started = false
        var delivered: [LocationSnapshotPushPayload] = []
        func unblock() { blocked = false }
        func upload(_ payload: LocationSnapshotPushPayload) async throws {
            started = true
            if blocked { try await Task.sleep(for: .seconds(60)) }
            delivered.append(payload)
        }
    }

    private struct PresencePreferenceUploader: DevicePreferenceSyncUploading {
        func upload(_ payload: DevicePreferenceSyncPayload) async throws {}
    }

    @Test @MainActor
    func sharedBackgroundCadenceSurvivesCancelledDrainAndReopen() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let suite = "runtime-cancel-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let store = UserDefaultsLocationUploadQueueStore(suiteName: suite, key: "pending")
        let uploader = CancellablePresenceUploader()
        func pusher(store: any LocationUploadQueueStoring) -> LocationSnapshotPusher {
            LocationSnapshotPusher(locationUploader: uploader, preferenceUploader: PresencePreferenceUploader(),
                installationIdProvider: { "installation" }, locationUploadEnabledProvider: { true },
                authorizationStatusProvider: { .authorizedAlways }, accuracyAuthorizationProvider: { .fullAccuracy },
                nowProvider: { now }, retryDelaysSeconds: [0], queueStore: store)
        }
        let original = pusher(store: store)
        let admission = LocationPresenceAdmission(
            provider: LocationProvider(geocoder: LocationManagerTests.OfflineGeocoder(), nowProvider: { now }),
            foreground: ForegroundPresenceEnqueuer(pusher: original),
            background: BackgroundPresenceEnqueuer(pusher: original), now: { now })
        let coordinates = CLLocationCoordinate2D(latitude: 39, longitude: -104)
        let capture = now.addingTimeInterval(-120)
        #expect(await admission.accept(.init(coordinates: coordinates, timestamp: capture, accuracy: 20),
            source: .backgroundLocationChange).retention == .retained)
        #expect(await admission.accept(.init(coordinates: coordinates, timestamp: now, accuracy: 20),
            source: .backgroundLocationChange).retention == .notAttempted)
        let delivery = Task { await original.drainPendingUploads() }
        try #require(await waitUntilAsync { await uploader.started })
        delivery.cancel()
        await delivery.value
        #expect(await uploader.delivered.isEmpty)
        let reopened = UserDefaultsLocationUploadQueueStore(suiteName: suite, key: "pending")
        let pending = await reopened.loadPendingRequests()
        #expect(pending.count == 1)
        #expect(pending.first?.source == .backgroundLocationChange)
        if case .locationSnapshot(let context) = pending.first?.operation {
            #expect(context.capturedAt == capture)
        } else { Issue.record("Expected retained location") }
        await uploader.unblock()
        await pusher(store: reopened).drainPendingUploads()
        #expect(await reopened.loadPendingRequests().isEmpty)
        #expect(await uploader.delivered.map(\.capturedAt) == [capture])
    }

    @MainActor
    @Test("V4 foreground movement enriches only current geography even with minimal transport active", arguments: [0, 1, 2, 3])
    func foregroundMovementReachesV4Transport(scenario: Int) async throws {
        let storageFails = scenario == 3
        let clock = PresenceClock()
        let staleResolution = scenario == 1
        let beforePreparation = scenario == 2
        let now = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        func context(latitude: Double, timestamp: Date) throws -> LocationContext {
            let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: -105)
            let cell = try SwiftyH3Hasher().h3Cell(for: coordinates)
            return LocationContext(snapshot: .init(coordinates: coordinates, timestamp: timestamp,
                accuracy: 20, placemarkSummary: nil, h3Cell: cell), h3Cell: cell,
                grid: .init(nwsId: "test", latitude: latitude, longitude: -105, gridId: "BOU", gridX: 1, gridY: 1,
                    forecastURL: nil, forecastHourlyURL: nil, forecastGridDataURL: nil, observationStationsURL: nil,
                    city: nil, state: nil, timeZoneId: nil, radarStationId: nil, forecastZone: "COZ039",
                    countyCode: "COC031", fireZone: "COZ246", countyLabel: "Denver", fireZoneLabel: "Fire area"))
        }
        let first = try context(latitude: 39, timestamp: now.addingTimeInterval(-120))
        let moved = try context(latitude: 40, timestamp: now)
        let suite = "foreground-v4-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let id = "f0465f55-f0a2-48a0-aac0-6a5c48a95891"
        let consent = InstallationConsentStore(suiteName: suite, settings: {
            .init(isSubscribed: true, mesoNotificationsEnabled: true,
                  locationSharingEnabled: true, locationAuthorization: .whenInUse)
        }, markerExists: { false }, createMarker: {}, accuracy: { .fullAccuracy }, now: { .distantPast })
        let http = ConsentHTTP()
        let base = URL(string: "https://arcus.example.com")!
        let queueStore = UserDefaultsLocationUploadQueueStore(suiteName: suite, key: "pending")
        let recoveringStore = RecoveringQueueStore(backing: queueStore, fails: storageFails)
        let pusher = LocationSnapshotPusher(
            locationUploader: HTTPLocationSnapshotUploader(baseURL: base, http: http,
                enrollment: enrolledTestCoordinator(), consent: consent, protocolVersion: .geographyInvalidatingV4),
            preferenceUploader: HTTPDevicePreferenceSyncUploader(baseURL: base, http: http,
                enrollment: enrolledTestCoordinator(), consent: consent),
            installationIdProvider: { id }, locationUploadEnabledProvider: { true },
            authorizationStatusProvider: { .authorizedWhenInUse }, accuracyAuthorizationProvider: { .fullAccuracy },
            osVersionProvider: { "test-os" }, nowProvider: { now },
            retryDelaysSeconds: [0], queueStore: recoveringStore)
        let provider = LocationProvider(geocoder: UnavailablePresenceGeocoder(), nowProvider: { now })
        let admission = LocationPresenceAdmission(provider: provider, foreground: ForegroundPresenceEnqueuer(pusher: pusher),
            background: BackgroundPresenceEnqueuer(pusher: pusher), now: { clock.now })
        let subscribed = AsyncStream<Void>.makeStream()
        let activations = AsyncStream<Void>.makeStream()
        defer { activations.continuation.finish() }
        func nextActivation() async throws {
            try #require(try await withTimeout(timeout: 10) {
                var iterator = activations.stream.makeAsyncIterator()
                return await iterator.next() != nil
            })
        }
        let resolver = ControlledResolver()
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { await admission.accept($0, source: .foregroundLocationChange).acceptance },
            onForegroundActivation: { eligible in
                await admission.retryForegroundAdmission(isEligible: eligible)
                if eligible() { await pusher.drainPendingUploads() }
                activations.continuation.yield(())
            }, foregroundUpdates: { _ in })
        let session = LocationSession(locationClient: LocationClient(snapshot: { await provider.snapshot() }, updates: {
            subscribed.continuation.yield(())
            return await provider.updates()
        }), locationManager: manager, locationContextResolver: resolver,
            locationUploadCoordinator: pusher)
        session.handleScenePhaseChange(.active)
        session.startupState = .failed("location-timeout")
        var subscription = subscribed.stream.makeAsyncIterator()
        _ = await subscription.next()
        subscribed.continuation.finish()
        try await nextActivation()
        let initialHTTPCount = await http.recorded().count
        if staleResolution {
            _ = await admission.accept(.init(coordinates: first.snapshot.coordinates,
                timestamp: first.snapshot.timestamp, accuracy: first.snapshot.accuracy), source: .foregroundLocationChange)
            try #require(await waitUntilAsync { await resolver.pendingIDs(for: .resolve).count == 1 })
            try #require(await waitUntilAsync { await http.recorded().filter { $0.path.contains("location-snapshots") }.count == 1 })
            // Ensure the first transport completed before pausing the movement's minimal transfer.
            try #require(await waitUntilAsync { await queueStore.loadPendingRequests().isEmpty })
        }
        if beforePreparation { await http.pause() } else { await http.pausePresence() }
        let movement = Task { await admission.accept(.init(coordinates: moved.snapshot.coordinates,
            timestamp: moved.snapshot.timestamp, accuracy: moved.snapshot.accuracy), source: .foregroundLocationChange) }
        defer { movement.cancel() }
        if storageFails {
            #expect(await movement.value.retention == .failed)
            #expect(await queueStore.loadPendingRequests().isEmpty)
            #expect(await http.recorded().isEmpty)
            await recoveringStore.recover()
            manager.updateMode(for: .inactive)
            manager.updateMode(for: .active)
            try await nextActivation()
            #expect(await queueStore.loadPendingRequests().isEmpty)
            clock.now.addTimeInterval(30)
            manager.updateMode(for: .inactive)
            manager.updateMode(for: .active) // No new Core Location fix and Home remains blocked.
        }
        try #require(await waitUntilAsync {
            let requests = await http.recorded()
            if beforePreparation {
                return requests.count == initialHTTPCount + 1 && requests.last?.path == "/v3/devices/preferences"
            }
            return requests.filter { $0.path.contains("location-snapshots") }.count == (staleResolution ? 2 : 1)
        })
        #expect(await movement.value.retention == (storageFails ? .failed : .retained)) // Admission returns while HTTP and Home are blocked.
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .resolve).count == 1 })
        let firstID = try #require(await resolver.pendingIDs(for: .resolve).first)
        await resolver.complete(id: firstID, with: .success(staleResolution ? first : moved))
        if staleResolution {
            try #require(await waitUntilAsync { await resolver.pendingIDs(for: .resolve).count == 1 })
            let movedID = try #require(await resolver.pendingIDs(for: .resolve).first)
            await resolver.complete(id: movedID, with: .success(moved))
        }
        try #require(await waitUntilAsync {
            let requests = await queueStore.loadPendingRequests()
            return requests.contains { request in
                if case .locationSnapshot(let context) = request.operation { return context.county != nil }
                return false
            }
        })
        // Reversed task arrival must not replace the enriched durable intent with minimal metadata.
        #expect(await pusher.enqueuePresence(moved.snapshot, source: .foregroundLocationChange, reason: .locationChanged))
        let pending = await queueStore.loadPendingRequests()
        #expect(pending.contains { request in
            if case .locationSnapshot(let context) = request.operation { return context.county == "COC031" }
            return false
        })
        await http.release()
        try #require(await waitUntilAsync { await queueStore.loadPendingRequests().isEmpty })
        let requests = await http.recorded().filter { $0.path.contains("location-snapshots") }
        #expect(requests.allSatisfy { $0.path == "/v4/devices/location-snapshots" })
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payloads = try requests.map { try decoder.decode(DeviceLocationSnapshotV3Payload.self, from: $0.body!) }
        #expect(payloads.count == (staleResolution ? 3 : (beforePreparation ? 1 : 2)))
        #expect(payloads.dropLast().allSatisfy { $0.county == nil && $0.zone == nil && $0.fireZone == nil })
        let enriched = try #require(payloads.last)
        #expect(enriched.h3Cell == moved.h3Cell && enriched.capturedAt == moved.snapshot.timestamp)
        #expect(enriched.county == moved.grid.countyCode && enriched.fireZone == moved.grid.fireZone)
        #expect(enriched.zone == moved.grid.forecastZone)
        #expect(enriched.countyLabel == "Denver" && enriched.fireZoneLabel == "Fire area")
    }

    private func durableContext(
        timestamp: Date,
        accuracy: Double = 20,
        h3Cell: Int64 = 1
    ) -> LocationContext {
        LocationContext(
            snapshot: .init(
                coordinates: .init(latitude: 39.7392, longitude: -104.9903),
                timestamp: timestamp,
                accuracy: accuracy,
                placemarkSummary: nil,
                h3Cell: h3Cell
            ),
            h3Cell: h3Cell,
            grid: .init(
                nwsId: "id",
                latitude: 39.7392,
                longitude: -104.9903,
                gridId: "BOU",
                gridX: 1,
                gridY: 1,
                forecastURL: nil,
                forecastHourlyURL: nil,
                forecastGridDataURL: nil,
                observationStationsURL: nil,
                city: nil,
                state: nil,
                timeZoneId: nil,
                radarStationId: nil,
                forecastZone: nil,
                countyCode: "COC031",
                fireZone: "COZ246",
                countyLabel: nil,
                fireZoneLabel: nil
            )
        )
    }

    private actor StubResolver: LocationContextResolving {
        let context: LocationContext?
        let error: LocationContextError?
        private var prepareCallCount = 0
        private var resolveCallCount = 0

        init(context: LocationContext?, error: LocationContextError?) {
            self.context = context
            self.error = error
        }

        func prepareCurrentContext(
            requiresFreshLocation: Bool,
            showsAuthorizationPrompt: Bool,
            authorizationTimeout: Double,
            locationTimeout: Double,
            maximumAcceptedLocationAge: TimeInterval,
            placemarkTimeout: Double, minimumObservationTimestamp: Date?
        ) async throws -> LocationContext {
            prepareCallCount += 1
            if let context {
                return context
            }
            throw error ?? LocationContextError.locationTimeout
        }

        func resolveContext(
            from snapshot: LocationSnapshot,
            maximumAcceptedLocationAge: TimeInterval?,
            placemarkTimeout: Double
        ) async throws -> LocationContext {
            resolveCallCount += 1
            if let context {
                return context
            }
            throw error ?? LocationContextError.locationTimeout
        }

        func recordedPrepareCallCount() -> Int { prepareCallCount }
        func recordedResolveCallCount() -> Int { resolveCallCount }
    }

    private actor ControlledResolver: LocationContextResolving {
        enum Operation: Equatable {
            case prepare
            case resolve
        }

        private struct PendingRequest {
            let id: Int
            let operation: Operation
            let continuation: CheckedContinuation<LocationContext, Error>
        }

        private(set) var lastPreparationRequiresFresh = false
        private(set) var lastPreparationMinimumTimestamp: Date?
        private var nextID = 0
        private var pendingRequests: [PendingRequest] = []

        func prepareCurrentContext(
            requiresFreshLocation: Bool,
            showsAuthorizationPrompt: Bool,
            authorizationTimeout: Double,
            locationTimeout: Double,
            maximumAcceptedLocationAge: TimeInterval,
            placemarkTimeout: Double, minimumObservationTimestamp: Date?
        ) async throws -> LocationContext {
            lastPreparationRequiresFresh = requiresFreshLocation
            lastPreparationMinimumTimestamp = minimumObservationTimestamp
            return try await enqueue(.prepare)
        }

        func resolveContext(
            from snapshot: LocationSnapshot,
            maximumAcceptedLocationAge: TimeInterval?,
            placemarkTimeout: Double
        ) async throws -> LocationContext {
            try await enqueue(.resolve)
        }

        func pendingIDs(for operation: Operation) -> [Int] {
            pendingRequests.filter { $0.operation == operation }.map(\.id)
        }

        func complete(id: Int, with result: Result<LocationContext, LocationContextError>) {
            guard let index = pendingRequests.firstIndex(where: { $0.id == id }) else { return }
            let request = pendingRequests.remove(at: index)
            switch result {
            case .success(let context):
                request.continuation.resume(returning: context)
            case .failure(let error):
                request.continuation.resume(throwing: error)
            }
        }

        private func enqueue(_ operation: Operation) async throws -> LocationContext {
            nextID += 1
            let id = nextID
            return try await withCheckedThrowingContinuation { continuation in
                pendingRequests.append(PendingRequest(id: id, operation: operation, continuation: continuation))
            }
        }
    }

    @MainActor
    private func waitUntilAsync(
        timeout: Duration = .seconds(2),
        interval: Duration = .milliseconds(10),
        _ condition: @escaping @MainActor () async -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if await condition() {
                return true
            }
            try? await Task.sleep(for: interval)
        }
        return await condition()
    }

    private actor StubUploadCoordinator: LocationUploadCoordinating {
        nonisolated let evidenceCutoffs = Mutex<[Date]>([])
        nonisolated var minimumLocationObservationTimestamp: Date? { evidenceCutoffs.withLock { $0.last } }
        nonisolated func invalidateLocationEvidence(at date: Date) { evidenceCutoffs.withLock { $0.append(date) } }
        private var enqueueCount = 0
        private var lastForceUpload: Bool?
        private var lastSource: LocationUploadSource?
        private var lastReason: LocationUploadReason?
        private var preferenceSyncCount = 0
        private var lastPreferenceReason: String?
        private var lastPreferenceIsSubscribedOverride: Bool?
        private var drainCount = 0

        func enqueue(
            _ context: LocationContext,
            source: LocationUploadSource,
            reason: LocationUploadReason,
            forceUpload: Bool
        ) async {
            enqueueCount += 1
            lastForceUpload = forceUpload
            lastSource = source
            lastReason = reason
        }

        func enqueuePreferenceSync(
            source: LocationUploadSource,
            requestReason: LocationUploadReason,
            forceUpload: Bool,
            detail: String,
            isSubscribedOverride: Bool?
        ) async {
            preferenceSyncCount += 1
            lastForceUpload = forceUpload
            lastSource = source
            lastReason = requestReason
            lastPreferenceReason = detail
            lastPreferenceIsSubscribedOverride = isSubscribedOverride
        }

        func drainPendingUploads() async {
            drainCount += 1
        }

        func drainPendingUploads(
            using budget: PendingLocationUploadDrainBudget
        ) async -> PendingLocationUploadDrainOutcome {
            drainCount += 1
            return .drained
        }

        func recordedEnqueueCount() -> Int { enqueueCount }
        func recordedLastForceUpload() -> Bool? { lastForceUpload }
        func recordedLastSource() -> LocationUploadSource? { lastSource }
        func recordedLastReason() -> LocationUploadReason? { lastReason }
        func recordedPreferenceSyncCount() -> Int { preferenceSyncCount }
        func recordedLastPreferenceReason() -> String? { lastPreferenceReason }
        func recordedLastPreferenceIsSubscribedOverride() -> Bool? { lastPreferenceIsSubscribedOverride }
        func recordedDrainCount() -> Int { drainCount }
    }

    @Test("preference convenience forwards a nil subscription override")
    func preferenceConvenience_forwardsNilSubscriptionOverride() async {
        let coordinator = StubUploadCoordinator()

        await coordinator.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: true,
            detail: "notification"
        )

        #expect(await coordinator.recordedPreferenceSyncCount() == 1)
        #expect(await coordinator.recordedLastPreferenceReason() == "notification")
        #expect(await coordinator.recordedLastPreferenceIsSubscribedOverride() == nil)
    }

    @MainActor
    @Test("stores a ready context returned by the resolver")
    func storesReadyContextFromResolver() async throws {
        let provider = LocationProvider()
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )

        let context = LocationContext(
            snapshot: LocationSnapshot(
                coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
                timestamp: Date(timeIntervalSince1970: 1_234_567),
                accuracy: 20,
                placemarkSummary: "Denver, CO",
                h3Cell: 0x882681b485fffff
            ),
            h3Cell: 0x882681b485fffff,
            grid: GridPointSnapshot(
                nwsId: "https://api.weather.gov/points/39.7392,-104.9903",
                latitude: 39.7392,
                longitude: -104.9903,
                gridId: "BOU",
                gridX: 56,
                gridY: 66,
                forecastURL: nil,
                forecastHourlyURL: nil,
                forecastGridDataURL: nil,
                observationStationsURL: nil,
                city: "Denver",
                state: "CO",
                timeZoneId: "America/Denver",
                radarStationId: "KFTG",
                forecastZone: "COZ039",
                countyCode: "COC031",
                fireZone: "COZ246",
                countyLabel: "Denver County",
                fireZoneLabel: "East Central Colorado"
            )
        )
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: StubResolver(context: context, error: nil),
            locationUploadCoordinator: NoOpLocationUploadCoordinator()
        )

        let result = await session.prepareCurrentLocationContext(
            requiresFreshLocation: false,
            showsAuthorizationPrompt: false
        )

        #expect(result == context)
        #expect(session.currentContext == context)
        #expect(session.currentSnapshot == context.snapshot)
        #expect(session.startupState == .ready)
    }

    @MainActor
    @Test("maps resolver failures into startup state")
    func mapsResolverFailuresIntoStartupState() async throws {
        let provider = LocationProvider()
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )

        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: StubResolver(context: nil, error: .missingRegionContext),
            locationUploadCoordinator: NoOpLocationUploadCoordinator()
        )

        let result = await session.prepareCurrentLocationContext(
            requiresFreshLocation: false,
            showsAuthorizationPrompt: false
        )

        #expect(result == nil)
        #expect(session.currentContext == nil)
        #expect(session.startupState == .failed("location-missing-region-context"))
    }

    private actor AcceptedSnapshotState {
        var latest: LocationSnapshot?
        private(set) var publications = 0

        func accept(_ snapshot: LocationSnapshot) { latest = snapshot }
        func recordPublication() { publications += 1 }
    }

    @MainActor
    @Test("inactive preparation rejects a superseded geography before publication or upload",
          arguments: [false, true], [false, true])
    func inactivePreparationRejectsSupersededContext(background: Bool, deliversUpdate: Bool) async throws {
        let first = durableContext(timestamp: .now.addingTimeInterval(-1), h3Cell: 1)
        let second = durableContext(timestamp: .now, h3Cell: 2)
        let source = AcceptedSnapshotState()
        await source.accept(first.snapshot)
        let updates = AsyncStream<LocationSnapshot>.makeStream()
        defer { updates.continuation.finish() }
        let subscribed = AsyncStream<Void>.makeStream()
        let client = LocationClient(snapshot: { await source.latest }, updates: {
            subscribed.continuation.yield(())
            return updates.stream
        })
        let suiteName = "LocationSessionTests.superseded.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let cache = DurableLocationContextCache(suiteName: suiteName)
        let manager = LocationManager(manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedAlways),
                                      onUpdate: { _ in .accepted })
        let resolver = ControlledResolver()
        let uploader = StubUploadCoordinator()
        let retention = HomeProjectionRetentionCoordinator()
        let session = LocationSession(locationClient: client, locationManager: manager,
            locationContextResolver: resolver, locationUploadCoordinator: uploader, durableContextCache: cache,
            retentionCoordinator: retention, onContextPublished: { await source.recordPublication() })
        session.handleScenePhaseChange(background ? .background : .inactive)
        var subscribedIterator = subscribed.stream.makeAsyncIterator()
        _ = await subscribedIterator.next()
        subscribed.continuation.finish()
        let preparation = Task {
            await session.prepareCurrentLocationContext(requiresFreshLocation: true, showsAuthorizationPrompt: false,
                                                        uploadSource: .foregroundLocationChange)
        }
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .prepare).count == 1 })
        let id = try #require(await resolver.pendingIDs(for: .prepare).first)
        await source.accept(second.snapshot)
        if deliversUpdate {
            updates.continuation.yield(second.snapshot)
            try #require(await waitUntilAsync { session.currentSnapshot == second.snapshot })
        }
        await resolver.complete(id: id, with: .success(first))
        #expect(await preparation.value == nil)
        #expect(session.currentSnapshot == second.snapshot)
        #expect(session.currentContext == nil)
        #expect(retention.currentActiveProjectionKey() == nil)
        #expect(await source.publications == 0)
        #expect(cache.load() == nil)
        #expect(await uploader.recordedEnqueueCount() == 0)
        // The rejected background result must leave the newer fix available for foreground recovery.
        session.handleScenePhaseChange(.active)
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .resolve).count == 1 })
        let replacementID = try #require(await resolver.pendingIDs(for: .resolve).first)
        await resolver.complete(id: replacementID, with: .success(second))
        #expect(await waitUntilAsync { session.currentContext == second && session.startupState == .ready })
    }

    @MainActor
    @Test("movement during inactive publication prevents later cache and upload handoff")
    func inactivePublicationRechecksBeforeCachingAndUpload() async throws {
        let first = durableContext(timestamp: .now.addingTimeInterval(-1), h3Cell: 1)
        let second = durableContext(timestamp: .now, h3Cell: 2)
        let source = AcceptedSnapshotState()
        await source.accept(first.snapshot)
        let updates = AsyncStream<LocationSnapshot>.makeStream()
        defer { updates.continuation.finish() }
        let entered = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        defer { release.continuation.finish() }
        let client = LocationClient(snapshot: { await source.latest }, updates: { updates.stream })
        let suiteName = "LocationSessionTests.publication.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let cache = DurableLocationContextCache(suiteName: suiteName)
        let manager = LocationManager(manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedAlways),
                                      onUpdate: { _ in .accepted })
        let resolver = ControlledResolver()
        let uploader = StubUploadCoordinator()
        let session = LocationSession(locationClient: client, locationManager: manager,
            locationContextResolver: resolver, locationUploadCoordinator: uploader, durableContextCache: cache,
            onContextPublished: {
                entered.continuation.yield(())
                var iterator = release.stream.makeAsyncIterator()
                _ = await iterator.next()
            })
        let preparation = Task {
            await session.prepareCurrentLocationContext(requiresFreshLocation: true, showsAuthorizationPrompt: false,
                                                        uploadSource: .foregroundLocationChange)
        }
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .prepare).count == 1 })
        let id = try #require(await resolver.pendingIDs(for: .prepare).first)
        await resolver.complete(id: id, with: .success(first))
        var enteredIterator = entered.stream.makeAsyncIterator()
        _ = await enteredIterator.next()
        #expect(session.currentContext == first)
        await source.accept(second.snapshot)
        release.continuation.finish()
        #expect(await preparation.value == nil)
        #expect(session.currentSnapshot == second.snapshot)
        #expect(cache.load() == nil)
        #expect(await uploader.recordedEnqueueCount() == 0)
    }

    @MainActor
    @Test("older explicit location attempt cannot replace a newer result", arguments: [false, true])
    func olderExplicitLocationAttemptCannotReplaceNewerResult(olderAttemptFails: Bool) async {
        let provider = LocationProvider()
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )
        let resolver = ControlledResolver()
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: resolver,
            locationUploadCoordinator: NoOpLocationUploadCoordinator()
        )
        let olderContext = durableContext(timestamp: .now.addingTimeInterval(-60), h3Cell: 1)
        let newerContext = durableContext(timestamp: .now, h3Cell: 2)

        let olderTask = Task {
            await session.prepareCurrentLocationContext(
                requiresFreshLocation: true,
                showsAuthorizationPrompt: false
            )
        }
        let olderStarted = await waitUntilAsync {
            await resolver.pendingIDs(for: .prepare).count == 1
        }
        #expect(olderStarted)
        let olderRequestID = await resolver.pendingIDs(for: .prepare)[0]

        let newerTask = Task {
            await session.prepareCurrentLocationContext(
                requiresFreshLocation: true,
                showsAuthorizationPrompt: false
            )
        }
        let newerStarted = await waitUntilAsync {
            await resolver.pendingIDs(for: .prepare).count == 2
        }
        #expect(newerStarted)
        let requestIDs = await resolver.pendingIDs(for: .prepare)
        let newerRequestID = requestIDs.first { $0 != olderRequestID }
        #expect(newerRequestID != nil)
        guard let newerRequestID else { return }

        await resolver.complete(id: newerRequestID, with: .success(newerContext))
        #expect(await newerTask.value == newerContext)

        await resolver.complete(
            id: olderRequestID,
            with: olderAttemptFails ? .failure(.locationTimeout) : .success(olderContext)
        )
        #expect(await olderTask.value == nil)
        #expect(session.currentContext == newerContext)
        #expect(session.currentSnapshot == newerContext.snapshot)
        #expect(session.startupState == .ready)
    }

    @MainActor
    @Test("a valid foreground fix recovers a failed location acquisition")
    func foregroundFixRecoversFailedAcquisition() async throws {
        let context = durableContext(timestamp: .now)
        let updates = AsyncStream<LocationSnapshot>.makeStream()
        defer { updates.continuation.finish() }
        let subscribed = AsyncStream<Void>.makeStream()
        let client = LocationClient(snapshot: { nil }, updates: {
            subscribed.continuation.yield(())
            return updates.stream
        })
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )
        let resolver = ControlledResolver()
        let session = LocationSession(locationClient: client, locationManager: manager,
                                      locationContextResolver: resolver,
                                      locationUploadCoordinator: NoOpLocationUploadCoordinator())
        session.handleScenePhaseChange(.active)
        var iterator = subscribed.stream.makeAsyncIterator()
        _ = await iterator.next()
        subscribed.continuation.finish()
        let preparation = Task {
            await session.prepareCurrentLocationContext(requiresFreshLocation: true, showsAuthorizationPrompt: false)
        }
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .prepare).count == 1 })
        let prepareID = try #require(await resolver.pendingIDs(for: .prepare).first)
        await resolver.complete(id: prepareID, with: .failure(.locationTimeout))
        #expect(await preparation.value == nil)
        updates.continuation.yield(context.snapshot)
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .resolve).count == 1 })
        let resolveID = try #require(await resolver.pendingIDs(for: .resolve).first)
        await resolver.complete(id: resolveID, with: .success(context))
        #expect(await waitUntilAsync { session.currentContext == context && session.startupState == .ready })
    }

    @MainActor
    @Test("newer streamed fix survives an in-flight recovery", arguments: [false, true], [false, true])
    func newerFixSurvivesRecovery(firstFails: Bool, secondFails: Bool) async throws {
        let first = durableContext(timestamp: .now.addingTimeInterval(-1), h3Cell: 1)
        let second = durableContext(timestamp: .now, h3Cell: 2)
        let updates = AsyncStream<LocationSnapshot>.makeStream()
        defer { updates.continuation.finish() }
        let subscribed = AsyncStream<Void>.makeStream()
        let client = LocationClient(snapshot: { nil }, updates: {
            subscribed.continuation.yield(())
            return updates.stream
        })
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )
        let resolver = ControlledResolver()
        let session = LocationSession(locationClient: client, locationManager: manager,
                                      locationContextResolver: resolver,
                                      locationUploadCoordinator: NoOpLocationUploadCoordinator())
        session.handleScenePhaseChange(.active)
        session.startupState = .failed("location-timeout")
        var iterator = subscribed.stream.makeAsyncIterator()
        _ = await iterator.next()
        subscribed.continuation.finish()
        updates.continuation.yield(first.snapshot)
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .resolve).count == 1 })
        let firstID = try #require(await resolver.pendingIDs(for: .resolve).first)
        updates.continuation.yield(second.snapshot)
        try #require(await waitUntilAsync { session.currentSnapshot == second.snapshot })
        await resolver.complete(id: firstID, with: firstFails ? .failure(.locationTimeout) : .success(first))
        try #require(await waitUntilAsync {
            let ids = await resolver.pendingIDs(for: .resolve)
            return ids.count == 1 && ids.first != firstID
        })
        let secondID = try #require(await resolver.pendingIDs(for: .resolve).first)
        await resolver.complete(id: secondID, with: secondFails ? .failure(.locationTimeout) : .success(second))
        if secondFails {
            #expect(await waitUntilAsync { session.startupState == .failed("location-timeout") })
            #expect(session.currentContext == nil)
            #expect(await resolver.pendingIDs(for: .resolve).isEmpty)
        } else {
            #expect(await waitUntilAsync { session.currentContext == second && session.startupState == .ready })
        }
    }

    @MainActor
    @Test("restoring authorization starts acquisition", arguments: [false, true])
    func authorizationRecoveryStartsAcquisition(afterSettings: Bool) async throws {
        let source = LocationManagerTests.StubAuthorizationManager(status: .denied)
        let manager = LocationManager(manager: source, onUpdate: { _ in .accepted })
        let resolver = ControlledResolver()
        let session = LocationSession(locationClient: makeLocationClient(provider: LocationProvider()),
                                      locationManager: manager, locationContextResolver: resolver,
                                      locationUploadCoordinator: NoOpLocationUploadCoordinator())
        session.handleScenePhaseChange(.active)
        _ = await session.prepareCurrentLocationContext(requiresFreshLocation: true, showsAuthorizationPrompt: false)
        if afterSettings { session.handleScenePhaseChange(.inactive) }
        source.stubStatus = .authorizedWhenInUse
        manager.locationManagerDidChangeAuthorization(source)
        try #require(await waitUntilAsync { session.authorizationStatus == .authorizedWhenInUse })
        if afterSettings { session.handleScenePhaseChange(.active) }
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .prepare).count == 1 })
        let id = try #require(await resolver.pendingIDs(for: .prepare).first)
        let context = durableContext(timestamp: .now)
        await resolver.complete(id: id, with: .success(context))
        #expect(await waitUntilAsync { session.currentContext == context && session.startupState == .ready })
    }

    @MainActor
    @Test("a fix received during acquisition is resolved after its completion", arguments: [false, true])
    func fixDuringAcquisitionIsNotLost(firstFails: Bool) async throws {
        let first = durableContext(timestamp: .now.addingTimeInterval(-1), h3Cell: 1)
        let second = durableContext(timestamp: .now, h3Cell: 2)
        let updates = AsyncStream<LocationSnapshot>.makeStream()
        defer { updates.continuation.finish() }
        let subscribed = AsyncStream<Void>.makeStream()
        let client = LocationClient(snapshot: { nil }, updates: {
            subscribed.continuation.yield(())
            return updates.stream
        })
        let manager = LocationManager(manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
                                      onUpdate: { _ in .accepted })
        let resolver = ControlledResolver()
        let session = LocationSession(locationClient: client, locationManager: manager,
                                      locationContextResolver: resolver,
                                      locationUploadCoordinator: NoOpLocationUploadCoordinator())
        session.handleScenePhaseChange(.active)
        var iterator = subscribed.stream.makeAsyncIterator()
        _ = await iterator.next()
        subscribed.continuation.finish()
        let preparation = Task {
            await session.prepareCurrentLocationContext(requiresFreshLocation: true, showsAuthorizationPrompt: false)
        }
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .prepare).count == 1 })
        let firstID = try #require(await resolver.pendingIDs(for: .prepare).first)
        updates.continuation.yield(second.snapshot)
        try #require(await waitUntilAsync { session.currentSnapshot == second.snapshot })
        await resolver.complete(id: firstID, with: firstFails ? .failure(.locationTimeout) : .success(first))
        _ = await preparation.value
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .resolve).count == 1 })
        let secondID = try #require(await resolver.pendingIDs(for: .resolve).first)
        await resolver.complete(id: secondID, with: .success(second))
        #expect(await waitUntilAsync { session.currentContext == second && session.startupState == .ready })
    }

    @MainActor
    @Test("failed acquisition is not hidden by a pending same-cell fix")
    func failedAcquisitionWithSameCellPendingFixRemainsUnavailable() async throws {
        let existing = durableContext(timestamp: .now.addingTimeInterval(-60), h3Cell: 1)
        let later = durableContext(timestamp: .now, h3Cell: 1)
        let updates = AsyncStream<LocationSnapshot>.makeStream()
        defer { updates.continuation.finish() }
        let subscribed = AsyncStream<Void>.makeStream()
        let client = LocationClient(snapshot: { nil }, updates: {
            subscribed.continuation.yield(())
            return updates.stream
        })
        let manager = LocationManager(manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
                                      onUpdate: { _ in .accepted })
        let resolver = ControlledResolver()
        let session = LocationSession(locationClient: client, locationManager: manager,
                                      locationContextResolver: resolver,
                                      locationUploadCoordinator: NoOpLocationUploadCoordinator())
        session.handleScenePhaseChange(.active)
        session.currentContext = existing
        session.currentSnapshot = existing.snapshot
        session.startupState = .ready
        var iterator = subscribed.stream.makeAsyncIterator()
        _ = await iterator.next()
        subscribed.continuation.finish()
        let preparation = Task {
            await session.prepareCurrentLocationContext(requiresFreshLocation: true, showsAuthorizationPrompt: false)
        }
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .prepare).count == 1 })
        let id = try #require(await resolver.pendingIDs(for: .prepare).first)
        updates.continuation.yield(later.snapshot)
        try #require(await waitUntilAsync { session.currentSnapshot == later.snapshot })
        await resolver.complete(id: id, with: .failure(.locationTimeout))
        #expect(await preparation.value == nil)
        #expect(session.startupState == .failed("location-timeout"))
        #expect(session.currentContext == nil)
        #expect(await resolver.pendingIDs(for: .resolve).isEmpty)
    }

    @MainActor
    @Test("same-cell fix during publication preserves successful preparation and upload")
    func sameCellFixDuringPublicationPreservesSuccess() async throws {
        let first = durableContext(timestamp: .now.addingTimeInterval(-1), h3Cell: 1)
        let later = durableContext(timestamp: .now, h3Cell: 1)
        let updates = AsyncStream<LocationSnapshot>.makeStream()
        defer { updates.continuation.finish() }
        let subscribed = AsyncStream<Void>.makeStream()
        let entered = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let client = LocationClient(snapshot: { nil }, updates: {
            subscribed.continuation.yield(())
            return updates.stream
        })
        let manager = LocationManager(manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
                                      onUpdate: { _ in .accepted })
        let resolver = ControlledResolver()
        let uploader = StubUploadCoordinator()
        let session = LocationSession(locationClient: client, locationManager: manager,
                                      locationContextResolver: resolver, locationUploadCoordinator: uploader,
                                      onContextPublished: {
            entered.continuation.yield(())
            var iterator = release.stream.makeAsyncIterator()
            _ = await iterator.next()
        })
        session.handleScenePhaseChange(.active)
        var subscribedIterator = subscribed.stream.makeAsyncIterator()
        _ = await subscribedIterator.next()
        subscribed.continuation.finish()
        let preparation = Task {
            await session.prepareCurrentLocationContext(requiresFreshLocation: true, showsAuthorizationPrompt: false,
                                                        uploadSource: .foregroundLocationChange)
        }
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .prepare).count == 1 })
        let id = try #require(await resolver.pendingIDs(for: .prepare).first)
        await resolver.complete(id: id, with: .success(first))
        var enteredIterator = entered.stream.makeAsyncIterator()
        _ = await enteredIterator.next()
        updates.continuation.yield(later.snapshot)
        try #require(await waitUntilAsync { session.currentSnapshot == later.snapshot })
        release.continuation.finish()
        #expect(await preparation.value == first)
        #expect(session.startupState == .ready)
        #expect(await resolver.pendingIDs(for: .resolve).isEmpty)
        #expect(await uploader.recordedEnqueueCount() == 1)
        await session.publishCurrentContext(nil)
        #expect(session.contextInterruptionRevision == 1)
        await session.publishCurrentContext(nil)
        #expect(session.contextInterruptionRevision == 1)
    }

    @MainActor
    @Test("same-cell fix during streamed publication still uploads")
    func sameCellStreamDuringPublicationUploads() async throws {
        let first = durableContext(timestamp: .now.addingTimeInterval(-1))
        let later = durableContext(timestamp: .now)
        let updates = AsyncStream<LocationSnapshot>.makeStream()
        defer { updates.continuation.finish() }
        let subscribed = AsyncStream<Void>.makeStream()
        let entered = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let client = LocationClient(snapshot: { nil }, updates: {
            subscribed.continuation.yield(())
            return updates.stream
        })
        let manager = LocationManager(manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
                                      onUpdate: { _ in .accepted })
        let resolver = ControlledResolver()
        let uploader = StubUploadCoordinator()
        let session = LocationSession(locationClient: client, locationManager: manager,
                                      locationContextResolver: resolver, locationUploadCoordinator: uploader,
                                      onContextPublished: {
            entered.continuation.yield(())
            var iterator = release.stream.makeAsyncIterator()
            _ = await iterator.next()
        })
        session.handleScenePhaseChange(.active)
        session.startupState = .failed("location-timeout")
        var subscribedIterator = subscribed.stream.makeAsyncIterator()
        _ = await subscribedIterator.next()
        updates.continuation.yield(first.snapshot)
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .resolve).count == 1 })
        let id = try #require(await resolver.pendingIDs(for: .resolve).first)
        await resolver.complete(id: id, with: .success(first))
        var enteredIterator = entered.stream.makeAsyncIterator()
        _ = await enteredIterator.next()
        updates.continuation.yield(later.snapshot)
        try #require(await waitUntilAsync { session.currentSnapshot == later.snapshot })
        release.continuation.finish()
        #expect(await waitUntilAsync {
            let count = await uploader.recordedEnqueueCount()
            return session.startupState == .ready && count == 1
        })
    }

    @MainActor
    @Test("authorization loss fences a suspended recovery")
    func authorizationLossFencesRecovery() async throws {
        let context = durableContext(timestamp: .now)
        let updates = AsyncStream<LocationSnapshot>.makeStream()
        defer { updates.continuation.finish() }
        let subscribed = AsyncStream<Void>.makeStream()
        let client = LocationClient(snapshot: { nil }, updates: {
            subscribed.continuation.yield(())
            return updates.stream
        })
        let source = LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse)
        let manager = LocationManager(manager: source, onUpdate: { _ in .accepted })
        let resolver = ControlledResolver()
        let session = LocationSession(locationClient: client, locationManager: manager,
                                      locationContextResolver: resolver,
                                      locationUploadCoordinator: NoOpLocationUploadCoordinator())
        session.handleScenePhaseChange(.active)
        session.startupState = .failed("location-timeout")
        var iterator = subscribed.stream.makeAsyncIterator()
        _ = await iterator.next()
        updates.continuation.yield(context.snapshot)
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .resolve).count == 1 })
        let id = try #require(await resolver.pendingIDs(for: .resolve).first)
        updates.continuation.yield(context.snapshot)
        source.stubStatus = .denied
        manager.locationManagerDidChangeAuthorization(source)
        try #require(await waitUntilAsync { session.authorizationStatus == .denied })
        await resolver.complete(id: id, with: .success(context))
        #expect(await waitUntilAsync { session.startupState == .failed("location-unavailable") })
        #expect(session.currentContext == nil)
        #expect(await resolver.pendingIDs(for: .resolve).isEmpty)
    }

    @MainActor
    @Test("pending fix resumes after the scene returns active")
    func pendingFixResumesAfterForegroundReturn() async throws {
        let first = durableContext(timestamp: .now.addingTimeInterval(-1), h3Cell: 1)
        let second = durableContext(timestamp: .now, h3Cell: 2)
        let updates = AsyncStream<LocationSnapshot>.makeStream()
        defer { updates.continuation.finish() }
        let subscribed = AsyncStream<Void>.makeStream()
        let client = LocationClient(snapshot: { nil }, updates: {
            subscribed.continuation.yield(())
            return updates.stream
        })
        let manager = LocationManager(manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
                                      onUpdate: { _ in .accepted })
        let resolver = ControlledResolver()
        let session = LocationSession(locationClient: client, locationManager: manager,
                                      locationContextResolver: resolver,
                                      locationUploadCoordinator: NoOpLocationUploadCoordinator())
        session.handleScenePhaseChange(.active)
        session.startupState = .failed("location-timeout")
        var iterator = subscribed.stream.makeAsyncIterator()
        _ = await iterator.next()
        updates.continuation.yield(first.snapshot)
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .resolve).count == 1 })
        let firstID = try #require(await resolver.pendingIDs(for: .resolve).first)
        updates.continuation.yield(second.snapshot)
        try #require(await waitUntilAsync { session.currentSnapshot == second.snapshot })
        session.handleScenePhaseChange(.inactive)
        await resolver.complete(id: firstID, with: .failure(.locationTimeout))
        try #require(await waitUntilAsync { session.startupState == .failed("location-timeout") })
        session.handleScenePhaseChange(.active)
        try #require(await waitUntilAsync { await resolver.pendingIDs(for: .resolve).count == 1 })
        let secondID = try #require(await resolver.pendingIDs(for: .resolve).first)
        await resolver.complete(id: secondID, with: .success(second))
        #expect(await waitUntilAsync { session.currentContext == second && session.startupState == .ready })
    }

    @MainActor
    @Test("new explicit preparation invalidates an older snapshot-driven resolution")
    func explicitPreparationInvalidatesOlderSnapshotDrivenResolution() async {
        let initialContext = durableContext(timestamp: .now.addingTimeInterval(-60), h3Cell: 1)
        let newerContext = durableContext(timestamp: .now, h3Cell: 2)
        let updates = AsyncStream<LocationSnapshot>.makeStream()
        defer { updates.continuation.finish() }
        let updatesSubscription = AsyncStream<Void>.makeStream()
        let locationClient = LocationClient(
            snapshot: { initialContext.snapshot },
            updates: {
                updatesSubscription.continuation.yield(())
                return updates.stream
            }
        )
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )
        let resolver = ControlledResolver()
        let session = LocationSession(
            locationClient: locationClient,
            locationManager: manager,
            locationContextResolver: resolver,
            locationUploadCoordinator: NoOpLocationUploadCoordinator()
        )
        session.currentSnapshot = initialContext.snapshot
        session.currentContext = initialContext
        session.startupState = .ready
        session.handleScenePhaseChange(.active)

        var subscriptionIterator = updatesSubscription.stream.makeAsyncIterator()
        _ = await subscriptionIterator.next()
        updatesSubscription.continuation.finish()

        let movedSnapshot = newerContext.snapshot
        updates.continuation.yield(movedSnapshot)
        let oldResolutionStarted = await waitUntilAsync(timeout: .seconds(10)) {
            await resolver.pendingIDs(for: .resolve).count == 1
        }
        guard oldResolutionStarted,
              let oldRequestID = await resolver.pendingIDs(for: .resolve).first else {
            Issue.record("The snapshot-driven context resolution did not start before the timeout.")
            return
        }

        let newPreparation = Task {
            await session.prepareCurrentLocationContext(
                requiresFreshLocation: true,
                showsAuthorizationPrompt: false
            )
        }
        let newPreparationStarted = await waitUntilAsync(timeout: .seconds(10)) {
            await resolver.pendingIDs(for: .prepare).count == 1
        }
        guard newPreparationStarted,
              let newRequestID = await resolver.pendingIDs(for: .prepare).first else {
            Issue.record("The explicit context preparation did not start before the timeout.")
            return
        }
        await resolver.complete(id: newRequestID, with: .success(newerContext))
        #expect(await newPreparation.value == newerContext)

        await resolver.complete(id: oldRequestID, with: .failure(.locationTimeout))
        for _ in 0..<5 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(20))

        #expect(session.currentContext == newerContext)
        #expect(session.startupState == .ready)
    }

    @MainActor
    @Test("syncNotificationPreference enqueues forced preference sync")
    func syncNotificationPreference_enqueuesForcedPreferenceSync() async throws {
        let provider = LocationProvider()
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )

        let context = LocationContext(
            snapshot: LocationSnapshot(
                coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
                timestamp: Date(timeIntervalSince1970: 1_234_567),
                accuracy: 20,
                placemarkSummary: "Denver, CO",
                h3Cell: 0x882681b485fffff
            ),
            h3Cell: 0x882681b485fffff,
            grid: GridPointSnapshot(
                nwsId: "https://api.weather.gov/points/39.7392,-104.9903",
                latitude: 39.7392,
                longitude: -104.9903,
                gridId: "BOU",
                gridX: 56,
                gridY: 66,
                forecastURL: nil,
                forecastHourlyURL: nil,
                forecastGridDataURL: nil,
                observationStationsURL: nil,
                city: "Denver",
                state: "CO",
                timeZoneId: "America/Denver",
                radarStationId: "KFTG",
                forecastZone: "COZ039",
                countyCode: "COC031",
                fireZone: "COZ246",
                countyLabel: "Denver County",
                fireZoneLabel: "East Central Colorado"
            )
        )
        let resolver = StubResolver(context: context, error: nil)
        let uploader = StubUploadCoordinator()
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: resolver,
            locationUploadCoordinator: uploader
        )
        _ = await session.prepareCurrentLocationContext(
            requiresFreshLocation: false,
            showsAuthorizationPrompt: false
        )

        await session.syncNotificationPreference(enabled: true)

        #expect(await uploader.recordedEnqueueCount() == 0)
        #expect(await uploader.recordedPreferenceSyncCount() == 1)
        #expect(await uploader.recordedLastForceUpload() == true)
        #expect(await uploader.recordedLastSource() == .settingsPreference)
        #expect(await uploader.recordedLastReason() == .preferenceChanged)
        #expect(await uploader.recordedLastPreferenceIsSubscribedOverride() == true)
        #expect(session.currentContext == context)
    }

    @MainActor
    @Test("syncLocationSharingPreference enqueues forced preference sync without resolving context")
    func syncLocationSharingPreference_enqueuesForcedPreferenceSyncWithoutResolvingContext() async throws {
        let provider = LocationProvider()
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )

        let context = LocationContext(
            snapshot: LocationSnapshot(
                coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
                timestamp: Date(timeIntervalSince1970: 1_234_567),
                accuracy: 20,
                placemarkSummary: "Denver, CO",
                h3Cell: 0x882681b485fffff
            ),
            h3Cell: 0x882681b485fffff,
            grid: GridPointSnapshot(
                nwsId: "https://api.weather.gov/points/39.7392,-104.9903",
                latitude: 39.7392,
                longitude: -104.9903,
                gridId: "BOU",
                gridX: 56,
                gridY: 66,
                forecastURL: nil,
                forecastHourlyURL: nil,
                forecastGridDataURL: nil,
                observationStationsURL: nil,
                city: "Denver",
                state: "CO",
                timeZoneId: "America/Denver",
                radarStationId: "KFTG",
                forecastZone: "COZ039",
                countyCode: "COC031",
                fireZone: "COZ246",
                countyLabel: "Denver County",
                fireZoneLabel: "East Central Colorado"
            )
        )
        let resolver = StubResolver(context: context, error: nil)
        let uploader = StubUploadCoordinator()
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: resolver,
            locationUploadCoordinator: uploader
        )

        // This path should not resolve context; snapshot presence is irrelevant.
        session.currentSnapshot = context.snapshot
        session.currentContext = nil

        await session.syncLocationSharingPreference(enabled: false)

        #expect(await uploader.recordedEnqueueCount() == 0)
        #expect(await uploader.recordedPreferenceSyncCount() == 1)
        #expect(await uploader.recordedLastForceUpload() == true)
        #expect(await uploader.recordedLastSource() == .settingsPreference)
        #expect(await uploader.recordedLastReason() == .preferenceChanged)
        #expect(await uploader.recordedLastPreferenceReason() == "location-sharing")
        #expect(await uploader.recordedLastPreferenceIsSubscribedOverride() == nil)
        #expect(await resolver.recordedPrepareCallCount() == 0)
        #expect(await resolver.recordedResolveCallCount() == 0)
        #expect(session.currentContext == nil)
    }

    @MainActor
    @Test("updateLocationSharingPreference when enabling requests always upgrade and emits one forced settings sync")
    func updateLocationSharingPreference_whenEnabling_requestsAlwaysUpgradeAndEmitsSingleForcedSettingsSync() async throws {
        let provider = LocationProvider()
        let authManager = LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse)
        let manager = LocationManager(manager: authManager, onUpdate: { _ in .accepted })
        let context = LocationContext(
            snapshot: LocationSnapshot(
                coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
                timestamp: Date(timeIntervalSince1970: 1_234_567),
                accuracy: 20,
                placemarkSummary: "Denver, CO",
                h3Cell: 0x882681b485fffff
            ),
            h3Cell: 0x882681b485fffff,
            grid: GridPointSnapshot(
                nwsId: "https://api.weather.gov/points/39.7392,-104.9903",
                latitude: 39.7392,
                longitude: -104.9903,
                gridId: "BOU",
                gridX: 56,
                gridY: 66,
                forecastURL: nil,
                forecastHourlyURL: nil,
                forecastGridDataURL: nil,
                observationStationsURL: nil,
                city: "Denver",
                state: "CO",
                timeZoneId: "America/Denver",
                radarStationId: "KFTG",
                forecastZone: "COZ039",
                countyCode: "COC031",
                fireZone: "COZ246",
                countyLabel: "Denver County",
                fireZoneLabel: "East Central Colorado"
            )
        )
        let uploader = StubUploadCoordinator()
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: StubResolver(context: context, error: nil),
            locationUploadCoordinator: uploader
        )
        _ = await session.prepareCurrentLocationContext(
            requiresFreshLocation: false,
            showsAuthorizationPrompt: false
        )

        await session.updateLocationSharingPreference(enabled: true)

        #expect(authManager.requestAlwaysCount == 1)
        #expect(await uploader.recordedEnqueueCount() == 0)
        #expect(await uploader.recordedPreferenceSyncCount() == 1)
        #expect(await uploader.recordedLastForceUpload() == true)
        #expect(await uploader.recordedLastSource() == .settingsPreference)
        #expect(await uploader.recordedLastReason() == .preferenceChanged)
        #expect(await uploader.recordedLastPreferenceReason() == "location-sharing")
        #expect(await uploader.recordedLastPreferenceIsSubscribedOverride() == nil)
    }

    @MainActor
    @Test("updateLocationSharingPreference when disabling syncs preference without requesting always upgrade")
    func updateLocationSharingPreference_whenDisabling_syncsPreferenceWithoutRequestingAlwaysUpgrade() async throws {
        let provider = LocationProvider()
        let authManager = LocationManagerTests.StubAuthorizationManager(status: .authorizedAlways)
        let manager = LocationManager(manager: authManager, onUpdate: { _ in .accepted })
        let resolver = StubResolver(context: nil, error: .locationTimeout)
        let uploader = StubUploadCoordinator()
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: resolver,
            locationUploadCoordinator: uploader
        )

        try await Task.sleep(for: .milliseconds(20))
        session.currentContext = nil
        session.currentSnapshot = nil

        await session.updateLocationSharingPreference(enabled: false)

        #expect(authManager.requestAlwaysCount == 0)
        #expect(await uploader.recordedEnqueueCount() == 0)
        #expect(await uploader.recordedPreferenceSyncCount() == 1)
        #expect(await uploader.recordedLastForceUpload() == true)
        #expect(await uploader.recordedLastSource() == .settingsPreference)
        #expect(await uploader.recordedLastReason() == .preferenceChanged)
        #expect(await uploader.recordedLastPreferenceReason() == "location-sharing")
        #expect(await uploader.recordedLastPreferenceIsSubscribedOverride() == nil)
    }

    @MainActor
    @Test("syncLocationSharingPreference with no context or snapshot queues durable preference sync")
    func syncLocationSharingPreference_withoutContextOrSnapshot_queuesPreferenceSync() async throws {
        let provider = LocationProvider()
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )
        let resolver = StubResolver(context: nil, error: .locationTimeout)
        let uploader = StubUploadCoordinator()
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: resolver,
            locationUploadCoordinator: uploader
        )

        try await Task.sleep(for: .milliseconds(20))
        session.currentContext = nil
        session.currentSnapshot = nil

        await session.syncLocationSharingPreference(enabled: false)

        #expect(await uploader.recordedEnqueueCount() == 0)
        #expect(await uploader.recordedPreferenceSyncCount() == 1)
        #expect(await uploader.recordedLastForceUpload() == true)
        #expect(await uploader.recordedLastSource() == .settingsPreference)
        #expect(await uploader.recordedLastReason() == .preferenceChanged)
        #expect(await uploader.recordedLastPreferenceReason() == "location-sharing")
        #expect(await uploader.recordedLastPreferenceIsSubscribedOverride() == nil)
    }

    @MainActor
    @Test("syncNotificationPreference with no context or snapshot queues durable preference sync")
    func syncNotificationPreference_withoutContextOrSnapshot_queuesPreferenceSync() async throws {
        let provider = LocationProvider()
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )
        let resolver = StubResolver(context: nil, error: .locationTimeout)
        let uploader = StubUploadCoordinator()
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: resolver,
            locationUploadCoordinator: uploader
        )

        try await Task.sleep(for: .milliseconds(20))
        session.currentContext = nil
        session.currentSnapshot = nil

        await session.syncNotificationPreference(enabled: false)

        #expect(await uploader.recordedEnqueueCount() == 0)
        #expect(await uploader.recordedPreferenceSyncCount() == 1)
        #expect(await uploader.recordedLastForceUpload() == true)
        #expect(await uploader.recordedLastSource() == .settingsPreference)
        #expect(await uploader.recordedLastReason() == .preferenceChanged)
        #expect(await uploader.recordedLastPreferenceReason() == "notification")
        #expect(await uploader.recordedLastPreferenceIsSubscribedOverride() == false)
    }

    @MainActor
    @Test("enqueueCurrentLocationUpload resolves from snapshot and enqueues non-forced upload once")
    func enqueueCurrentLocationUpload_resolvesFromSnapshotAndEnqueuesOnce() async throws {
        let provider = LocationProvider()
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )

        let context = LocationContext(
            snapshot: LocationSnapshot(
                coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
                timestamp: Date(timeIntervalSince1970: 1_234_567),
                accuracy: 20,
                placemarkSummary: "Denver, CO",
                h3Cell: 0x882681b485fffff
            ),
            h3Cell: 0x882681b485fffff,
            grid: GridPointSnapshot(
                nwsId: "https://api.weather.gov/points/39.7392,-104.9903",
                latitude: 39.7392,
                longitude: -104.9903,
                gridId: "BOU",
                gridX: 56,
                gridY: 66,
                forecastURL: nil,
                forecastHourlyURL: nil,
                forecastGridDataURL: nil,
                observationStationsURL: nil,
                city: "Denver",
                state: "CO",
                timeZoneId: "America/Denver",
                radarStationId: "KFTG",
                forecastZone: "COZ039",
                countyCode: "COC031",
                fireZone: "COZ246",
                countyLabel: "Denver County",
                fireZoneLabel: "East Central Colorado"
            )
        )
        let resolver = StubResolver(context: context, error: nil)
        let uploader = StubUploadCoordinator()
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: resolver,
            locationUploadCoordinator: uploader
        )

        try await Task.sleep(for: .milliseconds(20))
        session.currentSnapshot = context.snapshot
        session.currentContext = nil

        await session.enqueueCurrentLocationUpload(source: .settingsPreference, reason: .preferenceChanged)

        #expect(await uploader.recordedEnqueueCount() == 1)
        #expect(await uploader.recordedLastForceUpload() == false)
        #expect(await uploader.recordedLastSource() == .settingsPreference)
        #expect(await uploader.recordedLastReason() == .preferenceChanged)
        #expect(session.currentContext == context)
    }

    @MainActor
    @Test("drainPendingLocationUploads forwards to upload coordinator")
    func drainPendingLocationUploads_forwardsToCoordinator() async throws {
        let provider = LocationProvider()
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )
        let resolver = StubResolver(context: nil, error: .locationTimeout)
        let uploader = StubUploadCoordinator()
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: resolver,
            locationUploadCoordinator: uploader
        )

        await session.drainPendingLocationUploads()

        #expect(await uploader.recordedDrainCount() == 1)
    }

    @MainActor
    @Test("equal timestamp enrichment preserves location identity and accepted names",
          arguments: ["matching", "coordinates", "cell", "older", "named", "namedCoordinates", "namedCell", "blank"])
    func scheduledReuse_equalTimestampMetadata(variant: String) async throws {
        let timestamp = Date(timeIntervalSince1970: floor(Date.now.timeIntervalSince1970) - 60)
        let suiteName = "LocationSessionTests.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let cache = DurableLocationContextCache(suiteName: suiteName)
        let context = durableContext(timestamp: timestamp)
        cache.save(context)
        if variant.hasPrefix("named") {
            var accepted = context.snapshot
            accepted.placemarkSummary = "Accepted name"
            LocationSnapshotCache(suiteName: suiteName).save(accepted)
        }
        let providerSnapshot = LocationSnapshot(
            coordinates: .init(latitude: ["coordinates", "namedCoordinates"].contains(variant) ? 40 : context.snapshot.coordinates.latitude,
                               longitude: context.snapshot.coordinates.longitude),
            timestamp: variant == "older" ? timestamp.addingTimeInterval(-1) : timestamp,
            accuracy: context.snapshot.accuracy,
            placemarkSummary: variant == "blank" ? "  " : "Bennett, CO",
            h3Cell: ["cell", "namedCell"].contains(variant) ? 2 : context.h3Cell
        )
        let resolver = StubResolver(context: nil, error: .locationTimeout)
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse), onUpdate: { _ in .accepted }
        )
        let session = LocationSession(
            locationClient: .init(snapshot: { providerSnapshot }, updates: { AsyncStream { $0.finish() } }),
            locationManager: manager, locationContextResolver: resolver,
            locationUploadCoordinator: NoOpLocationUploadCoordinator(), durableContextCache: cache
        )
        let result = try #require(await session.prepareScheduledBackgroundLocationContext(
            uploadSource: nil, uploadReason: nil, authorizationTimeout: 1, locationTimeout: 1,
            maximumAcceptedLocationAge: 60, placemarkTimeout: 1
        ))
        let expected: String? = variant == "matching" ? "Bennett, CO" : (variant.hasPrefix("named") ? "Accepted name" : nil)
        #expect(result.snapshot.placemarkSummary == expected)
        #expect(result.snapshot.timestamp == timestamp)
        #expect(result.snapshot.coordinates.latitude == context.snapshot.coordinates.latitude)
        #expect(result.h3Cell == context.h3Cell)
        #expect(await resolver.recordedPrepareCallCount() == 0)
    }

    @MainActor
    @Test("restored accepted names follow the 90 minute policy and authorization",
          arguments: ["eligible", "stale", "denied", "invalidated"])
    func scheduledReuse_restoredNamePolicy(variant: String) async throws {
        let age: TimeInterval = variant == "stale" ? 91 * 60 : 70 * 60
        let timestamp = Date(timeIntervalSince1970: floor(Date.now.timeIntervalSince1970) - age)
        let suiteName = "LocationSessionTests.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let context = durableContext(timestamp: timestamp)
        var accepted = context.snapshot
        accepted.placemarkSummary = "Bennett, CO"
        LocationSnapshotCache(suiteName: suiteName).save(accepted)
        DurableLocationContextCache(suiteName: suiteName).save(context)
        let cache = DurableLocationContextCache(suiteName: suiteName)
        if variant == "invalidated" { cache.invalidate() }
        let provider = LocationProvider(snapshotCache: LocationSnapshotCache(suiteName: suiteName))
        #expect(await provider.snapshot() == nil)
        let resolver = StubResolver(context: nil, error: .locationTimeout)
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(
                status: variant == "denied" ? .denied : .authorizedWhenInUse
            ), onUpdate: { _ in .accepted }
        )
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider), locationManager: manager,
            locationContextResolver: resolver, locationUploadCoordinator: NoOpLocationUploadCoordinator(),
            durableContextCache: cache
        )
        let result = await session.prepareScheduledBackgroundLocationContext(
            uploadSource: nil, uploadReason: nil, authorizationTimeout: 1, locationTimeout: 1,
            maximumAcceptedLocationAge: 60, placemarkTimeout: 1
        )
        if variant == "eligible" {
            #expect(result?.snapshot.placemarkSummary == "Bennett, CO")
            #expect(result?.snapshot.timestamp == timestamp)
        } else {
            #expect(result == nil)
        }
        #expect(await resolver.recordedPrepareCallCount() == 0)
    }

    @MainActor
    @Test("scheduled reuse evaluates a fresh same-cell composite instead of a stale durable snapshot")
    func scheduledReuse_evaluatesFreshSameCellComposite() async throws {
        let now = Date()
        let suiteName = "LocationSessionTests.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let durableCache = DurableLocationContextCache(suiteName: suiteName, nowProvider: { now })
        let cachedContext = durableContext(timestamp: now.addingTimeInterval(-2 * 60 * 60))
        durableCache.save(cachedContext)
        let freshSnapshot = LocationSnapshot(
            coordinates: cachedContext.snapshot.coordinates,
            timestamp: now,
            accuracy: 20,
            placemarkSummary: nil,
            h3Cell: cachedContext.h3Cell
        )
        let providerClient = LocationClient(
            snapshot: { freshSnapshot },
            updates: { AsyncStream { $0.finish() } }
        )
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )
        let resolver = StubResolver(context: nil, error: .locationTimeout)
        let session = LocationSession(
            locationClient: providerClient,
            locationManager: manager,
            locationContextResolver: resolver,
            locationUploadCoordinator: NoOpLocationUploadCoordinator(),
            durableContextCache: durableCache
        )

        let result = await session.prepareScheduledBackgroundLocationContext(
            uploadSource: nil,
            uploadReason: nil,
            authorizationTimeout: 1,
            locationTimeout: 1,
            maximumAcceptedLocationAge: 60,
            placemarkTimeout: 1
        )

        #expect(result?.snapshot == freshSnapshot)
        #expect(result?.grid == cachedContext.grid)
        #expect(await resolver.recordedPrepareCallCount() == 0)
        let persistedSnapshot = durableCache.load()?.snapshot
        #expect(persistedSnapshot?.coordinates.latitude == freshSnapshot.coordinates.latitude)
        #expect(persistedSnapshot?.coordinates.longitude == freshSnapshot.coordinates.longitude)
        #expect(persistedSnapshot?.accuracy == freshSnapshot.accuracy)
        #expect(abs((persistedSnapshot?.timestamp.timeIntervalSince(freshSnapshot.timestamp)) ?? .infinity) < 1)
    }

    @MainActor
    @Test("scheduled reuse retains an eligible durable context when a same-cell composite is invalid")
    func scheduledReuse_fallsBackWhenSameCellCompositeIsInvalid() async throws {
        let now = Date()
        let suiteName = "LocationSessionTests.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let durableCache = DurableLocationContextCache(suiteName: suiteName, nowProvider: { now })
        let cachedContext = durableContext(timestamp: now.addingTimeInterval(-60))
        durableCache.save(cachedContext)
        let inaccurateSnapshot = LocationSnapshot(
            coordinates: cachedContext.snapshot.coordinates,
            timestamp: now,
            accuracy: BackgroundLocationContextReusePolicy.maximumHorizontalAccuracy + 1,
            placemarkSummary: nil,
            h3Cell: cachedContext.h3Cell
        )
        let providerClient = LocationClient(
            snapshot: { inaccurateSnapshot },
            updates: { AsyncStream { $0.finish() } }
        )
        let manager = LocationManager(
            manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse),
            onUpdate: { _ in .accepted }
        )
        let resolver = StubResolver(context: nil, error: .locationTimeout)
        let session = LocationSession(
            locationClient: providerClient,
            locationManager: manager,
            locationContextResolver: resolver,
            locationUploadCoordinator: NoOpLocationUploadCoordinator(),
            durableContextCache: durableCache
        )

        let result = await session.prepareScheduledBackgroundLocationContext(
            uploadSource: nil,
            uploadReason: nil,
            authorizationTimeout: 1,
            locationTimeout: 1,
            maximumAcceptedLocationAge: 60,
            placemarkTimeout: 1
        )

        #expect(result?.snapshot.coordinates.latitude == cachedContext.snapshot.coordinates.latitude)
        #expect(result?.snapshot.coordinates.longitude == cachedContext.snapshot.coordinates.longitude)
        #expect(result?.snapshot.accuracy == cachedContext.snapshot.accuracy)
        #expect(abs((result?.snapshot.timestamp.timeIntervalSince(cachedContext.snapshot.timestamp)) ?? .infinity) < 1)
        #expect(result?.grid == cachedContext.grid)
        #expect(await resolver.recordedPrepareCallCount() == 0)
        let persistedContext = durableCache.load()
        #expect(persistedContext?.snapshot.coordinates.latitude == cachedContext.snapshot.coordinates.latitude)
        #expect(persistedContext?.snapshot.coordinates.longitude == cachedContext.snapshot.coordinates.longitude)
        #expect(persistedContext?.snapshot.accuracy == cachedContext.snapshot.accuracy)
        #expect(
            abs((persistedContext?.snapshot.timestamp.timeIntervalSince(cachedContext.snapshot.timestamp)) ?? .infinity)
                < 1
        )
        #expect(persistedContext?.grid == cachedContext.grid)
    }

    @MainActor
    @Test("scheduled reuse reads a newer moved provider snapshot before policy evaluation")
    func scheduledReuse_readsMovedProviderSnapshotBeforePolicyEvaluation() async throws {
        let now = Date()
        let suiteName = "LocationSessionTests.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let durableCache = DurableLocationContextCache(suiteName: suiteName, nowProvider: { now })
        let cachedContext = durableContext(timestamp: now.addingTimeInterval(-60))
        durableCache.save(cachedContext)
        let movedSnapshot = LocationSnapshot(coordinates: .init(latitude: 40, longitude: -105), timestamp: now, accuracy: 20, placemarkSummary: nil, h3Cell: 2)
        let providerClient = LocationClient(snapshot: { movedSnapshot }, updates: { AsyncStream { $0.finish() } })
        let manager = LocationManager(manager: LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse), onUpdate: { _ in .accepted })
        let resolver = StubResolver(context: nil, error: .locationTimeout)
        let session = LocationSession(locationClient: providerClient, locationManager: manager, locationContextResolver: resolver, locationUploadCoordinator: NoOpLocationUploadCoordinator(), durableContextCache: durableCache)
        session.currentSnapshot = nil

        let result = await session.prepareScheduledBackgroundLocationContext(uploadSource: nil, uploadReason: nil, authorizationTimeout: 1, locationTimeout: 1, maximumAcceptedLocationAge: 60, placemarkTimeout: 1)

        #expect(result == nil)
        #expect(await resolver.recordedPrepareCallCount() == 0)
        #expect(durableCache.load() == nil)
    }

    @MainActor
    @Test("reliability state reflects authorization and accuracy updates")
    func reliabilityState_reflectsAuthorizationAndAccuracy() async throws {
        let provider = LocationProvider()
        let manager = LocationManagerTests.StubAuthorizationManager(
            status: .authorizedWhenInUse,
            accuracy: .reducedAccuracy
        )
        let locationManager = LocationManager(manager: manager, onUpdate: { _ in .accepted })
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: locationManager,
            locationContextResolver: StubResolver(context: nil, error: .locationUnavailable),
            locationUploadCoordinator: NoOpLocationUploadCoordinator()
        )

        #expect(session.authorizationStatus == .authorizedWhenInUse)
        #expect(session.accuracyAuthorization == .reducedAccuracy)
        #expect(session.reliabilityState.authorization == .whileUsing)
        #expect(session.reliabilityState.accuracy == .reduced)

        manager.stubStatus = .authorizedAlways
        manager.stubAccuracy = .fullAccuracy
        locationManager.locationManagerDidChangeAuthorization(manager)
        try await Task.sleep(for: .milliseconds(20))

        #expect(session.authorizationStatus == .authorizedAlways)
        #expect(session.accuracyAuthorization == .fullAccuracy)
        #expect(session.reliabilityState.authorization == .always)
        #expect(session.reliabilityState.accuracy == .precise)
    }
}

@Suite("LocationReliabilityState")
struct LocationReliabilityStateTests {
    @Test("maps authorization and accuracy combinations used by reliability surfaces")
    func mapsAuthorizationAndAccuracyMatrix() {
        let samples: [(CLAuthorizationStatus, CLAccuracyAuthorization?, LocationReliabilityAuthorization, LocationReliabilityAccuracy)] = [
            (.authorizedAlways, .fullAccuracy, .always, .precise),
            (.authorizedAlways, .reducedAccuracy, .always, .reduced),
            (.authorizedWhenInUse, .fullAccuracy, .whileUsing, .precise),
            (.authorizedWhenInUse, .reducedAccuracy, .whileUsing, .reduced),
            (.denied, nil, .denied, .unknown),
            (.restricted, nil, .restricted, .unknown),
            (.notDetermined, nil, .notDetermined, .unknown)
        ]

        for sample in samples {
            let state = LocationReliabilityState(
                authorizationStatus: sample.0,
                accuracyAuthorization: sample.1
            )

            #expect(state.authorization == sample.2)
            #expect(state.accuracy == sample.3)
        }
    }

    @Test("maps while-using plus precise accuracy")
    func mapsWhileUsingPrecise() {
        let state = LocationReliabilityState(
            authorizationStatus: .authorizedWhenInUse,
            accuracyAuthorization: .fullAccuracy
        )

        #expect(state.authorization == .whileUsing)
        #expect(state.accuracy == .precise)
        #expect(state.nextAction == .requestAlwaysUpgrade)
    }

    @Test("maps always plus reduced accuracy")
    func mapsAlwaysReducedAccuracy() {
        let state = LocationReliabilityState(
            authorizationStatus: .authorizedAlways,
            accuracyAuthorization: .reducedAccuracy
        )

        #expect(state.authorization == .always)
        #expect(state.accuracy == .reduced)
        #expect(state.nextAction == .openSettings)
    }

    @Test("maps missing accuracy as unknown")
    func mapsMissingAccuracyAsUnknown() {
        let state = LocationReliabilityState(
            authorizationStatus: .denied,
            accuracyAuthorization: nil
        )

        #expect(state.authorization == .denied)
        #expect(state.accuracy == .unknown)
        #expect(state.nextAction == .openSettings)
    }

    @Test("settings copy and action for always plus precise")
    func settingsPresentation_alwaysPrecise() {
        let state = LocationReliabilityState(authorization: .always, accuracy: .precise)

        #expect(state.settingsAuthorizationText == "Always")
        #expect(state.settingsAccuracyText == "Precise")
        #expect(state.settingsReliabilityCopy == "Background alerts are set up for the best reliability.")
        #expect(state.settingsAction == .none)
        #expect(state.settingsActionTitle == nil)
    }

    @Test("settings copy and action for always plus reduced accuracy")
    func settingsPresentation_alwaysReduced() {
        let state = LocationReliabilityState(authorization: .always, accuracy: .reduced)

        #expect(state.settingsAuthorizationText == "Always")
        #expect(state.settingsAccuracyText == "Reduced")
        #expect(state.settingsReliabilityCopy == "Background alerts are enabled. Precise Location can make alerts more accurate for your area.")
        #expect(state.settingsAction == .openSettings)
        #expect(state.settingsActionTitle == "Open Settings")
    }

    @Test("settings copy and action for while using plus precise")
    func settingsPresentation_whileUsingPrecise() {
        let state = LocationReliabilityState(authorization: .whileUsing, accuracy: .precise)

        #expect(state.settingsAuthorizationText == "While Using")
        #expect(state.settingsAccuracyText == "Precise")
        #expect(state.settingsReliabilityCopy == "SkyAware can alert while you are using the app. Enable Always for more reliable background alerts.")
        #expect(state.settingsAction == .openSettings)
        #expect(state.settingsActionTitle == "Enable Always")
    }

    @Test("settings copy and action for while using plus reduced accuracy")
    func settingsPresentation_whileUsingReduced() {
        let state = LocationReliabilityState(authorization: .whileUsing, accuracy: .reduced)

        #expect(state.settingsAuthorizationText == "While Using")
        #expect(state.settingsAccuracyText == "Reduced")
        #expect(state.settingsReliabilityCopy == "SkyAware can alert while you are using the app. Enable Always and Precise Location for more reliable alerts.")
        #expect(state.settingsAction == .openSettings)
        #expect(state.settingsActionTitle == "Enable Always")
    }

    @Test("settings copy and action for denied and restricted")
    func settingsPresentation_deniedAndRestricted() {
        let denied = LocationReliabilityState(authorization: .denied, accuracy: .unknown)
        let restricted = LocationReliabilityState(authorization: .restricted, accuracy: .unknown)

        #expect(denied.settingsAuthorizationText == "Off")
        #expect(restricted.settingsAuthorizationText == "Restricted")
        #expect(denied.settingsReliabilityCopy == "Location is off for SkyAware. Enable location to receive alerts for your area.")
        #expect(restricted.settingsReliabilityCopy == "Location is off for SkyAware. Enable location to receive alerts for your area.")
        #expect(denied.settingsAction == .openSettings)
        #expect(restricted.settingsAction == .openSettings)
        #expect(denied.settingsActionTitle == "Open Settings")
    }

    @Test("settings copy and action for not determined")
    func settingsPresentation_notDetermined() {
        let state = LocationReliabilityState(authorization: .notDetermined, accuracy: .unknown)

        #expect(state.settingsAuthorizationText == "Not Set")
        #expect(state.settingsAccuracyText == "Unknown")
        #expect(state.settingsReliabilityCopy == "Choose how SkyAware can use location to send alerts for your area.")
        #expect(state.settingsAction == .requestWhenInUse)
        #expect(state.settingsActionTitle == "Enable Location")
    }
}
