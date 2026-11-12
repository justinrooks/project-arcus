import Foundation
import SwiftData
import Testing
@testable import SkyAware

@MainActor
struct WSSISnapshotStoreTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("V7 layers and unrelated data survive V8 migration; snapshot states survive reopen")
    func migrationAndRestart() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("cache.store")
        do {
            let schema = Schema(versionedSchema: SkyAwarePersistenceSchemaV7.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(container)
            let input = try snapshot()
            let layer = try #require(try input.layers.first?.assessmentLayer(in: input.scope))
            context.insert(try WSSIForecastLayer(layer: layer, acceptedAt: now, provenance: "legacy"))
            context.insert(ConvectiveOutlook(title: "Preserved", link: URL(fileURLWithPath: "/forecast"),
                                            published: now, fullText: "Text", summary: "Summary", day: 1,
                                            riskLevel: "SLGT", issued: now, validUntil: now.addingTimeInterval(3600)))
            try context.save()
        }
        var expected: WSSICachedSnapshot?
        do {
            let container = try container(at: url)
            let store = WSSISnapshotStore(modelContainer: container)
            #expect(try await store.read().isEmpty) // Legacy layers do not prove canonical acceptance.
            expected = try await store.replace(with: snapshot(), select: true, now: now)
        }
        let reopened = try container(at: url)
        let store = WSSISnapshotStore(modelContainer: reopened)
        let restored = try #require(await store.read().first)
        #expect(restored == expected)
        #expect(restored.snapshot.layers.count == 20)
        #expect(try restored.snapshot.layers[1].assessmentLayer(in: restored.snapshot.scope) == nil)
        let identifiedEmpty = try #require(try restored.snapshot.layers[2].assessmentLayer(in: restored.snapshot.scope))
        #expect(identifiedEmpty.features.isEmpty)
        let positive = try #require(try restored.snapshot.layers[0].assessmentLayer(in: restored.snapshot.scope))
        #expect(positive.features.map(\.impact) == WSSIImpact.allCases)
        #expect(positive.features.first?.polygons.first?.rings.count == 2)
        #expect(try await store.issuanceWatermarks().count == 15)
        let context = ModelContext(reopened)
        #expect(try context.fetch(FetchDescriptor<WSSIForecastLayer>()).first?.provenance == "legacy")
        #expect(try context.fetch(FetchDescriptor<ConvectiveOutlook>()).first?.title == "Preserved")
    }

    @Test("Failure, cancellation and corruption never expose a partial replacement")
    func rollbackAndCorruption() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("cache.store")
        var expected: WSSICachedSnapshot?
        var expectedWatermarks: [WSSIIssuanceWatermark] = []
        do {
            let container = try container(at: url)
            let store = WSSISnapshotStore(modelContainer: container)
            let original = try await store.replace(with: snapshot(), select: true, now: now)
            expected = original
            expectedWatermarks = try await store.issuanceWatermarks()
            await #expect(throws: WSSISnapshotError.injectedFailure) {
                try await store.replace(with: snapshot(issueOffset: 60), select: true, now: now,
                                        failureAfterMutation: true)
            }
            let cancelled = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await store.replace(with: snapshot(issueOffset: 60), select: true, now: now)
            }
            await #expect(throws: CancellationError.self) { try await cancelled.value }
            #expect(try await store.read() == [original])
            #expect(try await store.issuanceWatermarks().allSatisfy { $0.issuedAt == now.addingTimeInterval(-3600) })
        }
        let reopened = try container(at: url)
        let store = WSSISnapshotStore(modelContainer: reopened)
        #expect(try await store.read().first == expected)
        #expect(try await store.issuanceWatermarks() == expectedWatermarks)
        let context = ModelContext(reopened)
        let row = try #require(context.fetch(FetchDescriptor<WSSICacheRecord>()).first)
        row.payload = Data("{bad payload".utf8)
        try context.save()
        // Use a fresh actor/context so SwiftData's identity cache cannot hide the disk corruption.
        let reader = WSSISnapshotStore(modelContainer: reopened)
        await #expect(throws: (any Error).self) { try await reader.read() }
    }

    @Test("Revalidation, conflict rejection, two-scope retention and durable issuance fencing")
    func orderingAndRetention() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("cache.store")
        do {
            let store = WSSISnapshotStore(modelContainer: try container(at: url))
            let original = try await store.replace(with: snapshot(), select: true, now: now)
            let later = now.addingTimeInterval(60)
            let revalidated = try await store.replace(with: snapshot(verifiedAt: later), select: true, now: later)
            #expect(revalidated.revision == original.revision)
            #expect(revalidated.committedAt == original.committedAt)
            #expect(try await store.read().first?.snapshot.verifiedAt == later)
            await #expect(throws: WSSISnapshotError.conflictingIssuance) {
                try await store.replace(with: snapshot(impact: .extreme), select: true, now: now)
            }
            _ = try await store.replace(with: snapshot(west: 20), select: true, now: now)
            #expect(try await store.read().map(\.snapshot.scope.west) == [20, 0])
            // Selection order survives backward wall-clock movement.
            _ = try await store.replace(with: snapshot(west: 40), select: true, now: now)
            #expect(try await store.read().map(\.snapshot.scope.west) == [40, 20])
            _ = try await store.replace(with: snapshot(west: 40, allEmpty: true), select: true, now: now)
            #expect(try await store.issuanceWatermarks().count == 15)
            try await store.prune(now: now.addingTimeInterval(86_400))
            #expect(try await store.read().isEmpty)
        }
        let store = WSSISnapshotStore(modelContainer: try container(at: url))
        #expect(try await store.issuanceWatermarks().count == 15)
        await #expect(throws: WSSISnapshotError.staleIssuance) {
            try await store.replace(with: snapshot(issueOffset: -60), select: true, now: now)
        }
    }

    @Test("Invalid vectors and fabricated empty timestamps are rejected before mutation")
    func invalidSnapshots() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = WSSISnapshotStore(modelContainer: try container(at: root.appendingPathComponent("cache.store")))
        let valid = try snapshot()
        var layers = valid.layers
        layers[1] = layers[0]
        let duplicate = WSSISnapshot(scope: valid.scope, source: valid.source, acquisitionStartedAt: now,
                                     verifiedAt: now, provenance: "test", layers: layers)
        await #expect(throws: WSSISnapshotError.invalidSnapshot) {
            try await store.replace(with: duplicate, select: true, now: now)
        }
        let fabricated = WSSISnapshotLayer(product: .overall, period: .day1, state: .observedEmpty,
                                           issuedAt: now, validFrom: nil, validTo: nil, features: [])
        #expect(throws: WSSISnapshotError.invalidSnapshot) { try fabricated.assessmentLayer(in: valid.scope) }
        #expect(try await store.read().isEmpty)
    }

    @Test("Retention respects future windows, clock reversal and encoded byte pressure")
    func retentionLimits() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try container(at: root.appendingPathComponent("cache.store"))
        let store = WSSISnapshotStore(modelContainer: container)
        let input = try snapshot(validityDuration: 172800)
        _ = try await store.replace(with: input, select: true, now: now)
        try await store.prune(now: now.addingTimeInterval(-86400))
        try await store.prune(now: now.addingTimeInterval(86400))
        #expect(try await store.read().count == 1)
        let context = ModelContext(container)
        let bytes = try #require(context.fetch(FetchDescriptor<WSSICacheRecord>()).first).payload.count
        // A second scope fits alone but the combined cache exceeds this reduced test budget.
        _ = try await store.replace(with: snapshot(west: 20, validityDuration: 172800), select: true,
                                    now: now, byteLimit: bytes * 3 / 2)
        #expect(try await store.read().map(\.snapshot.scope.west) == [20])
        await #expect(throws: WSSISnapshotError.capacityExceeded) {
            try await store.replace(with: snapshot(west: 40), select: true, now: now, byteLimit: 1)
        }
        #expect(try await store.read().map(\.snapshot.scope.west) == [20])
        try await store.prune(now: now.addingTimeInterval(172800))
        #expect(try await store.read().isEmpty)
        #expect(try await store.issuanceWatermarks().count == 15)
    }

    @Test("Empty observations retain the same-issuance conflict fence across restart")
    func emptyConflictFence() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("cache.store")
        var empty: WSSICachedSnapshot?
        var watermarks: [WSSIIssuanceWatermark] = []
        do {
            let store = WSSISnapshotStore(modelContainer: try container(at: url))
            _ = try await store.replace(with: snapshot(), select: true, now: now)
            empty = try await store.replace(with: snapshot(allEmpty: true), select: true, now: now)
            watermarks = try await store.issuanceWatermarks()
            await #expect(throws: WSSISnapshotError.conflictingIssuance) {
                try await store.replace(with: snapshot(impact: .extreme), select: true, now: now)
            }
            #expect(try await store.read().first == empty)
            #expect(try await store.issuanceWatermarks() == watermarks)
        }
        let store = WSSISnapshotStore(modelContainer: try container(at: url))
        #expect(try await store.read().first == empty)
        #expect(try await store.issuanceWatermarks() == watermarks)
        await #expect(throws: WSSISnapshotError.conflictingIssuance) {
            try await store.replace(with: snapshot(impact: .extreme), select: true, now: now)
        }
        let newer = try await store.replace(with: snapshot(issueOffset: 1, impact: .extreme), select: true, now: now)
        #expect(newer.snapshot.layers.first?.issuedAt == now.addingTimeInterval(-3599))
    }

    @Test("Independent per-layer dates survive reopen; regression of one layer rejects the whole snapshot")
    func independentLayerIdentities() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("cache.store")
        let base = try snapshot()
        let mixed = replacingLayers(in: base, with: base.layers.enumerated().map { index, layer in
            shifted(layer, by: TimeInterval(index * 30))
        })
        var accepted: WSSICachedSnapshot?
        var watermarks: [WSSIIssuanceWatermark] = []
        do {
            let store = WSSISnapshotStore(modelContainer: try container(at: url))
            _ = try await store.replace(with: mixed, select: true, now: now)
            var layers = mixed.layers
            layers[0] = shifted(layers[0], by: 1)
            accepted = try await store.replace(with: replacingLayers(in: mixed, with: layers), select: true, now: now)
            watermarks = try await store.issuanceWatermarks()
        }
        let store = WSSISnapshotStore(modelContainer: try container(at: url))
        #expect(try await store.read().first == accepted)
        await #expect(throws: WSSISnapshotError.staleIssuance) {
            try await store.replace(with: mixed, select: true, now: now)
        }
        #expect(try await store.read().first == accepted)
        #expect(try await store.issuanceWatermarks() == watermarks)
    }

    @Test("Inactive-scope revalidation cannot change selection order, including after restart")
    func inactiveScope() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("cache.store")
        var expected: [WSSICachedSnapshot] = []
        do {
            let store = WSSISnapshotStore(modelContainer: try container(at: url))
            let original = try await store.replace(with: snapshot(), select: true, now: now)
            _ = try await store.replace(with: snapshot(west: 20), select: true, now: now.addingTimeInterval(1))
            let later = now.addingTimeInterval(60)
            let inactive = try await store.replace(with: snapshot(verifiedAt: later), select: false, now: later)
            #expect(inactive.selectedAt == original.selectedAt)
            #expect(inactive.revision == original.revision)
            #expect(try await store.read().map(\.snapshot.scope.west) == [20, 0])
            expected = try await store.read()
        }
        let store = WSSISnapshotStore(modelContainer: try container(at: url))
        #expect(try await store.read() == expected)
    }

    private func replacingLayers(in snapshot: WSSISnapshot, with layers: [WSSISnapshotLayer]) -> WSSISnapshot {
        WSSISnapshot(scope: snapshot.scope, source: snapshot.source,
                     acquisitionStartedAt: snapshot.acquisitionStartedAt, verifiedAt: snapshot.verifiedAt,
                     provenance: snapshot.provenance, layers: layers)
    }

    private func shifted(_ layer: WSSISnapshotLayer, by offset: TimeInterval) -> WSSISnapshotLayer {
        guard let issued = layer.issuedAt, let from = layer.validFrom, let to = layer.validTo else { return layer }
        let features = layer.features.map {
            WSSIFeature(product: $0.product, period: $0.period, impact: $0.impact,
                        issuedAt: issued.addingTimeInterval(offset), validFrom: from.addingTimeInterval(offset),
                        validTo: to.addingTimeInterval(offset), polygons: $0.polygons)
        }
        return WSSISnapshotLayer(product: layer.product, period: layer.period, state: layer.state,
                                 issuedAt: issued.addingTimeInterval(offset), validFrom: from.addingTimeInterval(offset),
                                 validTo: to.addingTimeInterval(offset), features: features)
    }

    @Test("Selection timestamp growth cannot persist an oversized cache, including after reopen")
    func selectionByteLimit() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("cache.store")
        var expected: [WSSICachedSnapshot] = []
        do {
            let container = try container(at: url)
            let store = WSSISnapshotStore(modelContainer: container)
            let original = try await store.replace(with: snapshot(), select: true, now: now)
            let rows = try ModelContext(container).fetch(FetchDescriptor<WSSICacheRecord>())
            let bytes = try #require(rows.first).payload.count
            // An integer timestamp becomes fractional; one scope cannot evict itself to make room.
            await #expect(throws: WSSISnapshotError.capacityExceeded) {
                try await store.selectRetainedScope(original.snapshot.scope, now: now.addingTimeInterval(0.125),
                                                     byteLimit: bytes)
            }
            #expect(try await store.read() == [original])
            _ = try await store.replace(with: snapshot(west: 20), select: true, now: now)
            let combined = try ModelContext(container).fetch(FetchDescriptor<WSSICacheRecord>())
            let combinedBytes = try #require(combined.first).payload.count
            try await store.selectRetainedScope(original.snapshot.scope, now: now.addingTimeInterval(0.125),
                                                byteLimit: combinedBytes)
            expected = try await store.read()
            #expect(expected.map(\.snapshot.scope.west) == [0])
            let limited = try ModelContext(container).fetch(FetchDescriptor<WSSICacheRecord>())
            #expect(try #require(limited.first).payload.count <= combinedBytes)
        }
        let store = WSSISnapshotStore(modelContainer: try container(at: url))
        #expect(try await store.read() == expected)
    }

    @Test("Empty startup pruning does not create a canonical record, including after reopen")
    func emptyStartupDoesNotWrite() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("cache.store")
        do {
            let container = try container(at: url)
            let store = WSSISnapshotStore(modelContainer: container)
            _ = try await store.acceptedCoverage(at: now)
            #expect(try ModelContext(container).fetchCount(FetchDescriptor<WSSICacheRecord>()) == 0)
        }
        let reopened = try container(at: url)
        #expect(try ModelContext(reopened).fetchCount(FetchDescriptor<WSSICacheRecord>()) == 0)
    }

    @Test("Healthy no-op prune skips persistence; changed prune rolls back on failure")
    func prunePersistenceBoundary() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("cache.store")
        var expected: [WSSICachedSnapshot] = []
        var watermarks: [WSSIIssuanceWatermark] = []
        do {
            let store = WSSISnapshotStore(modelContainer: try container(at: url))
            _ = try await store.replace(with: snapshot(), select: true, now: now)
            expected = try await store.read()
            watermarks = try await store.issuanceWatermarks()
            // The injected persistence failure must be unreachable for a healthy no-op.
            try await store.prune(now: now, failureAfterMutation: true)
            await #expect(throws: WSSISnapshotError.injectedFailure) {
                try await store.prune(now: now.addingTimeInterval(86400), failureAfterMutation: true)
            }
            #expect(try await store.read() == expected)
        }
        let store = WSSISnapshotStore(modelContainer: try container(at: url))
        #expect(try await store.read() == expected)
        #expect(try await store.issuanceWatermarks() == watermarks)
        try await store.prune(now: now.addingTimeInterval(86400))
        #expect(try await store.read().isEmpty)
        #expect(try await store.issuanceWatermarks() == watermarks)
    }

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func container(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SkyAwarePersistenceSchema.self)
        return try ModelContainer(for: schema, migrationPlan: SkyAwarePersistenceMigrationPlan.self,
                                  configurations: ModelConfiguration(schema: schema, url: url))
    }

    private func snapshot(west: Double = 0, issueOffset: TimeInterval = 0, verifiedAt: Date? = nil,
                          impact: WSSIImpact? = nil, allEmpty: Bool = false, validityDuration: TimeInterval = 3600) throws -> WSSISnapshot {
        let scope = try WSSIScope(south: 0, west: west, north: 10, east: west + 10)
        let ring = [Coordinate2D(latitude: 1, longitude: west + 1), Coordinate2D(latitude: 1, longitude: west + 9),
                    Coordinate2D(latitude: 9, longitude: west + 9), Coordinate2D(latitude: 9, longitude: west + 1),
                    Coordinate2D(latitude: 1, longitude: west + 1)]
        let hole = [Coordinate2D(latitude: 2, longitude: west + 2), Coordinate2D(latitude: 2, longitude: west + 3),
                    Coordinate2D(latitude: 3, longitude: west + 3), Coordinate2D(latitude: 3, longitude: west + 2),
                    Coordinate2D(latitude: 2, longitude: west + 2)]
        let issued = now.addingTimeInterval(-3600 + issueOffset)
        let end = now.addingTimeInterval(validityDuration)
        let layers = WSSIProduct.allCases.flatMap { product in
            WSSIPeriod.allCases.enumerated().map { index, period in
                let state: WSSISnapshotLayer.State = allEmpty || index == 1 ? .observedEmpty
                    : index == 2 ? .identifiedEmpty : .identifiedData
                let features = state == .identifiedData ? (impact.map { [$0] } ?? WSSIImpact.allCases).map {
                    WSSIFeature(product: product, period: period, impact: $0, issuedAt: issued,
                                validFrom: now, validTo: end, polygons: [WSSIPolygon(rings: [ring, hole])])
                } : []
                return WSSISnapshotLayer(product: product, period: period, state: state,
                                         issuedAt: state == .observedEmpty ? nil : issued,
                                         validFrom: state == .observedEmpty ? nil : now,
                                         validTo: state == .observedEmpty ? nil : end, features: features)
            }
        }
        return WSSISnapshot(scope: scope,
                            source: URL(string: "https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/wpc_wssi/MapServer")!,
                            acquisitionStartedAt: now, verifiedAt: verifiedAt ?? now, provenance: "fixture", layers: layers)
    }
}
