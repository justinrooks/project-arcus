import Testing
@testable import SkyAware
import SwiftData
import Foundation

private struct StubArcusClient: ArcusClient {
    let payload: Data

    func fetchActiveAlerts(for ugc: String, or fire: String, in cell: Int64?) async throws -> Data {
        payload
    }
}

@Suite("WatchRepo refresh()")
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
            in: 613725958748241919
        )

        let hits = try await repo.active(
            countyCode: "COC031",
            fireZone: "COZ245",
            cell: 613725958748241919,
            on: now
        )

        #expect(hits.isEmpty)
    }
}
