import Foundation
import SwiftData
import Synchronization
import Testing
@testable import SkyAware

@MainActor
struct WSSIAcceptanceTests {
    private let now = Date(timeIntervalSince1970: 1_794_440_000)
    private func scope(_ west: Double = -112) throws -> WSSIScope {
        try WSSIScope(south: 36, west: west, north: 43, east: west + 10)
    }
    private func store() throws -> WSSISnapshotStore {
        WSSISnapshotStore(modelContainer: try TestStore.container(for: SkyAwarePersistenceSchema.models))
    }
    private func client(_ fixture: WSSIClientTests.Fixture) throws -> WSSIClient {
        try WSSIClient(transport: { try await fixture.get($0, $1) })
    }

    @Test("Foreground gate, cadence and overlap preserve independently queryable accepted coverage")
    func foregroundIntegration() async throws {
        let store = try store()
        let fixture = WSSIClientTests.Fixture()
        let gate = Gate()
        let probe = Probe(fixture: fixture, gate: gate)
        let enabled = Mutex(false)
        let outcomes = Mutex<[WSSIForegroundIngestion.Outcome]>([])
        let clock = Mutex(now)
        let failing = Mutex(false)
        let ingestion = WSSIForegroundIngestion(store: store,
            client: try WSSIClient(transport: { request, ceiling in
                if failing.withLock({ $0 }) { throw WSSIAcquisitionError.invalidResponse }
                return try await probe.get(request, ceiling)
            }),
            enabled: { enabled.withLock { $0 } }, date: { clock.withLock { $0 } },
            observe: { value in outcomes.withLock { $0.append(value) } })
        let region = try scope()
        await ingestion.admit(scope: region, foreground: true)
        enabled.withLock { $0 = true }
        await ingestion.admit(scope: region, foreground: false)
        #expect(await fixture.count == 0)
        await ingestion.admit(scope: region, foreground: true)
        await gate.waitForEntry()
        await ingestion.admit(scope: region, foreground: true)
        await gate.open()
        await ingestion.waitForIdle()
        let accepted = try await store.acceptedCoverage(at: now)
        #expect(accepted.snapshots.count == 1)
        let assessment = try await ingestion.assessment(at: .init(latitude: 40, longitude: -105), time: now)
        #expect(assessment.entries.contains { $0.issuedAt != nil })
        let requests = await fixture.count
        await ingestion.admit(scope: region, foreground: true)
        #expect(await fixture.count == requests)
        #expect(outcomes.withLock { $0 } == [.disabled, .background, .busy, .accepted, .fresh])
        clock.withLock { $0 = now.addingTimeInterval(7200) }
        failing.withLock { $0 = true }
        await ingestion.admit(scope: region, foreground: true)
        await ingestion.waitForIdle()
        #expect(outcomes.withLock { $0.last } == .failed)
        #expect(try await store.acceptedCoverage(at: now).snapshots == accepted.snapshots)
    }

    @Test("Movement during acquisition selects latest scope and cadence follows both retained scopes")
    func foregroundMovement() async throws {
        let store = try store()
        let a = try scope(), b = try scope(-111)
        let gate = Gate()
        let af = WSSIClientTests.Fixture(mode: .empty)
        let bf = WSSIClientTests.Fixture(mode: .empty, geometry: "-111.0,36.0,-101.0,43.0")
        let probe = Probe(fixture: af, gate: gate)
        let date = now
        let ingestion = WSSIForegroundIngestion(store: store,
            client: try WSSIClient(transport: { request, ceiling in
                let geometry = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                    .queryItems?.first { $0.name == "geometry" }?.value
                if geometry == "-111.0,36.0,-101.0,43.0" { return try await bf.get(request, ceiling) }
                return try await probe.get(request, ceiling)
            }), enabled: { true }, date: { date })
        await ingestion.admit(scope: a, foreground: true)
        await gate.waitForEntry()
        await ingestion.admit(scope: b, foreground: true)
        #expect(try await store.acceptedCoverage(at: now).selectedScope == b)
        await gate.open()
        await ingestion.waitForIdle()
        #expect(try await store.acceptedCoverage(at: now).selectedScope == b)
        #expect(try await store.acceptedCoverage(at: now).snapshots.count == 2)
        let ac = await af.count, bc = await bf.count
        await ingestion.admit(scope: a, foreground: true)
        await ingestion.admit(scope: b, foreground: true)
        #expect(await af.count == ac)
        #expect(await bf.count == bc)
    }

    @Test("Two unconditional matching scans preserve independent source dates and explicit empty states")
    func stable() async throws {
        let fixture = WSSIClientTests.Fixture(mode: .unchanged)
        let transport = Probe(fixture: fixture, varyLayerIssuance: true)
        let client = try WSSIClient(transport: { try await transport.get($0, $1) })
        let store = try store()
        try await store.selectCoverage(scope(), at: now)
        let date = now
        let first = try await store.refreshCoverage(scope: scope(), client: client, date: { date })
        #expect(first.snapshot.layers.count == 20)
        #expect(Set(first.snapshot.layers.compactMap(\.issuedAt)).count == 2)
        #expect(Set(first.snapshot.layers.compactMap(\.validFrom)).count == 2)
        #expect(await fixture.count == 160)
        #expect(await transport.conditionalRequests == 0)
        let second = try await store.refreshCoverage(scope: scope(), client: client, date: { date })
        #expect(second.revision == first.revision)
        #expect(await transport.conditionalRequests == 0)
        let empty = try await store.refreshCoverage(scope: scope(), client: self.client(.init(mode: .empty)), date: { date })
        #expect(empty.snapshot.layers.allSatisfy { $0.state == .observedEmpty && $0.issuedAt == nil })
        for layer in empty.snapshot.layers { #expect(try layer.assessmentLayer(in: empty.snapshot.scope) == nil) }
    }

    @Test("Same IDs with changed attributes or geometry between scans reject the whole attempt",
          arguments: ["impact", "geometry", "issuance", "ids", "apiSecond", "mixed"])
    func changed(field: String) async throws {
        let store = try store()
        let date = now
        try await store.selectCoverage(scope(), at: now)
        let original = try await store.refreshCoverage(scope: scope(), client: client(.init()), date: { date })
        let probe = Probe(fixture: .init(), changedField: field)
        let candidate = try WSSIClient(transport: { try await probe.get($0, $1) })
        if field == "mixed" {
            await #expect(throws: WSSIAssessmentError.self) {
                try await store.refreshCoverage(scope: scope(), client: candidate, date: { date })
            }
        } else {
            let error: WSSIAcquisitionError = field == "apiSecond" ? .invalidResponse : .changedPublication
            await #expect(throws: error) {
                try await store.refreshCoverage(scope: scope(), client: candidate, date: { date })
            }
        }
        #expect(try await store.acceptedCoverage(at: now).snapshots == [original])
    }

    @Test("Partial inventory, API error and cancellation preserve the accepted cache",
          arguments: [WSSIClientTests.Mode.missing, .apiError, .truncated])
    func failures(mode: WSSIClientTests.Mode) async throws {
        let store = try store()
        let date = now
        try await store.selectCoverage(scope(), at: now)
        let original = try await store.refreshCoverage(scope: scope(), client: client(.init()), date: { date })
        await #expect(throws: (any Error).self) {
            try await store.refreshCoverage(scope: scope(), client: client(.init(mode: mode)), date: { date })
        }
        #expect(try await store.acceptedCoverage(at: now).snapshots == [original])
        let gate = Gate()
        let probe = Probe(fixture: .init(), gate: gate, pauseAt: 81) // Cancellation during the second scan.
        let candidate = try WSSIClient(transport: { try await probe.get($0, $1) })
        let region = try scope()
        let task = Task { try await store.refreshCoverage(scope: region, client: candidate, date: { date }) }
        await gate.waitForEntry()
        #expect(try await store.acceptedCoverage(at: now).snapshots == [original])
        task.cancel()
        await gate.open()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try await store.acceptedCoverage(at: now).snapshots == [original])
    }

    @Test("Latest admitted attempt fences old completion even when newer work fails", arguments: [false, true])
    func supersession(newerFails: Bool) async throws {
        let store = try store()
        let date = now
        let region = try scope()
        try await store.selectCoverage(region, at: now)
        let original = try await store.refreshCoverage(scope: region, client: client(.init()), date: { date })
        let gate = Gate()
        let probe = Probe(fixture: .init(mode: .empty), gate: gate)
        let slow = try WSSIClient(transport: { try await probe.get($0, $1) })
        let older = Task { try await store.refreshCoverage(scope: region, client: slow, date: { date }) }
        await gate.waitForEntry()
        let newer = try client(.init(mode: newerFails ? .apiError : .empty))
        if newerFails {
            await #expect(throws: WSSIAcquisitionError.invalidResponse) {
                try await store.refreshCoverage(scope: region, client: newer, date: { date })
            }
        } else {
            _ = try await store.refreshCoverage(scope: region, client: newer, date: { date })
        }
        let expected = try await store.acceptedCoverage(at: now).snapshots
        await gate.open()
        await #expect(throws: WSSIAcceptanceError.superseded) { try await older.value }
        #expect(try await store.acceptedCoverage(at: now).snapshots == expected)
        if newerFails { #expect(expected == [original]) }
    }

    @Test("Old-location completion cannot select coverage; movement retains only two scopes")
    func movement() async throws {
        let store = try store()
        let date = now
        let a = try scope(), b = try scope(-111), c = try scope(-110)
        try await store.selectCoverage(a, at: now)
        let gate = Gate()
        let probe = Probe(fixture: .init(mode: .empty), gate: gate)
        let slow = try WSSIClient(transport: { try await probe.get($0, $1) })
        let old = Task { try await store.refreshCoverage(scope: a, client: slow, date: { date }) }
        await gate.waitForEntry()
        try await store.selectCoverage(b, at: now)
        let bf = WSSIClientTests.Fixture(mode: .empty, geometry: "-111.0,36.0,-101.0,43.0")
        _ = try await store.refreshCoverage(scope: b, client: client(bf), date: { date })
        await gate.open()
        _ = try await old.value
        let coverage = try await store.acceptedCoverage(at: now)
        #expect(coverage.selectedScope == b)
        #expect(coverage.snapshots.map(\.snapshot.scope) == [b, a])
        // Reselect a retained scope without a successful new refresh.
        try await store.selectCoverage(a, at: now)
        #expect(try await store.acceptedCoverage(at: now).snapshots.map(\.snapshot.scope) == [a, b])
        try await store.selectCoverage(c, at: now)
        let cf = WSSIClientTests.Fixture(mode: .empty, geometry: "-110.0,36.0,-100.0,43.0")
        _ = try await store.refreshCoverage(scope: c, client: client(cf), date: { date })
        #expect(try await store.acceptedCoverage(at: now).snapshots.map(\.snapshot.scope) == [c, a])
    }

    @Test("Selection reversal fences an in-flight retained location, including A-to-B-to-A intent")
    func selectionReversal() async throws {
        let store = try store()
        let date = now
        let a = try scope(), b = try scope(-111)
        try await store.selectCoverage(a, at: now)
        _ = try await store.refreshCoverage(scope: a, client: client(.init(mode: .empty)), date: { date })
        try await store.selectCoverage(b, at: now)
        let fixture = WSSIClientTests.Fixture(mode: .empty, geometry: "-111.0,36.0,-101.0,43.0")
        _ = try await store.refreshCoverage(scope: b, client: client(fixture), date: { date })
        let clock = Mutex(now.addingTimeInterval(10))
        try await store.selectCoverage(a, at: now.addingTimeInterval(10))
        let gate = Gate()
        let probe = Probe(fixture: .init(mode: .empty), gate: gate)
        let slow = try WSSIClient(transport: { try await probe.get($0, $1) })
        let task = Task {
            try await store.refreshCoverage(scope: a, client: slow, date: { clock.withLock { $0 } })
        }
        await gate.waitForEntry()
        clock.withLock { $0 = now.addingTimeInterval(20) }
        try await store.selectCoverage(b, at: now.addingTimeInterval(20))
        let reselection = now.addingTimeInterval(30)
        clock.withLock { $0 = reselection }
        try await store.selectCoverage(a, at: reselection)
        clock.withLock { $0 = now.addingTimeInterval(40) }
        await gate.open()
        _ = try await task.value
        let final = try await store.acceptedCoverage(at: now.addingTimeInterval(40))
        #expect(final.selectedScope == a)
        #expect(final.snapshots.map(\.snapshot.scope) == [a, b])
        #expect(final.snapshots[0].selectedAt == reselection)
        #expect(final.snapshots[0].snapshot.verifiedAt == now.addingTimeInterval(40))
    }

    @Test("Cancellation after commit returns the committed outcome")
    func cancellationAfterCommit() async throws {
        let store = try store()
        let date = now
        let region = try scope()
        try await store.selectCoverage(region, at: now)
        let client = try client(.init(mode: .empty))
        let task = Task {
            let committed = try await store.refreshCoverage(scope: region, client: client, date: { date })
            withUnsafeCurrentTask { $0?.cancel() }
            return committed
        }
        let committed = try await task.value
        #expect(try await store.acceptedCoverage(at: now).snapshots == [committed])
    }

    @Test("Shared request, decoded-byte and deadline budgets span both scans")
    func sharedBudgets() async throws {
        let requestFixture = WSSIClientTests.Fixture(mode: .empty)
        let limited = try WSSIClient(limits: .init(maximumRequests: 61), transport: { try await requestFixture.get($0, $1) })
        let date = now
        await #expect(throws: WSSIAcquisitionError.requestLimit) { try await limited.acquireVerified(scope: scope(), date: { date }) }
        #expect(await requestFixture.count == 61)
        let reference = try await client(.init(mode: .empty)).acquire(scope: scope())
        let bytes = reference.layers.flatMap(\.requests).reduce(0) { $0 + $1.decodedByteCount }
        let byteFixture = WSSIClientTests.Fixture(mode: .empty)
        let byteLimited = try WSSIClient(limits: .init(maximumTotalBytes: bytes + 1), transport: { try await byteFixture.get($0, $1) })
        await #expect(throws: WSSIAcquisitionError.responseTooLarge) { try await byteLimited.acquireVerified(scope: scope(), date: { date }) }
        #expect(await byteFixture.count == 61)
        #expect(await byteFixture.ceilings.last == 1)
        let clock = Mutex(ContinuousClock.now)
        let timeFixture = WSSIClientTests.Fixture(mode: .empty)
        let timed = try WSSIClient(limits: .init(acquisitionTimeout: .seconds(61)), now: { clock.withLock { $0 } },
            sleepUntil: { _ in try await Task.sleep(for: .seconds(3600)) }, transport: { request, ceiling in
                let response = try await timeFixture.get(request, ceiling)
                clock.withLock { $0 = $0.advanced(by: .seconds(1)) }
                return response
            })
        await #expect(throws: WSSIAcquisitionError.deadlineExceeded) { try await timed.acquireVerified(scope: scope(), date: { date }) }
        #expect(await timeFixture.count == 61)
    }

    @Test("Restart restores canonical cache, prunes expired data and preserves issuance fences")
    func restart() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("cache.store")
        let schema = Schema(versionedSchema: SkyAwarePersistenceSchema.self)
        func container() throws -> ModelContainer {
            try ModelContainer(for: schema, migrationPlan: SkyAwarePersistenceMigrationPlan.self,
                               configurations: ModelConfiguration(schema: schema, url: url))
        }
        let date = now
        var expected: WSSICachedSnapshot?
        do {
            let store = WSSISnapshotStore(modelContainer: try container())
            try await store.selectCoverage(scope(), at: now)
            expected = try await store.refreshCoverage(scope: scope(), client: client(.init()), date: { date })
        }
        do {
            let store = WSSISnapshotStore(modelContainer: try container())
            let restored = try await store.acceptedCoverage(at: now)
            #expect(restored.snapshots.first == expected)
            #expect(restored.selectedScope == (try scope()))
            let probe = Probe(fixture: .init(), olderIssuance: true)
            let stale = try WSSIClient(transport: { try await probe.get($0, $1) })
            await #expect(throws: WSSISnapshotError.staleIssuance) {
                try await store.refreshCoverage(scope: scope(), client: stale, date: { date })
            }
            #expect(try await store.acceptedCoverage(at: now).snapshots.first == expected)
        }
        let store = WSSISnapshotStore(modelContainer: try container())
        #expect(try await store.acceptedCoverage(at: now.addingTimeInterval(3 * 86400)).snapshots.isEmpty)
        #expect(try await store.issuanceWatermarks().count == 20)
    }

    actor Gate {
        var entered = false
        var entryWaiters: [CheckedContinuation<Void, Never>] = []
        var release: CheckedContinuation<Void, Never>?
        func pause() async {
            entered = true
            entryWaiters.forEach { $0.resume() }; entryWaiters = []
            await withCheckedContinuation { release = $0 }
        }
        func waitForEntry() async {
            if !entered { await withCheckedContinuation { entryWaiters.append($0) } }
        }
        func open() { release?.resume(); release = nil }
    }

    actor Probe {
        let fixture: WSSIClientTests.Fixture
        let gate: Gate?
        let pauseAt: Int
        let changedField: String?
        let olderIssuance: Bool
        let varyLayerIssuance: Bool
        var count = 0
        var conditionalRequests = 0
        init(fixture: WSSIClientTests.Fixture, gate: Gate? = nil, pauseAt: Int = 1,
             changedField: String? = nil, olderIssuance: Bool = false, varyLayerIssuance: Bool = false) {
            self.fixture = fixture; self.gate = gate; self.pauseAt = pauseAt
            self.changedField = changedField; self.olderIssuance = olderIssuance; self.varyLayerIssuance = varyLayerIssuance
        }
        func get(_ request: URLRequest, _ ceiling: Int) async throws -> HTTPResponse {
            count += 1
            if request.value(forHTTPHeaderField: "If-None-Match") != nil { conditionalRequests += 1 }
            if count == pauseAt, let gate { await gate.pause() }
            let response = try await fixture.get(request, ceiling)
            guard let body = response.data, var text = String(data: body, encoding: .utf8) else { return response }
            if olderIssuance { text = text.replacingOccurrences(of: "2116Z", with: "1916Z") }
            if varyLayerIssuance && request.url?.path.contains("/2/query") == true {
                text = text.replacingOccurrences(of: "2116Z", with: "1916Z")
                text = text.replacingOccurrences(of: "18Z 11/12/26", with: "18Z 11/13/26")
                    .replacingOccurrences(of: "21Z 11/11/26", with: "18Z 11/12/26")
            }
            if let field = changedField, count > 80 || field == "mixed" {
                if field == "apiSecond" {
                    return HTTPResponse(status: 200, headers: [:], data: Data("{\"error\":{\"code\":400}}".utf8))
                }
                if field == "ids" {
                    text = text.replacingOccurrences(of: "\"objectid\":2", with: "\"objectid\":3")
                        .replacingOccurrences(of: "[1,2]", with: "[1,3]")
                }
                if field == "impact" { text = text.replacingOccurrences(of: "MAJOR", with: "MINOR") }
                if field == "geometry" { text = text.replacingOccurrences(of: "-120", with: "-119") }
                if field == "issuance" || (field == "mixed" && count % 80 == 3) {
                    text = text.replacingOccurrences(of: "2116Z", with: "1916Z")
                }
            }
            return HTTPResponse(status: response.status, headers: response.headers, data: Data(text.utf8))
        }
    }
}
