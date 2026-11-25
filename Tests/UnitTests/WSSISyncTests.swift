import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import SkyAware

@Suite
struct WSSISyncTests {
    @Test @MainActor func discoveryOnlyOffersForUnansweredReturningUsers() throws {
        let suite = "WinterImpactsDiscoveryTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = WinterImpactsPreferenceController(defaults: defaults, service: nil)

        func offersDiscovery(onboardingComplete: Bool = true) throws -> Bool {
            let reopenedDefaults = try #require(UserDefaults(suiteName: suite))
            let preference = WinterImpactsPreference(defaults: reopenedDefaults)
            return WinterImpactsPreference.offersDiscovery(
                onboardingComplete: onboardingComplete,
                choice: preference.choice,
                dismissed: preference.discoveryDismissed
            )
        }

        #expect(try !offersDiscovery(onboardingComplete: false))
        #expect(try offersDiscovery())

        controller.setChoice(false)
        #expect(try !offersDiscovery())
        controller.setChoice(true)
        #expect(try !offersDiscovery())

        defaults.removeObject(forKey: WinterImpactsPreference.enabledKey)
        controller.preference.dismissDiscovery()
        #expect(try !offersDiscovery())
        #expect(controller.preference.choice == nil)
    }

    @Test @MainActor func settingsTogglePreservesUnansweredChoice() throws {
        let suite = "WinterImpactsSettingsTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = WinterImpactsPreferenceController(defaults: defaults, service: nil)
        let toggle = WinterImpactsSettingsToggle(defaults: defaults, controller: controller)
        #expect(ImageRenderer(content: toggle).uiImage != nil)
        #expect(controller.preference.choice == nil)
        #expect(toggle.binding.wrappedValue == false)
        toggle.binding.wrappedValue = false
        #expect(controller.preference.choice == false)
        toggle.binding.wrappedValue = true
        #expect(controller.preference.choice == true)
    }
    @Test @MainActor func preferenceRevisionFencesSuspendedAssessment() async throws {
        let hold = SyncGate()
        let gate = WinterImpactsAdmission(enabled: true)
        var checks = 0
        let location = WSSIAcceptedAssessment.Location(point: .init(latitude: 0, longitude: 0), h3Cell: 1, observedAt: .now)
        let foreground = WSSIForeground(
            client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!,
                                    http: SyncHTTP { _, _ in throw URLError(.notConnectedToInternet) }),
            container: try container(nil), enabled: true, preferenceAdmission: gate,
            currentLocation: {
                checks += 1
                if checks == 1 { await hold.suspend() }
                return location
            }
        )
        let read = Task { try await foreground.assessment(at: .now) }
        await hold.waitUntilSuspended()
        gate.update(false)
        gate.update(true)
        await hold.release()
        #expect(try await read.value == nil)
    }
    @Test @MainActor func disabledPreferenceFencesQueuedOffer() async throws {
        let suite = "WinterImpactsFenceTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: WinterImpactsPreference.enabledKey)
        let http = SyncHTTP { _, _ in
            Issue.record("Disabled preference admitted a request")
            throw URLError(.notConnectedToInternet)
        }
        let gate = WinterImpactsAdmission(enabled: true)
        let service = WSSIForeground(
            client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!, http: http),
            container: try container(nil), enabled: true, preferenceAdmission: gate, currentLocation: { nil }
        )
        gate.update(false)
        await service.offerRefresh()
        await service.waitForRefresh()
        #expect(await http.requests.isEmpty)
    }
    @Test @MainActor func preferencePersistsChoicesAndPreservesOtherSettings() throws {
        let suite = "WinterImpactsPreferenceTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "stormSetupEnabled")
        let controller = WinterImpactsPreferenceController(defaults: defaults, service: nil)
        #expect(controller.preference.choice == nil)
        #expect(!controller.preference.isEnabled)
        controller.setChoice(false)
        #expect(WinterImpactsPreference(defaults: defaults).choice == false)
        controller.setChoice(true)
        #expect(WinterImpactsPreference(defaults: defaults).isEnabled)
        controller.preference.dismissDiscovery()
        #expect(WinterImpactsPreference(defaults: defaults).discoveryDismissed)
        #expect(defaults.bool(forKey: "stormSetupEnabled"))
    }

    @Test @MainActor func rapidPreferenceChangesCancelOldRefresh() async throws {
        let suite = "WinterImpactsAdmissionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: WinterImpactsPreference.enabledKey)
        let gate = SyncGate()
        let http = SyncHTTP { _, index in
            if index == 0 { await gate.suspend() }
            return .init(status: 503, headers: [:], data: nil)
        }
        let runtime = WinterImpactsRuntime(
            defaults: defaults, origin: URL(string: "https://wssi.example.test")!, container: try container(nil),
            makeClient: { ForgeWSSIClient(origin: $0, http: http) }, currentLocation: { nil }
        )
        let service = try #require(runtime.service)
        let controller = runtime.preference
        await service.offerRefresh()
        await gate.waitUntilSuspended()
        controller.setChoice(false)
        controller.setChoice(true)
        await controller.waitForPendingChanges()
        await gate.release()
        await service.waitForRefresh()
        #expect(await http.requests.count == 2)
        #expect(await http.peakInFlight == 1)
        #expect(WinterImpactsPreference(defaults: defaults).isEnabled)
    }

    @Test @MainActor func runtimeRestoresChoiceAndSkipsSupersededEnable() async throws {
        let suite = "WinterImpactsRuntimeTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "stormSetupEnabled")
        let http = SyncHTTP { _, _ in .init(status: 503, headers: [:], data: nil) }
        let modelContainer = try container(nil)
        let origin = URL(string: "https://wssi.example.test")!
        func runtime(_ origin: URL?) -> WinterImpactsRuntime {
            WinterImpactsRuntime(defaults: defaults, origin: origin, container: modelContainer,
                                 makeClient: { ForgeWSSIClient(origin: $0, http: http) }, currentLocation: { nil })
        }
        let fresh = runtime(origin)
        await fresh.service?.offerRefresh()
        await fresh.service?.waitForRefresh()
        #expect(await http.requests.isEmpty)
        fresh.preference.setChoice(true)
        fresh.preference.setChoice(false)
        await fresh.preference.waitForPendingChanges()
        #expect(await http.requests.isEmpty)
        let disabled = runtime(origin)
        await disabled.service?.offerRefresh()
        await disabled.service?.waitForRefresh()
        #expect(await http.requests.isEmpty)
        disabled.preference.setChoice(true)
        await disabled.preference.waitForPendingChanges()
        await disabled.service?.waitForRefresh()
        let count = await http.requests.count
        #expect(count == 1)
        let restored = runtime(origin)
        await restored.service?.offerRefresh()
        await restored.service?.waitForRefresh()
        #expect(await http.requests.count == count + 1)
        let unavailable = runtime(nil)
        #expect(unavailable.service == nil)
        unavailable.preference.setChoice(false)
        await unavailable.preference.waitForPendingChanges()
        #expect(WinterImpactsPreference(defaults: defaults).choice == false)
        #expect(defaults.bool(forKey: "stormSetupEnabled"))
    }

    @Test func initialPreferenceControlsForegroundAdmission() async throws {
        let http = SyncHTTP { _, _ in
            .init(status: 503, headers: [:], data: nil)
        }
        let service = WSSIForeground(
            client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!, http: http),
            container: try container(nil),
            enabled: true,
            currentLocation: { nil }
        )
        await service.offerRefresh()
        await service.waitForRefresh()
        #expect(await http.requests.count > 0)
        await service.setEnabled(false)
        let count = await http.requests.count
        await service.offerRefresh()
        #expect(await http.requests.count == count)
    }

    @Test func backgroundSkipsDisabledAndExhaustedAdmission() async throws {
        let http = SyncHTTP { _, _ in
            Issue.record("WSSI made a request without admission")
            throw URLError(.notConnectedToInternet)
        }
        let service = WSSIForeground(
            client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!, http: http),
            container: try container(nil),
            currentLocation: { nil }
        )
        _ = await backgroundLifecycle(service).run()
        await service.setEnabled(true)
        let expired = BackgroundRefreshBudget.standard(start: .now - BackgroundRefreshBudget.defaultTotalDuration)
        _ = await backgroundLifecycle(service).run(budget: expired)
        #expect(await http.requests.isEmpty)
    }

    @Test func backgroundAcceptsAllSlotsAndRevalidatesAfterReopen() async throws {
        let fixture = SyncFixture()
        let body = try fixture.manifest()
        let http = SyncHTTP { request, index in
            #expect(HTTPExecutionMode.current == .background)
            #expect(BackgroundRefreshExecutionContext.current != nil)
            if index == 16 {
                #expect(request.validator == #""original""#)
                return .init(status: 304, headers: [:], data: nil)
            }
            return try fixture.response(for: request.path, manifest: body)
        }
        let time = try Date.ISO8601FormatStyle().parse("2026-11-24T00:00:00Z")
        let url = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        do {
            let service = WSSIForeground(
                client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!, http: http),
                container: try container(url),
                enabled: true,
                currentLocation: { nil }
            )
            _ = await backgroundLifecycle(service).run()
        }

        let reopened = WSSIForeground(
            client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!, http: http),
            container: try container(url),
            enabled: true,
            currentLocation: {
                .init(point: .init(latitude: 10, longitude: 10), h3Cell: 1, observedAt: time)
            }
        )
        let assessment = try #require(try await reopened.assessment(at: time))
        #expect(assessment.periods.compactMap { $0.assessment.revision?.revision } == fixture.revisions)
        #expect(assessment.periods.allSatisfy { $0.assessment.impact == .noMatchUnknownCoverage })
        _ = await backgroundLifecycle(reopened).run()
        #expect(await http.requests.map(\.path) == [SyncHTTP.manifestPath] + fixture.paths + [SyncHTTP.manifestPath])
    }

    @Test func elapsedBackgroundDeadlineLeavesDurableManifestAndGeometryIntact() async throws {
        let fixture = SyncFixture()
        let revised = fixture.replacingFirstSlot()
        let url = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try reopen(url)
        let originalBody = try fixture.manifest(advertised: 1)
        let original = try await store.saveManifest(originalBody, eTag: #""original""#, replacing: nil)
        let accepted = try #require(try fixture.response(for: fixture.paths[0], manifest: originalBody).data)
        try await store.acceptGeometry(accepted, eTag: nil, product: .overallImpact, day: 1,
                                       manifestGeneration: original.generation)
        let replacementBody = try revised.manifest(advertised: 1)
        let replacement = try await store.saveManifest(replacementBody, eTag: #""changed""#, replacing: original.generation)
        let candidate = try #require(try revised.response(for: revised.paths[0], manifest: replacementBody).data)

        let elapsed = BackgroundRefreshBudget.standard(start: .now - BackgroundRefreshBudget.defaultTotalDuration)
        await BackgroundRefreshExecutionContext.$current.withValue(.init(budget: elapsed)) {
            #expect(!Task.isCancelled)
            await #expect(throws: CancellationError.self) {
                try await store.saveManifest(originalBody, eTag: #""late""#, replacing: replacement.generation)
            }
            await #expect(throws: CancellationError.self) {
                try await store.acceptGeometry(candidate, eTag: nil, product: .overallImpact, day: 1,
                                               manifestGeneration: replacement.generation)
            }
        }

        let reopened = try reopen(url)
        #expect(try await reopened.manifest()?.generation == replacement.generation)
        #expect(try await reopened.manifest()?.eTag == #""changed""#)
        let retained = try #require(try await reopened.slot(product: .overallImpact, day: 1))
        #expect(retained.revision.revision == fixture.revisions[0])
        #expect(retained.geometry == accepted)
    }

    enum BackgroundInterruption: CaseIterable, Sendable {
        case deadline, expiration, foreground
    }

    @Test(.timeLimit(.minutes(1)), arguments: BackgroundInterruption.allCases)
    func interruptedBackgroundPreservesCoreOutcomeAndResumesInForeground(_ interruption: BackgroundInterruption) async throws {
        let fixture = SyncFixture()
        let body = try fixture.manifest(advertised: 2)
        let request = SyncGate()
        let deadline = SyncGate()
        let foregroundManifest = SyncGate()
        let scheduled = BackgroundScheduleMarker()
        let feed: Set<Feed> = [.outlookDay1, .warning]
        let http = SyncHTTP { work, index in
            #expect(await scheduled.recorded)
            if index == 2 {
                #expect(HTTPExecutionMode.current == .background)
                await request.suspend()
            }
            if index >= 3 {
                #expect(HTTPExecutionMode.current == .foreground)
                #expect(BackgroundRefreshExecutionContext.current == nil)
                if work.path == SyncHTTP.manifestPath {
                    await foregroundManifest.suspend()
                    #expect(work.validator == #""original""#)
                    return .init(status: 304, headers: [:], data: nil)
                }
            }
            return try fixture.response(for: work.path, manifest: body)
        }
        let time = try Date.ISO8601FormatStyle().parse("2026-11-24T00:00:00Z")
        let url = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let service = WSSIForeground(
            client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!, http: http),
            container: try container(url),
            enabled: true,
            waitForBackgroundDeadline: { instant in
                if interruption == .deadline {
                    await deadline.suspend()
                } else {
                    try await ContinuousClock().sleep(until: instant)
                }
            },
            currentLocation: {
                .init(point: .init(latitude: 0.25, longitude: 0.75), h3Cell: 1, observedAt: time)
            }
        )
        let updates = await service.assessmentUpdates()
        #expect(await receivesSignal(from: updates))

        let core = Outcome(next: .distantFuture, result: .success, didNotify: true, feedsChanged: feed)
        let lifecycle = backgroundLifecycle(service, core: core, marker: scheduled)
        let background = Task { await lifecycle.run() }
        await request.waitUntilSuspended()
        #expect(await scheduled.recorded)
        #expect(await receivesSignal(from: updates), "The committed slot should publish before cancellation.")

        switch interruption {
        case .deadline:
            await deadline.waitUntilSuspended()
            await deadline.release()
        case .expiration:
            background.cancel()
        case .foreground:
            await service.offerRefresh()
        }

        let outcome = await background.value
        #expect(outcome.result == core.result && outcome.didNotify && outcome.feedsChanged == feed)
        let partial = try #require(try await service.assessment(at: time))
        #expect(partial.refreshStatus == .notAttempted)
        #expect(partial.periods[0].assessment.revision?.revision == fixture.revisions[0])
        #expect(partial.periods[1].assessment.revision == nil)
        #expect(await receivesSignal(from: updates), "Refresh termination should publish separately.")
        await request.release()
        if interruption != .foreground { await service.offerRefresh() }
        await foregroundManifest.waitUntilSuspended()
        await foregroundManifest.release()
        await service.waitForRefresh()
        #expect(await http.requests.map(\.path) == [SyncHTTP.manifestPath] + Array(fixture.paths.prefix(2))
                + [SyncHTTP.manifestPath, fixture.paths[1]])
        #expect(await http.peakInFlight == 1)
        #expect(try await service.assessment(at: time)?.periods[1].assessment.revision?.revision == fixture.revisions[1])
    }

    private func receivesSignal(from stream: AsyncStream<Void>) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                var events = stream.makeAsyncIterator()
                return await events.next() != nil
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(5))
                return false
            }
            let received = await group.next() ?? false
            group.cancelAll()
            return received
        }
    }

    @Test(arguments: [false, true])
    func backgroundForgeFailureDoesNotChangeCoreOutcome(offline: Bool) async throws {
        let http = SyncHTTP { _, _ in
            if offline { throw URLError(.notConnectedToInternet) }
            return .init(status: 503, headers: ["Retry-After": "120"], data: nil)
        }
        let service = WSSIForeground(
            client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!, http: http),
            container: try container(nil),
            enabled: true,
            currentLocation: { nil }
        )
        let core = Outcome(next: .distantFuture, result: .success, didNotify: true, feedsChanged: [.meso])
        let outcome = await backgroundLifecycle(service, core: core).run()
        #expect(outcome.result == core.result && outcome.didNotify && outcome.feedsChanged == core.feedsChanged)
        #expect(outcome.next == core.next)
        #expect(await http.requests.count == 1)
    }

    private func backgroundLifecycle(
        _ service: WSSIForeground,
        core: Outcome = .init(next: .distantFuture, result: .success, didNotify: false, feedsChanged: []),
        marker: BackgroundScheduleMarker? = nil
    ) -> BackgroundRefreshLifecycle {
        .init(
            beginRun: {
                .init(runId: UUID().uuidString, startedAt: .now) { phase, _ in
                    if phase == .authoritative { await marker?.record() }
                }
            },
            scheduleFallback: { .submitted },
            runOrchestration: { _ in core },
            scheduleAuthoritative: { _ in .submitted },
            wssi: service
        )
    }

    @Test @MainActor func foregroundReadsAcceptedSlotsBeforeAndDuringFailedRefreshAfterReopen() async throws {
        let fixture = SyncFixture()
        let url = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let body = try fixture.manifest(advertised: 2, startingAt: 2)
        try await seedForegroundStore(at: url, fixture: fixture, manifest: body)
        let container = try container(url)
        let gate = SyncGate()
        let retry = SyncGate()
        let http = SyncHTTP { _, index in
            if index == 2 { return .init(status: 304, headers: [:], data: nil) }
            await (index == 0 ? gate : retry).suspend()
            return .init(status: 503, headers: ["Retry-After": "2"], data: nil)
        }
        let time = try Date.ISO8601FormatStyle().parse("2026-11-24T00:00:00Z")
        var location = WSSIAcceptedAssessment.Location(point: .init(latitude: 0.25, longitude: 0.75), h3Cell: 1, observedAt: .distantPast)
        let foreground = WSSIForeground(
            client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!, http: http),
            container: container,
            currentLocation: { location }
        )
        let reader: any WSSIAssessmentReading = foreground
        let map: any WSSIGeometryReading = foreground
        await foreground.offerRefresh()
        #expect(try await reader.assessment(at: time) == nil)
        #expect(await http.requests.isEmpty)

        await foreground.setEnabled(true)
        let cached = try #require(try await reader.assessment(at: time))
        #expect(cached.refreshStatus == .notAttempted)
        #expect(cached.periods.count == 15)
        #expect(cached.periods[0].assessment.impact == .unavailable)
        #expect(cached.periods[2].assessment.impact == .match(.minor))
        #expect(cached.periods[3].assessment.impact == .match(.moderate))
        #expect(cached.periods[3].coverage == .unknown)
        #expect(cached.periods[3].assessment.revision?.revision == fixture.revisions[3])
        let geometry = try #require(try await map.geometry(product: .snowAmount, day: 1,
                                                           revision: fixture.revisions[3], at: time))
        #expect(geometry.geometry.features.count == 1)
        #expect(geometry.validity == .valid)
        #expect(geometry.revision.issuedAt == time)
        #expect(try await map.geometry(product: .snowAmount, day: 1, revision: fixture.revisions[3],
                                       at: geometry.revision.validTo) == nil)
        #expect(try await map.geometry(product: .snowAmount, day: 1, revision: UUID(), at: time) == nil)

        await foreground.offerRefresh()
        await gate.waitUntilSuspended()
        await foreground.offerRefresh()
        #expect(await http.requests.count == 1)
        location = .init(point: .init(latitude: 10, longitude: 10), h3Cell: 2, observedAt: .distantPast)
        let moved = try #require(try await reader.assessment(at: time))
        #expect(moved.location == location)
        #expect(moved.periods[3].assessment.impact == .noMatchUnknownCoverage)

        await foreground.setEnabled(false)
        #expect(try await reader.assessment(at: time) == nil)
        #expect(try await map.geometry(product: .snowAmount, day: 1,
                                       revision: fixture.revisions[3], at: time) == nil)
        await foreground.setEnabled(true)
        await foreground.offerRefresh()
        await gate.release()
        await retry.waitUntilSuspended()
        #expect(try await reader.assessment(at: time)?.refreshStatus == .notAttempted)
        await retry.release()
        await foreground.waitForRefresh()
        #expect(await http.peakInFlight == 1)
        let failed = try #require(try await reader.assessment(at: time))
        #expect(failed.refreshStatus == .manifestFailed(.httpStatus(503, retryAfterSeconds: 2)))
        let retained = failed.periods[3].assessment
        #expect(retained.revision == cached.periods[3].assessment.revision)
        #expect(retained.validity == .valid)
        #expect(retained.sourceStatus == .available && retained.pollHealth == .successful)
        #expect(retained.impact == .noMatchUnknownCoverage)

        await foreground.offerRefresh()
        await foreground.waitForRefresh()
        let recovered = try #require(try await reader.assessment(at: time))
        guard case .reconciled(let slots) = recovered.refreshStatus else {
            Issue.record("Expected a completed reconciliation after manifest revalidation")
            return
        }
        #expect(slots.count == 15)
        #expect(slots.first { $0.product == .snowAmount && $0.day == 1 }?.outcome == .current(fixture.revisions[3]))
        #expect(recovered.periods[3].assessment.revision == retained.revision)
    }

    @Test(.timeLimit(.minutes(1)))
    func foregroundPublishesAcceptedOverallBeforeReconciliationFinishes() async throws {
        let original = SyncFixture()
        var revised = original.replacingFirstSlot()
        revised.revise(1)
        let replacement = revised
        let initial = try original.manifest(advertised: 2)
        let updated = try replacement.manifest(advertised: 2)
        let url = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try await seedForegroundStore(at: url, fixture: original, manifest: initial)

        let overallGeometry = SyncGate()
        let subsequentGeometry = SyncGate()
        let http = SyncHTTP { request, _ in
            if request.path == replacement.paths[0] { await overallGeometry.suspend() }
            if request.path == replacement.paths[1] { await subsequentGeometry.suspend() }
            return try replacement.response(for: request.path, manifest: updated)
        }
        let time = try Date.ISO8601FormatStyle().parse("2026-11-24T00:00:00Z")
        let foreground = WSSIForeground(
            client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!, http: http),
            container: try container(url),
            enabled: true,
            currentLocation: {
                .init(point: .init(latitude: 0.25, longitude: 0.75), h3Cell: 1, observedAt: time)
            }
        )
        let updates = await foreground.assessmentUpdates()
        #expect(await receivesSignal(from: updates))
        #expect(try await foreground.assessment(at: time)?.periods[0].assessment.revision?.revision == original.revisions[0])

        await foreground.offerRefresh()
        await overallGeometry.waitUntilSuspended()
        #expect(await receivesSignal(from: updates), "A manifest commit should wake subscribers before geometry arrives.")
        #expect((try? await foreground.assessment(at: time))?.periods[0].assessment.revision?.revision == original.revisions[0])
        await overallGeometry.release()
        await subsequentGeometry.waitUntilSuspended()
        let signaled = await receivesSignal(from: updates)
        let partial = try? await foreground.assessment(at: time)
        await subsequentGeometry.release()
        await foreground.waitForRefresh()

        #expect(signaled, "A durable geometry commit should wake subscribers before reconciliation finishes.")
        let assessment = try #require(partial)
        #expect(assessment.periods[0].assessment.revision?.revision == replacement.revisions[0])
        #expect(assessment.periods[0].assessment.impact == .match(.major))
        #expect(assessment.refreshStatus == .notAttempted)
    }

    @Test func foregroundReportsSlotFailureUntilReplacementSucceeds() async throws {
        let original = SyncFixture()
        var revised = original.replacingFirstSlot()
        revised.revise(1)
        let replacement = revised
        let initial = try original.manifest(advertised: 3)
        let changed = try replacement.manifest(advertised: 3)
        let http = SyncHTTP { request, index in
            switch index {
            case 0..<4: return try original.response(for: request.path, manifest: initial)
            case 4: return .init(status: 200, headers: ["ETag": #""changed""#], data: changed)
            case 5: return .init(status: 503, headers: ["Retry-After": "2"], data: nil)
            case 7: return .init(status: 304, headers: [:], data: nil)
            default: return try replacement.response(for: request.path, manifest: changed)
            }
        }
        let time = try Date.ISO8601FormatStyle().parse("2026-11-24T00:00:00Z")
        let foreground = WSSIForeground(
            client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!, http: http),
            container: try container(nil),
            enabled: true,
            currentLocation: {
                .init(point: .init(latitude: 0.25, longitude: 0.75), h3Cell: 1, observedAt: time)
            }
        )
        let reader: any WSSIAssessmentReading = foreground

        let expected: [([UUID], [WSSISync.SlotResult.Outcome])] = [
            (Array(original.revisions.prefix(3)), original.revisions.prefix(3).map { .accepted($0) }),
            ([original.revisions[0], replacement.revisions[1], original.revisions[2]], [
                .failed(.httpStatus(503, retryAfterSeconds: 2), retainedRevision: original.revisions[0]),
                .accepted(replacement.revisions[1]), .current(original.revisions[2])
            ]),
            (Array(replacement.revisions.prefix(3)), [
                .accepted(replacement.revisions[0]), .current(replacement.revisions[1]), .current(original.revisions[2])
            ])
        ]
        for (expectedRevisions, expectedOutcomes) in expected {
            await foreground.offerRefresh()
            await foreground.waitForRefresh()
            let assessment = try #require(try await reader.assessment(at: time))
            guard case .reconciled(let slots) = assessment.refreshStatus else {
                Issue.record("Expected a completed reconciliation with independent slot outcomes")
                return
            }
            #expect(slots.count == 15)
            #expect(slots.prefix(3).allSatisfy { $0.product == .overallImpact })
            #expect(slots.prefix(3).map(\.day) == [1, 2, 3])
            #expect(Array(slots.prefix(3).map(\.outcome)) == expectedOutcomes)
            #expect(assessment.periods.prefix(3).compactMap { $0.assessment.revision?.revision } == expectedRevisions)
        }
    }

    @Test @MainActor func foregroundDropsAssessmentWhenRecoveryPublishesDuringRead() async throws {
        let hold = SyncGate()
        let ready = AsyncStream<Void>.makeStream()
        let fixture = SyncFixture()
        let manifest = try fixture.manifest(advertised: 1)
        let http = SyncHTTP { request, index in
            if index == 0 { return .init(status: 503, headers: [:], data: nil) }
            return try fixture.response(for: request.path, manifest: manifest)
        }
        let time = try Date.ISO8601FormatStyle().parse("2026-11-24T00:00:00Z")
        let location = WSSIAcceptedAssessment.Location(
            point: .init(latitude: 0.25, longitude: 0.75), h3Cell: 1, observedAt: time
        )
        var checks = 0
        let foreground = WSSIForeground(
            client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!, http: http),
            container: try container(nil),
            enabled: true,
            currentLocation: {
                checks += 1
                if checks == 4 {
                    ready.continuation.yield()
                    await hold.suspend()
                }
                return location
            }
        )
        await foreground.offerRefresh()
        await foreground.waitForRefresh()
        let failed = try #require(try await foreground.assessment(at: time))
        #expect(failed.refreshStatus == .manifestFailed(.httpStatus(503, retryAfterSeconds: nil)))

        let read = Task {
            defer { ready.continuation.finish() }
            return try await foreground.assessment(at: time)
        }
        var readiness = ready.stream.makeAsyncIterator()
        try #require(await readiness.next() != nil, "Assessment returned before rechecking its location")
        await hold.waitUntilSuspended()
        await foreground.offerRefresh()
        await foreground.waitForRefresh()
        await hold.release()
        #expect(try await read.value == nil)

        let recovered = try #require(try await foreground.assessment(at: time))
        guard case .reconciled(let slots) = recovered.refreshStatus else {
            Issue.record("Expected a completed reconciliation after recovery")
            return
        }
        #expect(slots.first?.outcome == .accepted(fixture.revisions[0]))
        #expect(recovered.periods.first?.assessment.revision?.revision == fixture.revisions[0])
    }

    @Test(arguments: [false, true])
    @MainActor func foregroundDropsAssessmentWhenLocationOrGateChangesDuringRead(toggleGate: Bool) async throws {
        let hold = SyncGate()
        let ready = AsyncStream<Void>.makeStream()
        let store = try container(nil)
        var location = WSSIAcceptedAssessment.Location(point: .init(latitude: 0.25, longitude: 0.75), h3Cell: 1, observedAt: .distantPast)
        var checks = 0
        let foreground = WSSIForeground(
            client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!,
                                    http: SyncHTTP { _, _ in throw URLError(.notConnectedToInternet) }),
            container: store,
            currentLocation: {
                checks += 1
                if checks == 2 {
                    ready.continuation.yield()
                    await hold.suspend()
                }
                return location
            }
        )
        await foreground.setEnabled(true)
        let read = Task {
            defer { ready.continuation.finish() }
            return try await foreground.assessment(at: .now)
        }
        var readiness = ready.stream.makeAsyncIterator()
        try #require(await readiness.next() != nil, "Assessment returned before rechecking its location")
        await hold.waitUntilSuspended()
        if toggleGate {
            await foreground.setEnabled(false)
            await foreground.setEnabled(true)
        } else {
            location = .init(point: .init(latitude: 10, longitude: 10), h3Cell: 2, observedAt: .distantPast)
        }
        await hold.release()
        #expect(try await read.value == nil)
        #expect(try await foreground.assessment(at: .now)?.location == location)
    }

    private func seedForegroundStore(at url: URL, fixture: SyncFixture, manifest: Data) async throws {
        let store = try reopen(url)
        let http = SyncHTTP { request, _ in try fixture.response(for: request.path, manifest: manifest) }
        let sync = makeSync(http, store: store)
        let outcome = await HTTPExecutionMode.$current.withValue(.background) {
            await sync.refresh(enabled: true)
        }
        _ = try reconciled(outcome, update: .updated)
    }

    @Test func interruptedAcquisitionResumesOnlyMissingSlotsAfterReopenAnd304() async throws {
        let fixture = SyncFixture()
        let url = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try await acceptFirstTenAndCancelTwice(fixture, url: url)

        let store = try reopen(url)
        let body = try fixture.manifest()
        let http = SyncHTTP { request, _ in
            if request.path == SyncHTTP.manifestPath { return .init(status: 304, headers: [:], data: nil) }
            return try fixture.response(for: request.path, manifest: body)
        }
        let sync = makeSync(http, store: store)
        let outcome = await sync.refresh(enabled: true)
        let slots = try reconciled(outcome, update: .revalidated)
        #expect(slots.map(\.outcome) == fixture.revisions.enumerated().map { index, revision in
            index < 10 ? .current(revision) : .accepted(revision)
        })
        let requests = await http.requests
        #expect(requests.map(\.path) == [SyncHTTP.manifestPath] + Array(fixture.paths.dropFirst(10)))
        #expect(requests.first?.validator == #""original""#)
        #expect(requests.dropFirst().allSatisfy { $0.validator == nil })
        #expect(await http.peakInFlight == 1)
        for (entry, revision) in zip(try WSSISourceDecoder.manifest(from: body).datasets, fixture.revisions) {
            #expect(try await store.slot(product: entry.product, day: entry.day)?.revision.revision == revision)
        }
    }

    @Test func statusChangesSkipGeometryAndFailedRevisionsRecoverAfterReopenAnd304() async throws {
        let url = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let replacement = try await acceptPartialRevisionUpdate(at: url)
        let store = try reopen(url)
        let body = try replacement.manifest(overdue: true)
        let http = SyncHTTP { request, _ in
            if request.path == SyncHTTP.manifestPath { return .init(status: 304, headers: [:], data: nil) }
            return try replacement.response(for: request.path, manifest: body)
        }
        let slots = try reconciled(await makeSync(http, store: store).refresh(enabled: true), update: .revalidated)
        #expect(slots.map(\.outcome) == replacement.revisions.enumerated().map { index, revision in
            if index == 14 { return .unavailable(retainedRevision: nil) }
            return (1..<5).contains(index) ? .accepted(revision) : .current(revision)
        })
        #expect(await http.requests.map(\.path) == [SyncHTTP.manifestPath] + Array(replacement.paths[1..<5]))
        #expect(await http.requests.first?.validator == #""changed""#)
        for (slot, revision) in zip(slots.prefix(14), replacement.revisions) {
            #expect(try await store.slot(product: slot.product, day: slot.day)?.revision.revision == revision)
        }
    }

    private func acceptPartialRevisionUpdate(at url: URL) async throws -> SyncFixture {
        let store = try reopen(url)
        let original = SyncFixture()
        let initial = try original.manifest(advertised: 14)
        let statusOnly = try original.manifest(advertised: 14, overdue: true)
        var revised = original
        for index in 0..<5 { revised.revise(index) }
        let changes = try revised.manifest(advertised: 14, overdue: true)
        let replacement = revised
        let http = SyncHTTP { request, index in
            switch (request.path, request.validator) {
            case (SyncHTTP.manifestPath, nil):
                return .init(status: 200, headers: ["ETag": #""original""#], data: initial)
            case (SyncHTTP.manifestPath, #""original""#):
                return .init(status: 200, headers: ["ETag": #""status""#], data: statusOnly)
            case (SyncHTTP.manifestPath, #""status""#):
                return .init(status: 200, headers: ["ETag": #""changed""#], data: changes)
            case (replacement.paths[1], _):
                return .init(status: 404, headers: [:], data: nil)
            case (replacement.paths[2], _):
                return .init(status: 503, headers: ["Retry-After": "2"], data: nil)
            case (replacement.paths[3], _):
                throw URLError(.networkConnectionLost)
            case (replacement.paths[4], _):
                return .init(status: 200, headers: [:], data: Data("{}".utf8))
            default:
                if index < 15 { return try original.response(for: request.path, manifest: initial) }
                return try replacement.response(for: request.path, manifest: changes)
            }
        }
        let sync = makeSync(http, store: store)
        let first = try reconciled(await sync.refresh(enabled: true), update: .updated)
        #expect(first.prefix(14).map(\.outcome) == original.revisions.prefix(14).map { .accepted($0) })

        let status = try reconciled(await sync.refresh(enabled: true), update: .updated)
        #expect(status.prefix(14).map(\.outcome) == original.revisions.prefix(14).map { .current($0) })
        #expect(status.last?.outcome == .unavailable(retainedRevision: nil))
        let manifest = try #require(try await store.manifest())
        #expect(manifest.document.pollFreshness == .overdue)
        #expect(manifest.document.datasets[0].sourceStatus == .unavailable)
        #expect(manifest.document.datasets[0].pollHealth == .failed)
        #expect(manifest.document.datasets[0].validity == .expired)
        #expect(manifest.document.datasets[14].sourceStatus == .available)
        #expect(manifest.document.datasets[14].pollHealth == .successful)
        #expect(manifest.document.datasets[14].validity == .neverAccepted)
        #expect(await http.requests.count == 16)

        let slots = try reconciled(await sync.refresh(enabled: true), update: .updated)
        #expect(slots.prefix(5).map(\.outcome) == [
            .accepted(replacement.revisions[0]),
            .failed(.httpStatus(404, retryAfterSeconds: nil), retainedRevision: original.revisions[1]),
            .failed(.httpStatus(503, retryAfterSeconds: 2), retainedRevision: original.revisions[2]),
            .failed(.transport, retainedRevision: original.revisions[3]),
            .failed(.invalidRepresentation, retainedRevision: original.revisions[4])
        ])
        #expect(slots[5..<14].map(\.outcome) == original.revisions[5..<14].map { .current($0) })
        #expect(slots.last?.outcome == .unavailable(retainedRevision: nil))
        #expect(await http.requests.dropFirst(17).map(\.path) == Array(replacement.paths.prefix(5)))
        for (index, slot) in slots.prefix(14).enumerated() {
            let stored = try await store.slot(product: slot.product, day: slot.day)
            #expect(stored?.revision.revision == (index == 0 ? replacement.revisions[0] : original.revisions[index]))
        }
        return replacement
    }

    @Test(arguments: [false, true])
    func absentOrCorruptManifestStartsUnconditionally(corrupt: Bool) async throws {
        let url = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        if corrupt {
            let context = ModelContext(try container(url))
            context.insert(WSSIStoredManifest(body: Data("{}".utf8), eTag: #""unusable""#))
            try context.save()
        }
        let store = try reopen(url)
        let body = try SyncFixture().manifest(advertised: 0)
        let http = SyncHTTP { _, _ in .init(status: 200, headers: [:], data: body) }
        let slots = try reconciled(await makeSync(http, store: store).refresh(enabled: true), update: .updated)
        #expect(slots.map(\.outcome) == Array(repeating: .unavailable(retainedRevision: nil), count: 15))
        #expect(await http.requests == [.init(path: SyncHTTP.manifestPath, validator: nil)])
        #expect(try await store.manifest() != nil)
    }

    @Test func conflicting304RecoversOnceAndUnsolicited304LeavesManifestIntact() async throws {
        let store = try reopen()
        let body = try SyncFixture().manifest(advertised: 0)
        let initial = try await store.saveManifest(body, eTag: #""original""#, replacing: nil)
        let http = SyncHTTP { _, index in
            if index == 1 { return .init(status: 200, headers: ["ETag": #""recovered""#], data: body) }
            return .init(status: 304, headers: ["ETag": #""wrong""#], data: nil)
        }
        let sync = makeSync(http, store: store)
        _ = try reconciled(await sync.refresh(enabled: true), update: .updated)
        let recovered = try #require(try await store.manifest())
        #expect(recovered.generation != initial.generation)
        #expect(await sync.refresh(enabled: true) == .manifestFailed(.invalidRepresentation, retainedManifest: true))
        #expect(await http.requests.map(\.validator) == [#""original""#, nil, #""recovered""#, nil])
        #expect(try await store.manifest()?.generation == recovered.generation)
    }

    @Test func disabledAndOverlappingRefreshesShareOneRequestAndCancelIndependently() async throws {
        let store = try reopen()
        let body = try SyncFixture().manifest(advertised: 0)
        let gate = SyncGate()
        let http = SyncHTTP { _, _ in
            await gate.suspend()
            return .init(status: 200, headers: [:], data: body)
        }
        let sync = makeSync(http, store: store)
        #expect(await sync.refresh(enabled: false) == .disabled)
        #expect(await http.requests.isEmpty)

        let background = Task { await sync.refresh(enabled: true) }
        await gate.waitUntilSuspended()
        let foreground = Task {
            await HTTPExecutionMode.$current.withValue(.foreground) { await sync.refresh(enabled: true) }
        }
        await waitForWaiters(2, sync: sync)
        background.cancel()
        #expect(await background.value == .cancelled)
        #expect(await http.requests.count == 1)
        await gate.release()
        _ = try reconciled(await foreground.value, update: .updated)
        #expect(await http.requests.count == 1)
    }

    @Test func foregroundWaitsForBudgetedBackgroundThenRunsUnderItsOwnContext() async throws {
        let store = try reopen()
        let gate = SyncGate()
        let body = try SyncFixture().manifest(advertised: 0)
        let context = BackgroundRefreshExecutionContext(budget: .standard(start: .now))
        let http = SyncHTTP { _, index in
            if index == 0 {
                #expect(HTTPExecutionMode.current == .background)
                #expect(BackgroundRefreshExecutionContext.current?.deadlineState === context.deadlineState)
                await gate.suspend()
                await context.deadlineState.markExceeded()
                throw CancellationError()
            }
            #expect(HTTPExecutionMode.current == .foreground)
            #expect(BackgroundRefreshExecutionContext.current == nil)
            return .init(status: 200, headers: [:], data: body)
        }
        let sync = makeSync(http, store: store)
        let background = Task {
            await BackgroundRefreshExecutionContext.$current.withValue(context) { await sync.refresh(enabled: true) }
        }
        await gate.waitUntilSuspended()
        let foreground = Task {
            await HTTPExecutionMode.$current.withValue(.foreground) { await sync.refresh(enabled: true) }
        }
        await waitForWaiters(2, sync: sync)
        #expect(await http.requests.count == 1)
        await gate.release()
        #expect(await background.value == .cancelled)
        #expect(await context.deadlineState.exceeded())
        _ = try reconciled(await foreground.value, update: .updated)
        #expect(await http.requests.count == 2)
        #expect(await http.peakInFlight == 1)
    }

    @Test(arguments: [200, 304, 0, 404])
    func supersededManifestOrGeometryCannotOverwriteNewerAcceptance(delayedStatus: Int) async throws {
        let store = try reopen()
        let fixture = SyncFixture()
        let slot = delayedStatus == 404 ? 14 : 0
        let old = try fixture.manifest(advertised: 1, startingAt: slot)
        let initial = try await store.saveManifest(old, eTag: #""old""#, replacing: nil)
        var next = fixture
        next.revise(slot)
        let gate = SyncGate()
        let http = SyncHTTP { _, index in
            // Delay the manifest response, geometry success, or final-slot geometry failure.
            if delayedStatus == 0 || delayedStatus == 404, index == 0 {
                return .init(status: 304, headers: [:], data: nil)
            }
            await gate.suspend()
            if delayedStatus == 0 { return try fixture.response(for: fixture.paths[0], manifest: old) }
            return .init(status: delayedStatus, headers: ["ETag": #""old""#], data: delayedStatus == 200 ? old : nil)
        }
        let sync = makeSync(http, store: store)
        let task = Task { await sync.refresh(enabled: true) }
        await gate.waitUntilSuspended()
        let newerBody = try next.manifest(advertised: 1, startingAt: slot)
        let newer = try await store.saveManifest(newerBody, eTag: #""newer""#, replacing: initial.generation)
        let entry = newer.document.datasets[slot]
        let geometry = try #require(try next.response(for: next.paths[slot], manifest: newerBody).data)
        try await store.acceptGeometry(geometry, eTag: nil, product: entry.product, day: entry.day,
                                       manifestGeneration: newer.generation)
        await gate.release()
        #expect(await task.value == .superseded)
        #expect(try await store.manifest()?.generation == newer.generation)
        #expect(try await store.slot(product: entry.product, day: entry.day)?.revision.revision == next.revisions[slot])
    }

    private func acceptFirstTenAndCancelTwice(_ fixture: SyncFixture, url: URL) async throws {
        let store = try reopen(url)
        let body = try fixture.manifest()
        let first = SyncGate()
        let second = SyncGate()
        let http = SyncHTTP { request, index in
            if index == 11 { await first.suspend() }
            if index == 12 { return .init(status: 304, headers: [:], data: nil) }
            if index == 13 { await second.suspend() }
            return try fixture.response(for: request.path, manifest: body)
        }
        let sync = makeSync(http, store: store)
        let task = Task { await sync.refresh(enabled: true) }
        await first.waitUntilSuspended()
        task.cancel()
        #expect(await task.value == .cancelled)
        let queued = Task { await sync.refresh(enabled: true) }
        await waitForWaiters(1, sync: sync)
        queued.cancel()
        #expect(await queued.value == .cancelled)
        #expect(await http.requests.count == 12)
        let retry = Task { await sync.refresh(enabled: true) }
        await waitForWaiters(1, sync: sync)
        await first.release()

        await second.waitUntilSuspended()
        retry.cancel()
        #expect(await retry.value == .cancelled)
        await second.release()
        await sync.waitForWorkloadToFinish()
        let requests = await http.requests
        #expect(requests.map(\.path) == [SyncHTTP.manifestPath] + Array(fixture.paths.prefix(11))
                + [SyncHTTP.manifestPath, fixture.paths[10]])
        #expect(requests.dropFirst(12).first?.validator == #""original""#)
        #expect(await http.peakInFlight == 1)
    }

    private func waitForWaiters(_ count: Int, sync: WSSISync) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(5)
        while await sync.waiterCount < count, clock.now < deadline { await Task.yield() }
        #expect(await sync.waiterCount == count)
    }

    private func makeSync(_ http: SyncHTTP, store: WSSIAcceptedStore) -> WSSISync {
        WSSISync(client: ForgeWSSIClient(origin: URL(string: "https://wssi.example.test")!, http: http), store: store)
    }

    private func reconciled(_ outcome: WSSISync.Outcome, update: WSSISync.ManifestUpdate) throws -> [WSSISync.SlotResult] {
        guard case .reconciled(let actual, let slots) = outcome else {
            Issue.record("Expected reconciliation, got \(outcome)")
            throw URLError(.cannotParseResponse)
        }
        #expect(actual == update)
        return slots
    }

    private func temporaryStore() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("WSSI.sqlite")
    }

    private func reopen(_ url: URL? = nil) throws -> WSSIAcceptedStore {
        WSSIAcceptedStore(modelContainer: try container(url))
    }

    private func container(_ url: URL?) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SkyAwarePersistenceSchema.self)
        let configuration = url.map { ModelConfiguration(schema: schema, url: $0) }
            ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, migrationPlan: SkyAwarePersistenceMigrationPlan.self,
                                  configurations: configuration)
    }
}

private actor BackgroundScheduleMarker {
    private(set) var recorded = false

    func record() { recorded = true }
}

actor SyncHTTP: HTTPClient {
    static let manifestPath = "/v1/wssi/manifest"

    struct Request: Equatable, Sendable {
        let path: String
        let validator: String?
    }
    private(set) var requests: [Request] = []
    private(set) var peakInFlight = 0
    private var inFlight = 0
    private let respond: @Sendable (Request, Int) async throws -> HTTPResponse

    init(_ respond: @escaping @Sendable (Request, Int) async throws -> HTTPResponse) {
        self.respond = respond
    }

    func get(_ url: URL, headers: [String: String], fallbackPolicy: HTTPFallbackPolicy) async throws -> HTTPResponse {
        #expect(fallbackPolicy == .explicitRevalidation)
        let request = Request(path: url.path, validator: headers["If-None-Match"])
        let index = requests.count
        requests.append(request)
        inFlight += 1
        peakInFlight = max(peakInFlight, inFlight)
        defer { inFlight -= 1 }
        return try await respond(request, index)
    }

    func post(_ url: URL, headers: [String: String], body: Data?) async throws -> HTTPResponse {
        throw URLError(.unsupportedURL)
    }

    nonisolated func clearCache() {}
}

actor SyncGate {
    private var releaseWork: CheckedContinuation<Void, Never>?
    private var waitingForWork: CheckedContinuation<Void, Never>?

    func suspend() async {
        await withCheckedContinuation { continuation in
            releaseWork = continuation
            waitingForWork?.resume()
            waitingForWork = nil
        }
    }

    func waitUntilSuspended() async {
        guard releaseWork == nil else { return }
        await withCheckedContinuation { waitingForWork = $0 }
    }

    func release() {
        releaseWork?.resume()
        releaseWork = nil
    }
}

struct SyncFixture: Sendable {
    private(set) var revisions = (0..<15).map { _ in UUID() }
    private var corrections: Set<Int> = []

    mutating func revise(_ index: Int) {
        revisions[index] = UUID()
        corrections.insert(index)
    }

    func replacingFirstSlot() -> Self {
        var replacement = self
        replacement.revise(0)
        return replacement
    }

    var paths: [String] {
        revisions.indices.map { index in
            "/v1/wssi/\(product(index).rawValue)/days/\(day(index))/revisions/\(revisions[index].uuidString.lowercased())/geometry"
        }
    }

    func manifest(advertised: Int = 15, startingAt: Int = 0, overdue: Bool = false) throws -> Data {
        let datasets: [[String: Any]] = revisions.indices.map { index in
            var accepted = metadata(index)
            for key in ["product", "day", "coverage"] { accepted.removeValue(forKey: key) }
            accepted["geometryPath"] = paths[index]
            let available = (startingAt..<(startingAt + advertised)).contains(index)
            return ["product": product(index).rawValue, "day": day(index), "coverage": "unknown",
                    "validity": available ? (overdue ? "Expired" : "Valid") : "NeverAccepted",
                    "sourceStatus": available && overdue ? "Unavailable" : "Available",
                    "pollHealth": available && overdue ? "Failed" : "Successful",
                    "accepted": available ? accepted as Any : NSNull()]
        }
        return try JSONSerialization.data(withJSONObject: ["datasets": datasets, "pollFreshness": overdue ? "Overdue" : "Scheduled"])
    }

    func response(for path: String, manifest: Data) throws -> HTTPResponse {
        if path == SyncHTTP.manifestPath { return .init(status: 200, headers: ["ETag": #""original""#], data: manifest) }
        let index = try #require(paths.firstIndex(of: path))
        let severity = corrections.contains(index) ? "Major" : (index == 3 ? "Moderate" : "Minor")
        let feature: [String: Any] = [
            "type": "Feature", "id": 1, "properties": ["sourceObjectId": 1, "severity": severity],
            "geometry": ["type": "MultiPolygon", "coordinates": [[[[0, 0], [1, 0], [1, 1], [0, 0]]]]]
        ]
        let geometry: [String: Any] = ["type": "FeatureCollection", "features": [feature], "metadata": metadata(index)]
        return .init(status: 200, headers: [:], data: try JSONSerialization.data(withJSONObject: geometry))
    }

    private func metadata(_ index: Int) -> [String: Any] {
        ["product": product(index).rawValue, "day": day(index), "coverage": "unknown",
         "revision": revisions[index].uuidString,
         "issuedAt": "2026-11-24T00:00:00Z", "validFrom": "2026-11-24T00:00:00Z",
         "validTo": "2026-11-27T00:00:00Z", "retrievedAt": "2026-11-24T00:00:00Z",
         "gisFileDate": corrections.contains(index) ? "2026-11-24T00:15:00Z" : "2026-11-24T00:00:00Z"]
    }

    private func product(_ index: Int) -> WSSIProduct { WSSIProduct.allCases[index / 3] }
    private func day(_ index: Int) -> Int { index % 3 + 1 }
}
