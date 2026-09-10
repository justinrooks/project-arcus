import Foundation
import Testing
@testable import SkyAware

@Suite("WidgetSnapshotStore")
struct WidgetSnapshotStoreTests {
    @Test("load returns missing when no snapshot exists")
    func load_missingSnapshot_returnsMissing() throws {
        let sandbox = try makeSandboxDirectory()
        let store = WidgetSnapshotStore(directoryURL: sandbox)

        #expect(store.load() == .missing)
    }

    @Test("load returns corrupt for unreadable snapshot data")
    func load_corruptData_returnsCorrupt() throws {
        let sandbox = try makeSandboxDirectory()
        let payloadURL = sandbox.appendingPathComponent("widget-snapshot.json")
        try fileManager.createDirectory(at: sandbox, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: payloadURL, options: [.atomic])

        let store = WidgetSnapshotStore(directoryURL: sandbox)

        #expect(store.load() == .corrupt)
    }

    @Test("write then load preserves snapshot")
    func writeLoad_roundTrip() throws {
        let sandbox = try makeSandboxDirectory()
        let store = WidgetSnapshotStore(directoryURL: sandbox)
        let snapshot = makeSnapshot(freshness: .from(timestamp: iso("2026-05-01T11:40:00Z"), now: iso("2026-05-01T12:00:00Z")))

        try store.write(snapshot)

        let loaded = store.load()
        #expect(loaded == .snapshot(snapshot))
    }

    @Test("write then load preserves stale freshness metadata")
    func writeLoad_staleMetadataPreserved() throws {
        let sandbox = try makeSandboxDirectory()
        let store = WidgetSnapshotStore(directoryURL: sandbox)

        let staleFreshness = WidgetFreshnessState(
            timestamp: iso("2026-05-01T11:00:00Z"),
            state: .stale
        )
        let snapshot = makeSnapshot(freshness: staleFreshness)

        try store.write(snapshot)

        let loaded = store.load()
        guard case .snapshot(let restored) = loaded else {
            Issue.record("Expected snapshot, got \(loaded)")
            return
        }

        #expect(restored.freshness == staleFreshness)
        #expect(restored.freshness.state == .stale)
        #expect(restored == snapshot)
    }

    @Test("load accepts a legacy no-alert snapshot without the active alert collection")
    func load_legacyNoAlertSnapshot_defaultsActiveAlerts() throws {
        let sandbox = try makeSandboxDirectory()
        let payloadURL = sandbox.appendingPathComponent("widget-snapshot.json")
        let snapshot = WidgetSnapshot(
            generatedAt: iso("2026-05-01T12:00:00Z"),
            stormRisk: .placeholder,
            severeRisk: .placeholder,
            selectedAlert: nil,
            hiddenAlertCount: 0,
            freshness: .from(timestamp: iso("2026-05-01T12:00:00Z"), now: iso("2026-05-01T12:00:00Z")),
            availability: .available
        )
        let encoded = try JSONEncoder().encode(snapshot)
        var legacyPayload = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyPayload.removeValue(forKey: "activeAlerts")
        legacyPayload.removeValue(forKey: "selectedAlert")
        try JSONSerialization.data(withJSONObject: legacyPayload).write(to: payloadURL, options: [.atomic])

        let store = WidgetSnapshotStore(directoryURL: sandbox)
        let loaded = try #require(store.load().snapshot)

        #expect(loaded.selectedAlert == nil)
        #expect(loaded.activeAlerts.isEmpty)
        #expect(loaded.hiddenAlertCount == 0)
    }

    private let fileManager = FileManager.default

    private func makeSandboxDirectory() throws -> URL {
        let url = fileManager.temporaryDirectory
            .appendingPathComponent("WidgetSnapshotStoreTests")
            .appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeSnapshot(freshness: WidgetFreshnessState) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: iso("2026-05-01T12:00:00Z"),
            stormRisk: .init(label: "Slight Risk", severity: 3),
            severeRisk: .init(label: "Tornado", severity: 3),
            selectedAlert: .init(
                title: "Tornado Warning",
                typeLabel: "Warning",
                severity: 3,
                issuedAt: iso("2026-05-01T11:58:00Z")
            ),
            hiddenAlertCount: 1,
            freshness: freshness,
            availability: .available,
            destination: .summary
        )
    }
}

private extension WidgetSnapshotStoreLoadResult {
    var snapshot: WidgetSnapshot? {
        guard case .snapshot(let snapshot) = self else { return nil }
        return snapshot
    }
}

private func iso(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)!
}
