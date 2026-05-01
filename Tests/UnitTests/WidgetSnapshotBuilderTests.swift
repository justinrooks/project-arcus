import Foundation
import Testing
@testable import SkyAware

@Suite("WidgetSnapshotBuilder")
struct WidgetSnapshotBuilderTests {
    private let now = iso("2026-05-01T12:00:00Z")

    @Test("builds normal available snapshot")
    func normalState() {
        let builder = WidgetSnapshotBuilder()
        let input = WidgetSnapshotBuilder.Input(
            generatedAt: now,
            snapshotTimestamp: iso("2026-05-01T11:50:00Z"),
            availability: .available,
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.35),
            watches: [makeWatch(id: "w1", title: "Tornado Warning", issued: iso("2026-05-01T11:45:00Z"), validEnd: iso("2026-05-01T12:15:00Z"))],
            mesos: []
        )

        let snapshot = builder.build(from: input, now: now)

        #expect(snapshot.stormRisk == .init(label: "Slight Risk", severity: 3))
        #expect(snapshot.severeRisk == .init(label: "Tornado", severity: 3))
        #expect(snapshot.selectedAlert?.title == "Tornado Warning")
        #expect(snapshot.hiddenAlertCount == 0)
        #expect(snapshot.freshness.state == .fresh)
        #expect(snapshot.availability == .available)
    }

    @Test("builds deterministic no-alert state")
    func noAlertState() {
        let builder = WidgetSnapshotBuilder()
        let input = WidgetSnapshotBuilder.Input(
            generatedAt: now,
            snapshotTimestamp: now,
            availability: .available,
            stormRisk: .allClear,
            severeRisk: .allClear,
            watches: [],
            mesos: []
        )

        let snapshot = builder.build(from: input, now: now)

        #expect(snapshot.selectedAlert == nil)
        #expect(snapshot.hiddenAlertCount == 0)
        #expect(snapshot.stormRisk.label == "Clear Skies")
        #expect(snapshot.severeRisk.label == "No Active Threats")
    }

    @Test("multiple alerts produce selected alert plus hidden count")
    func multipleAlertsState() {
        let builder = WidgetSnapshotBuilder()
        let input = WidgetSnapshotBuilder.Input(
            generatedAt: now,
            snapshotTimestamp: now,
            availability: .available,
            stormRisk: .enhanced,
            severeRisk: .hail(probability: 0.2),
            watches: [
                makeWatch(id: "w1", title: "Special Weather Statement", issued: iso("2026-05-01T11:00:00Z"), validEnd: iso("2026-05-01T12:30:00Z")),
                makeWatch(id: "w2", title: "Severe Thunderstorm Warning", issued: iso("2026-05-01T11:05:00Z"), validEnd: iso("2026-05-01T12:30:00Z"))
            ],
            mesos: [
                makeMeso(number: 2001, issued: iso("2026-05-01T11:10:00Z"), validEnd: iso("2026-05-01T12:30:00Z"))
            ]
        )

        let snapshot = builder.build(from: input, now: now)

        #expect(snapshot.selectedAlert?.title == "Severe Thunderstorm Warning")
        #expect(snapshot.hiddenAlertCount == 2)
    }

    @Test("priority order matches v1 contract")
    func priorityOrder() {
        let builder = WidgetSnapshotBuilder()
        let input = WidgetSnapshotBuilder.Input(
            generatedAt: now,
            snapshotTimestamp: now,
            availability: .available,
            stormRisk: .moderate,
            severeRisk: .wind(probability: 0.1),
            watches: [
                makeWatch(id: "watch", title: "Special Weather Statement", issued: iso("2026-05-01T11:55:00Z"), validEnd: iso("2026-05-01T12:30:00Z")),
                makeWatch(id: "flood", title: "Flash Flood Warning", issued: iso("2026-05-01T11:54:00Z"), validEnd: iso("2026-05-01T12:30:00Z")),
                makeWatch(id: "severe", title: "Severe Thunderstorm Warning", issued: iso("2026-05-01T11:53:00Z"), validEnd: iso("2026-05-01T12:30:00Z")),
                makeWatch(id: "tornado", title: "Tornado Warning", issued: iso("2026-05-01T11:52:00Z"), validEnd: iso("2026-05-01T12:30:00Z"))
            ],
            mesos: [
                makeMeso(number: 1999, issued: iso("2026-05-01T11:59:00Z"), validEnd: iso("2026-05-01T12:30:00Z"))
            ]
        )

        let snapshot = builder.build(from: input, now: now)

        #expect(snapshot.selectedAlert?.title == "Tornado Warning")
        #expect(snapshot.selectedAlert?.typeLabel == "Warning")
    }

    @Test("hidden count excludes expired alerts")
    func hiddenCountIgnoresExpiredAlerts() {
        let builder = WidgetSnapshotBuilder()
        let input = WidgetSnapshotBuilder.Input(
            generatedAt: now,
            snapshotTimestamp: now,
            availability: .available,
            stormRisk: .slight,
            severeRisk: .hail(probability: 0.3),
            watches: [
                makeWatch(id: "active", title: "Severe Thunderstorm Warning", issued: iso("2026-05-01T11:30:00Z"), validEnd: iso("2026-05-01T12:10:00Z")),
                makeWatch(id: "expired", title: "Tornado Warning", issued: iso("2026-05-01T10:30:00Z"), validEnd: iso("2026-05-01T11:59:00Z"))
            ],
            mesos: [
                makeMeso(number: 2002, issued: iso("2026-05-01T11:20:00Z"), validEnd: iso("2026-05-01T11:55:00Z"))
            ]
        )

        let snapshot = builder.build(from: input, now: now)

        #expect(snapshot.selectedAlert?.title == "Severe Thunderstorm Warning")
        #expect(snapshot.hiddenAlertCount == 0)
    }

    @Test("expired alerts are filtered from active widget state")
    func expiredAlertsFiltered() {
        let builder = WidgetSnapshotBuilder()
        let input = WidgetSnapshotBuilder.Input(
            generatedAt: now,
            snapshotTimestamp: now,
            availability: .available,
            stormRisk: .slight,
            severeRisk: .wind(probability: 0.1),
            watches: [
                makeWatch(id: "expired-watch", title: "Tornado Warning", issued: iso("2026-05-01T09:00:00Z"), validEnd: iso("2026-05-01T11:00:00Z"))
            ],
            mesos: [
                makeMeso(number: 2003, issued: iso("2026-05-01T09:00:00Z"), validEnd: iso("2026-05-01T11:00:00Z"))
            ]
        )

        let snapshot = builder.build(from: input, now: now)

        #expect(snapshot.selectedAlert == nil)
        #expect(snapshot.hiddenAlertCount == 0)
    }

    @Test("stale state uses 30 minute threshold")
    func staleState() {
        let builder = WidgetSnapshotBuilder()
        let input = WidgetSnapshotBuilder.Input(
            generatedAt: now,
            snapshotTimestamp: iso("2026-05-01T11:30:00Z"),
            availability: .available,
            stormRisk: .marginal,
            severeRisk: .wind(probability: 0.1),
            watches: [],
            mesos: []
        )

        let snapshot = builder.build(from: input, now: now)
        #expect(snapshot.freshness.state == .stale)
    }

    @Test("unavailable state returns explicit unavailable snapshot")
    func unavailableState() {
        let builder = WidgetSnapshotBuilder()
        let input = WidgetSnapshotBuilder.Input(
            generatedAt: now,
            snapshotTimestamp: iso("2026-05-01T11:20:00Z"),
            availability: .unavailable(message: "ignored"),
            stormRisk: nil,
            severeRisk: nil,
            watches: [],
            mesos: []
        )

        let snapshot = builder.build(from: input, now: now)

        #expect(snapshot.freshness.state == .unavailable)
        #expect(snapshot.selectedAlert == nil)
        if case .unavailable(let message) = snapshot.availability {
            #expect(message == WidgetSnapshot.unavailableMessage)
        } else {
            Issue.record("Expected unavailable state")
        }
    }
}

private func makeWatch(id: String, title: String, issued: Date, validEnd: Date) -> WatchRowDTO {
    WatchRowDTO(
        id: id,
        messageId: nil,
        currentRevisionSent: nil,
        title: title,
        headline: title,
        issued: issued,
        expires: validEnd,
        ends: validEnd,
        messageType: "Alert",
        sender: nil,
        severity: "Severe",
        urgency: "Immediate",
        certainty: "Observed",
        description: "Alert",
        instruction: nil,
        response: nil,
        areaSummary: "Area",
        geometryData: nil,
        tornadoDetection: nil,
        tornadoDamageThreat: nil,
        maxWindGust: nil,
        maxHailSize: nil,
        windThreat: nil,
        hailThreat: nil,
        thunderstormDamageThreat: nil,
        flashFloodDetection: nil,
        flashFloodDamageThreat: nil
    )
}

private func makeMeso(number: Int, issued: Date, validEnd: Date) -> MdDTO {
    MdDTO(
        number: number,
        title: "Mesoscale Discussion",
        link: URL(string: "https://example.com/\(number)")!,
        issued: issued,
        validStart: issued,
        validEnd: validEnd,
        areasAffected: "Area",
        summary: "Summary",
        concerning: nil,
        watchProbability: "40",
        threats: nil,
        coordinates: []
    )
}

private func iso(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)!
}
