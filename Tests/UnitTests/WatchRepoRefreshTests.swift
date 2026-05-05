import Testing
@testable import SkyAware
import SwiftData
import Foundation

private struct StubArcusClient: ArcusClient {
    let payload: Data

    func fetchActiveAlerts(for county: String, and fire: String, and forecast: String, in cell: Int64?) async throws -> Data {
        payload
    }

    func fetchAlert(id: String, revisionSent: Date?) async throws -> Data {
        payload
    }
}

@Suite("WatchRepo refresh()", .serialized)
struct WatchRepoRefreshTests {
    let container: ModelContainer
    let repo: WatchRepo

    init() throws {
        let schema = Schema([Watch.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        repo = WatchRepo(modelContainer: container)
    }

    @Test("Skips cancelled Arcus alerts even if timing fields are still active")
    func skipsCancelledPayloads() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-03-24T12:00:00Z")!
        let json = """
        [
          {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "event": "Tornado Watch",
            "currentRevisionUrn": "urn:alert:test",
            "currentRevisionSent": "2026-03-24T11:00:00Z",
            "messageType": "Cancel",
            "state": "Cancelled",
            "created": "2026-03-24T11:00:00Z",
            "updated": "2026-03-24T11:00:00Z",
            "lastSeenActive": "2026-03-24T11:00:00Z",
            "sent": "2026-03-24T11:00:00Z",
            "effective": "2026-03-24T11:00:00Z",
            "onset": "2026-03-24T11:00:00Z",
            "expires": "2026-03-24T13:00:00Z",
            "ends": "2026-03-24T13:00:00Z",
            "severity": "Extreme",
            "urgency": "Immediate",
            "certainty": "Observed",
            "areaDesc": "Denver Metro",
            "senderName": "NWS Test",
            "headline": "Test headline",
            "description": "Test description",
            "instructions": "Test instructions",
            "response": "Monitor",
            "ugc": ["COC031"],
            "h3Cells": [613725958748241919]
          }
        ]
        """

        try await repo.refresh(
            using: StubArcusClient(payload: Data(json.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        let hits = try await repo.active(
            countyCode: "COC031",
            fireZone: "COZ245",
            forecastZone: "COZ245",
            cell: 613725958748241919,
            on: now
        )

        #expect(hits.isEmpty)
    }

    @Test("targeted refresh decodes a single alert payload and stores its revision timestamp")
    func targetedRefresh_decodesSinglePayload() async throws {
        let json = """
        {
          "id": "123e4567-e89b-12d3-a456-426614174001",
          "event": "Tornado Watch",
          "currentRevisionUrn": "urn:alert:targeted",
          "currentRevisionSent": "2026-03-24T12:15:00Z",
          "messageType": "Alert",
          "state": "Active",
          "created": "2026-03-24T12:00:00Z",
          "updated": "2026-03-24T12:15:00Z",
          "lastSeenActive": "2026-03-24T12:15:00Z",
          "sent": "2026-03-24T12:15:00Z",
          "effective": "2026-03-24T12:15:00Z",
          "onset": "2026-03-24T12:15:00Z",
          "expires": "2026-03-24T13:15:00Z",
          "ends": "2026-03-24T13:15:00Z",
          "severity": "Extreme",
          "urgency": "Immediate",
          "certainty": "Observed",
          "areaDesc": "Denver Metro",
          "senderName": "NWS Test",
          "headline": "Test headline",
          "description": "Test description",
          "instructions": "Test instructions",
          "response": "Monitor",
          "ugc": ["COC031"],
          "h3Cells": [613725958748241919]
        }
        """

        try await repo.refreshAlert(
            using: StubArcusClient(payload: Data(json.utf8)),
            id: "123e4567-e89b-12d3-a456-426614174001",
            revisionSent: Date(timeIntervalSince1970: 1_711_282_900)
        )

        let watch = try #require(await repo.watch(id: "123e4567-e89b-12d3-a456-426614174001"))
        #expect(watch.messageId == "urn:alert:targeted")
        #expect(watch.currentRevisionSent == ISO8601DateFormatter().date(from: "2026-03-24T12:15:00Z"))
        #expect(watch.geometry == nil)
    }

    @Test("refresh persists polygon geometry from Arcus payloads")
    func refresh_persistsPolygonGeometry() async throws {
        let id = "123e4567-e89b-12d3-a456-426614174002"
        let json = alertPayloadArrayJSON(id: id, geometry: polygonGeometryJSON())

        try await repo.refresh(
            using: StubArcusClient(payload: Data(json.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        let watch = try #require(await repo.watch(id: id))
        #expect(watch.geometry == polygonGeometry())

        let active = try await repo.active(
            countyCode: "COC031",
            fireZone: "COZ245",
            forecastZone: "COZ245",
            cell: 613725958748241919,
            on: ISO8601DateFormatter().date(from: "2026-03-24T12:30:00Z")!
        )
        #expect(active.map(\.id) == [ArcusAlertIdentifier.canonical(id)])
        #expect(active.first?.geometry == polygonGeometry())
    }

    @Test("refresh persists multipolygon geometry from Arcus payloads")
    func refresh_persistsMultiPolygonGeometry() async throws {
        let id = "123e4567-e89b-12d3-a456-426614174003"
        let json = alertPayloadArrayJSON(id: id, geometry: multiPolygonGeometryJSON())

        try await repo.refresh(
            using: StubArcusClient(payload: Data(json.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        let watch = try #require(await repo.watch(id: id))
        #expect(watch.geometry == multiPolygonGeometry())
    }

    @Test("refresh replaces stored geometry for an existing alert")
    func refresh_replacesStoredGeometry() async throws {
        let id = "123e4567-e89b-12d3-a456-426614174004"
        let initial = alertPayloadArrayJSON(
            id: id,
            messageId: "urn:alert:initial",
            currentRevisionSent: "2026-03-24T12:15:00Z",
            geometry: polygonGeometryJSON()
        )

        try await repo.refresh(
            using: StubArcusClient(payload: Data(initial.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        let stored = try #require(await repo.watch(id: id))
        #expect(stored.messageId == "urn:alert:initial")
        #expect(stored.geometry == polygonGeometry())

        let updated = alertPayloadArrayJSON(
            id: id,
            messageId: "urn:alert:updated",
            currentRevisionSent: "2026-03-24T12:45:00Z",
            geometry: multiPolygonGeometryJSON()
        )

        try await repo.refresh(
            using: StubArcusClient(payload: Data(updated.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        let reloaded = try #require(await repo.watch(id: id))
        let expectedRevisionSent = ISO8601DateFormatter().date(from: "2026-03-24T12:45:00Z")
        #expect(reloaded.messageId == "urn:alert:updated")
        #expect(reloaded.currentRevisionSent == expectedRevisionSent)
        #expect(reloaded.geometry == multiPolygonGeometry())

        let canonicalID = ArcusAlertIdentifier.canonical(id)
        let predicate = #Predicate<Watch> { watch in
            watch.nwsId == canonicalID
        }
        let storedCount = try ModelContext(container).fetchCount(FetchDescriptor<Watch>(predicate: predicate))
        #expect(storedCount == 1)
    }

    @Test("refresh clears stored geometry when an existing alert payload omits geometry")
    func refresh_clearsStoredGeometry() async throws {
        let id = "123e4567-e89b-12d3-a456-426614174005"
        let initial = alertPayloadArrayJSON(
            id: id,
            messageId: "urn:alert:initial",
            currentRevisionSent: "2026-03-24T12:15:00Z",
            geometry: polygonGeometryJSON()
        )

        try await repo.refresh(
            using: StubArcusClient(payload: Data(initial.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        let stored = try #require(await repo.watch(id: id))
        #expect(stored.geometry == polygonGeometry())

        let updated = alertPayloadArrayJSON(
            id: id,
            messageId: "urn:alert:updated",
            currentRevisionSent: "2026-03-24T12:45:00Z"
        )

        try await repo.refresh(
            using: StubArcusClient(payload: Data(updated.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        let reloaded = try #require(await repo.watch(id: id))
        #expect(reloaded.messageId == "urn:alert:updated")
        #expect(reloaded.geometry == nil)
    }

    @Test("refresh reconciles cancellation payloads by clearing stored geometry and active visibility")
    func refresh_reconcilesCancelledPayloads() async throws {
        let id = "123e4567-e89b-12d3-a456-426614174006"
        let initial = alertPayloadArrayJSON(
            id: id,
            messageId: "urn:alert:initial",
            currentRevisionSent: "2026-03-24T12:15:00Z",
            geometry: polygonGeometryJSON()
        )

        try await repo.refresh(
            using: StubArcusClient(payload: Data(initial.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        let cancelled = alertPayloadArrayJSON(
            id: id,
            messageId: "urn:alert:cancelled",
            currentRevisionSent: "2026-03-24T12:45:00Z",
            messageType: "Cancel",
            state: "Cancelled"
        )
        try await repo.refresh(
            using: StubArcusClient(payload: Data(cancelled.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        let reloaded = try #require(await repo.watch(id: id))
        #expect(reloaded.messageId == "urn:alert:cancelled")
        #expect(reloaded.messageType == "Cancel")
        #expect(reloaded.geometry == nil)

        let now = ISO8601DateFormatter().date(from: "2026-03-24T12:50:00Z")!
        let activeWarnings = try await repo.activeWarningGeometries(on: now)
        #expect(activeWarnings.contains(where: { $0.id == ArcusAlertIdentifier.canonical(id) }) == false)

        let activeAlerts = try await repo.active(
            countyCode: "COC031",
            fireZone: "COZ245",
            forecastZone: "COZ245",
            cell: 613725958748241919,
            on: now
        )
        #expect(activeAlerts.contains(where: { $0.id == ArcusAlertIdentifier.canonical(id) }) == false)
    }

    @Test("refresh reconciles superseded payloads by clearing stored geometry")
    func refresh_reconcilesSupersededPayloads() async throws {
        let id = "123e4567-e89b-12d3-a456-426614174007"
        let initial = alertPayloadArrayJSON(
            id: id,
            messageId: "urn:alert:initial",
            currentRevisionSent: "2026-03-24T12:15:00Z",
            geometry: polygonGeometryJSON()
        )

        try await repo.refresh(
            using: StubArcusClient(payload: Data(initial.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        let superseded = alertPayloadArrayJSON(
            id: id,
            messageId: "urn:alert:superseded",
            currentRevisionSent: "2026-03-24T12:45:00Z",
            messageType: "Update",
            state: "Superseded"
        )
        try await repo.refresh(
            using: StubArcusClient(payload: Data(superseded.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        let reloaded = try #require(await repo.watch(id: id))
        #expect(reloaded.messageId == "urn:alert:superseded")
        #expect(reloaded.messageType == "Update")
        #expect(reloaded.geometry == nil)

        let now = ISO8601DateFormatter().date(from: "2026-03-24T12:50:00Z")!
        let activeWarnings = try await repo.activeWarningGeometries(on: now)
        #expect(activeWarnings.contains(where: { $0.id == ArcusAlertIdentifier.canonical(id) }) == false)
    }

    @Test("refresh reconciles expired payloads by clearing stored geometry")
    func refresh_reconcilesExpiredPayloads() async throws {
        let id = "123e4567-e89b-12d3-a456-426614174008"
        let initial = alertPayloadArrayJSON(
            id: id,
            messageId: "urn:alert:initial",
            currentRevisionSent: "2026-03-24T12:15:00Z",
            geometry: polygonGeometryJSON()
        )

        try await repo.refresh(
            using: StubArcusClient(payload: Data(initial.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        let expired = alertPayloadArrayJSON(
            id: id,
            messageId: "urn:alert:expired",
            currentRevisionSent: "2026-03-24T12:45:00Z",
            messageType: "Update",
            state: "Expired",
            ends: "2026-03-24T13:15:00Z"
        )
        try await repo.refresh(
            using: StubArcusClient(payload: Data(expired.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        let reloaded = try #require(await repo.watch(id: id))
        #expect(reloaded.messageId == "urn:alert:expired")
        #expect(reloaded.messageType == "Update")
        #expect(reloaded.geometry == nil)

        let now = ISO8601DateFormatter().date(from: "2026-03-24T12:50:00Z")!
        let activeWarnings = try await repo.activeWarningGeometries(on: now)
        #expect(activeWarnings.contains(where: { $0.id == ArcusAlertIdentifier.canonical(id) }) == false)
    }

    @Test("refresh ignores unseen terminal payloads without creating rows")
    func refresh_ignoresUnseenTerminalPayload() async throws {
        let id = "123e4567-e89b-12d3-a456-426614174009"
        let terminal = alertPayloadArrayJSON(
            id: id,
            messageId: "urn:alert:terminal",
            currentRevisionSent: "2026-03-24T12:45:00Z",
            messageType: "Cancel",
            state: "Cancelled"
        )

        try await repo.refresh(
            using: StubArcusClient(payload: Data(terminal.utf8)),
            for: "COC031",
            and: "COZ245",
            and: "COZ245",
            in: 613725958748241919
        )

        #expect(try await repo.watch(id: id) == nil)

        let count = try ModelContext(container).fetchCount(Watch.allWatchesDescriptor())
        #expect(count == 0)
    }
}

private func alertPayloadArrayJSON(
    id: String,
    messageId: String = "urn:alert:test",
    currentRevisionSent: String = "2026-03-24T12:15:00Z",
    messageType: String = "Alert",
    state: String = "Active",
    ends: String = "2026-03-24T13:15:00Z",
    geometry: String? = nil
) -> String {
    let geometryField = geometry.map { ",\n            \"geometry\": \($0)" } ?? ""

    return """
        [
          {
            "id": "\(id)",
            "event": "Tornado Warning",
            "currentRevisionUrn": "\(messageId)",
            "currentRevisionSent": "\(currentRevisionSent)",
            "messageType": "\(messageType)",
            "state": "\(state)",
            "created": "2026-03-24T12:00:00Z",
            "updated": "\(currentRevisionSent)",
            "lastSeenActive": "\(currentRevisionSent)",
            "sent": "\(currentRevisionSent)",
            "effective": "2026-03-24T12:00:00Z",
            "onset": "2026-03-24T12:00:00Z",
            "expires": "2026-03-24T13:15:00Z",
            "ends": "\(ends)",
            "severity": "Extreme",
            "urgency": "Immediate",
            "certainty": "Observed",
            "areaDesc": "Denver Metro",
            "senderName": "NWS Test",
            "headline": "Test headline",
            "description": "Test description",
            "instructions": "Test instructions",
            "response": "Monitor",
            "ugc": ["COC031"],
            "h3Cells": [613725958748241919]\(geometryField)
          }
        ]
        """
}

private func polygonGeometryJSON() -> String {
    """
    {
      "type": "Polygon",
      "coordinates": [
        [
          [-104.9903, 39.7392],
          [-104.8200, 39.7392],
          [-104.8200, 39.8800],
          [-104.9903, 39.8800],
          [-104.9903, 39.7392]
        ]
      ]
    }
    """
}

private func polygonGeometry() -> DeviceAlertGeometry {
    .polygon(
        rings: [
            [
                DeviceAlertCoordinate(longitude: -104.9903, latitude: 39.7392),
                DeviceAlertCoordinate(longitude: -104.8200, latitude: 39.7392),
                DeviceAlertCoordinate(longitude: -104.8200, latitude: 39.8800),
                DeviceAlertCoordinate(longitude: -104.9903, latitude: 39.8800),
                DeviceAlertCoordinate(longitude: -104.9903, latitude: 39.7392)
            ]
        ]
    )
}

private func multiPolygonGeometryJSON() -> String {
    """
    {
      "type": "MultiPolygon",
      "coordinates": [
        [
          [
            [-104.9903, 39.7392],
            [-104.8200, 39.7392],
            [-104.8200, 39.8800],
            [-104.9903, 39.8800],
            [-104.9903, 39.7392]
          ]
        ],
        [
          [
            [-105.1200, 39.6500],
            [-104.9800, 39.6500],
            [-104.9800, 39.7600],
            [-105.1200, 39.7600],
            [-105.1200, 39.6500]
          ]
        ]
      ]
    }
    """
}

private func multiPolygonGeometry() -> DeviceAlertGeometry {
    .multiPolygon(
        polygons: [
            [
                [
                    DeviceAlertCoordinate(longitude: -104.9903, latitude: 39.7392),
                    DeviceAlertCoordinate(longitude: -104.8200, latitude: 39.7392),
                    DeviceAlertCoordinate(longitude: -104.8200, latitude: 39.8800),
                    DeviceAlertCoordinate(longitude: -104.9903, latitude: 39.8800),
                    DeviceAlertCoordinate(longitude: -104.9903, latitude: 39.7392)
                ]
            ],
            [
                [
                    DeviceAlertCoordinate(longitude: -105.1200, latitude: 39.6500),
                    DeviceAlertCoordinate(longitude: -104.9800, latitude: 39.6500),
                    DeviceAlertCoordinate(longitude: -104.9800, latitude: 39.7600),
                    DeviceAlertCoordinate(longitude: -105.1200, latitude: 39.7600),
                    DeviceAlertCoordinate(longitude: -105.1200, latitude: 39.6500)
                ]
            ]
        ]
    )
}
