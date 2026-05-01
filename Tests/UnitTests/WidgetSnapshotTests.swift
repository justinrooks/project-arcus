import Foundation
import Testing
@testable import SkyAware

@Suite("WidgetSnapshot")
struct WidgetSnapshotTests {
    @Test("encodes and decodes snapshot deterministically")
    func encodeDecode_roundTrip() throws {
        let snapshot = WidgetSnapshot(
            generatedAt: iso("2026-05-01T12:00:00Z"),
            stormRisk: .init(label: "Slight Risk", severity: 3),
            severeRisk: .init(label: "Tornado", severity: 3),
            selectedAlert: .init(
                title: "Tornado Warning",
                typeLabel: "Warning",
                severity: 3,
                issuedAt: iso("2026-05-01T11:58:00Z")
            ),
            hiddenAlertCount: 2,
            freshness: .from(
                timestamp: iso("2026-05-01T11:55:00Z"),
                now: iso("2026-05-01T12:00:00Z")
            ),
            availability: .available,
            destination: .summary
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(WidgetSnapshot.self, from: data)
        #expect(decoded == snapshot)

        let reEncoded = try encoder.encode(decoded)
        #expect(String(decoding: data, as: UTF8.self) == String(decoding: reEncoded, as: UTF8.self))
    }

    @Test("stale threshold marks snapshots stale at 30 minutes")
    func staleThreshold_isThirtyMinutes() {
        let updatedAt = iso("2026-05-01T10:00:00Z")

        let justBefore = WidgetFreshnessState.from(
            timestamp: updatedAt,
            now: iso("2026-05-01T10:29:59Z")
        )
        #expect(justBefore.state == .fresh)

        let atThreshold = WidgetFreshnessState.from(
            timestamp: updatedAt,
            now: iso("2026-05-01T10:30:00Z")
        )
        #expect(atThreshold.state == .stale)

        #expect(atThreshold.isStale(at: iso("2026-05-01T10:35:00Z")))
    }

    @Test("unavailable snapshot provides fallback state and copy")
    func unavailableSnapshot_defaults() {
        let snapshot = WidgetSnapshot.unavailable(
            generatedAt: iso("2026-05-01T12:00:00Z"),
            timestamp: iso("2026-05-01T11:40:00Z")
        )

        #expect(snapshot.selectedAlert == nil)
        #expect(snapshot.hiddenAlertCount == 0)
        #expect(snapshot.destination == .summary)
        #expect(snapshot.freshness.state == .unavailable)

        if case .unavailable(let message) = snapshot.availability {
            #expect(message == WidgetSnapshot.unavailableMessage)
        } else {
            Issue.record("Expected unavailable availability state")
        }
    }

    @Test("encoded payload is derived and privacy-safe")
    func encodedPayload_isDerivedOnly() throws {
        let snapshot = WidgetSnapshot(
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
            freshness: .from(
                timestamp: iso("2026-05-01T11:40:00Z"),
                now: iso("2026-05-01T12:00:00Z")
            ),
            availability: .available
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        let allowedTopLevelKeys: Set<String> = [
            "generatedAt",
            "stormRisk",
            "severeRisk",
            "selectedAlert",
            "hiddenAlertCount",
            "freshness",
            "availability",
            "destination"
        ]

        #expect(Set(json.keys) == allowedTopLevelKeys)

        #expect(json["location"] == nil)
        #expect(json["token"] == nil)
        #expect(json["payload"] == nil)
    }
}

private func iso(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)!
}
