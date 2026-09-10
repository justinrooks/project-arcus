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

    @Test("decodes legacy snapshot without alert freshness")
    func decodesLegacySnapshot_withoutAlertFreshness() throws {
        let snapshot = WidgetSnapshot(
            generatedAt: iso("2026-05-01T12:00:00Z"),
            stormRisk: .init(label: "Slight Risk", severity: 3),
            severeRisk: .init(label: "Tornado", severity: 3),
            selectedAlert: nil,
            hiddenAlertCount: 0,
            freshness: .from(timestamp: iso("2026-05-01T11:55:00Z"), now: iso("2026-05-01T12:00:00Z")),
            alertFreshness: .from(timestamp: iso("2026-05-01T11:59:00Z"), now: iso("2026-05-01T12:00:00Z")),
            availability: .available
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let currentPayload = try #require(JSONSerialization.jsonObject(with: encoder.encode(snapshot)) as? [String: Any])
        var legacyPayload = currentPayload
        legacyPayload.removeValue(forKey: "alertFreshness")

        let legacyData = try JSONSerialization.data(withJSONObject: legacyPayload)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetSnapshot.self, from: legacyData)

        #expect(decoded.freshness == snapshot.freshness)
        #expect(decoded.alertFreshness == nil)
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

    @Test("normalization marks stale snapshots and suppresses expired selected alerts")
    func normalizedForWidgetPresentation_suppressesExpiredAlert() {
        let snapshot = WidgetSnapshot(
            generatedAt: iso("2026-05-01T11:20:00Z"),
            stormRisk: .init(label: "Enhanced Risk", severity: 4),
            severeRisk: .init(label: "Tornado", severity: 3),
            selectedAlert: .init(
                title: "Tornado Warning",
                typeLabel: "Tornado Warning",
                severity: 5,
                issuedAt: iso("2026-05-01T10:55:00Z"),
                validEnd: iso("2026-05-01T11:50:00Z")
            ),
            hiddenAlertCount: 2,
            freshness: .from(
                timestamp: iso("2026-05-01T03:00:00Z"),
                now: iso("2026-05-01T11:25:00Z")
            ),
            availability: .available
        )

        let normalized = snapshot.normalizedForWidgetPresentation(at: iso("2026-05-01T12:00:00Z"))

        #expect(normalized.freshness.state == .stale)
        #expect(normalized.selectedAlert == nil)
        #expect(normalized.hiddenAlertCount == 0)
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

@Suite("Widget snapshot relevance")
struct WidgetSnapshotRelevanceTests {
    private let now = Date(timeIntervalSince1970: 1_777_700_000)

    @Test("quiet and unavailable snapshots remain neutral")
    func quietAndUnavailable_areNeutral() {
        #expect(WidgetSnapshotRelevancePolicy.relevance(for: makeSnapshot(), now: now) == nil)
        #expect(WidgetSnapshotRelevancePolicy.relevance(for: .unavailable(generatedAt: now), now: now) == nil)
    }

    @Test("alert classes follow warning, watch, mesoscale precedence")
    func alertClasses_haveDescendingScores() {
        let warning = relevance(alertType: "Warning")
        let watch = relevance(alertType: "Watch")
        let mesoscale = relevance(alertType: "Mesoscale Discussion")

        #expect(warning.score > watch.score)
        #expect(watch.score > mesoscale.score)
    }

    @Test("elevated risk is relevant but remains below active alerts")
    func elevatedRisk_staysBelowAlerts() {
        let storm = WidgetSnapshotRelevancePolicy.relevance(for: makeSnapshot(stormSeverity: 6), now: now)
        let severe = WidgetSnapshotRelevancePolicy.relevance(for: makeSnapshot(severeSeverity: 3), now: now)
        let warning = relevance(alertType: "Warning")
        let mesoscale = relevance(alertType: "Mesoscale Discussion")

        #expect(storm?.score ?? 0 > 0)
        #expect(severe?.score ?? 0 > 0)
        #expect((storm?.score ?? .greatestFiniteMagnitude) < mesoscale.score)
        #expect((severe?.score ?? .greatestFiniteMagnitude) < mesoscale.score)
        #expect((storm?.score ?? .greatestFiniteMagnitude) < warning.score)
        #expect((severe?.score ?? .greatestFiniteMagnitude) < warning.score)
    }

    @Test("risk-only relevance ignores alerts and the other risk domain")
    func riskOnlyRelevance_isScopedToVisibleRisk() {
        let snapshot = makeSnapshot(
            alertType: "Tornado Warning",
            stormSeverity: 0,
            severeSeverity: 3
        )

        #expect(WidgetSnapshotRelevancePolicy.relevance(
            for: snapshot,
            surface: .stormRisk,
            now: now
        ) == nil)
        #expect(WidgetSnapshotRelevancePolicy.relevance(
            for: snapshot,
            surface: .severeRisk,
            now: now
        )?.score == 40)
    }

    @Test("risk relevance uses the slow-product freshness cadence")
    func riskRelevance_usesEightHourCadence() {
        let snapshot = makeSnapshot(
            stormSeverity: 3,
            timestamp: now.addingTimeInterval(-31 * 60)
        )

        #expect(WidgetSnapshotRelevancePolicy.relevance(
            for: snapshot,
            surface: .stormRisk,
            now: now
        ) != nil)
        #expect(WidgetSnapshotRelevancePolicy.relevance(
            for: makeSnapshot(stormSeverity: 3, timestamp: now.addingTimeInterval(-8 * 60 * 60)),
            surface: .stormRisk,
            now: now
        ) == nil)
    }

    @Test("combined relevance uses alert freshness independently from risk freshness")
    func combinedRelevance_usesDomainSpecificFreshness() {
        let snapshot = WidgetSnapshot(
            generatedAt: now,
            stormRisk: .init(label: "Enhanced Risk", severity: 4),
            severeRisk: .init(label: "Threat", severity: 0),
            selectedAlert: .init(title: "Tornado Warning", typeLabel: "Warning", severity: 5, issuedAt: now),
            hiddenAlertCount: 0,
            freshness: .init(timestamp: now, state: .fresh),
            alertFreshness: .init(timestamp: now.addingTimeInterval(-WidgetFreshnessState.staleThreshold), state: .stale),
            availability: .available
        )

        let relevance = WidgetSnapshotRelevancePolicy.relevance(for: snapshot, now: now)
        #expect(relevance?.score == 30)
    }

    @Test("stale and expired states have no relevance")
    func staleAndExpired_haveNoRelevance() {
        let stale = makeSnapshot(freshness: .stale)
        let expired = makeSnapshot(alertType: "Warning", validEnd: now.addingTimeInterval(-1))

        #expect(WidgetSnapshotRelevancePolicy.relevance(for: stale, now: now) == nil)
        #expect(WidgetSnapshotRelevancePolicy.relevance(for: expired, now: now) == nil)
    }

    @Test("relevance duration is bounded by freshness and alert validity")
    func duration_isBounded() {
        let snapshot = makeSnapshot(
            alertType: "Warning",
            validEnd: now.addingTimeInterval(120),
            timestamp: now.addingTimeInterval(-60)
        )

        #expect(WidgetSnapshotRelevancePolicy.relevance(for: snapshot, now: now)?.duration == 120)
    }

    private func relevance(alertType: String) -> WidgetSnapshotRelevance {
        WidgetSnapshotRelevancePolicy.relevance(for: makeSnapshot(alertType: alertType), now: now)!
    }

    private func makeSnapshot(
        alertType: String? = nil,
        validEnd: Date? = nil,
        stormSeverity: Int = 0,
        severeSeverity: Int = 0,
        freshness: WidgetFreshnessState.State = .fresh,
        timestamp: Date? = nil
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: now,
            stormRisk: .init(label: "Risk", severity: stormSeverity),
            severeRisk: .init(label: "Threat", severity: severeSeverity),
            selectedAlert: alertType.map {
                .init(title: $0, typeLabel: $0, severity: 1, issuedAt: now, validEnd: validEnd)
            },
            hiddenAlertCount: 0,
            freshness: .init(timestamp: timestamp ?? now, state: freshness),
            alertFreshness: alertType.map { _ in .init(timestamp: now, state: freshness) },
            availability: .available
        )
    }
}
