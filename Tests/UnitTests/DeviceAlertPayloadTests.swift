import Testing
@testable import SkyAware
import Foundation

@Suite("DeviceAlertPayload decoding")
struct DeviceAlertPayloadTests {
    @Test("Missing ugc still decodes for cell-based Arcus matches")
    func missingUgc_decodes() throws {
        let json = """
        [
          {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "event": "Tornado Watch",
            "currentRevisionUrn": "urn:alert:test",
            "currentRevisionSent": "2026-03-20T00:00:00Z",
            "messageType": "Alert",
            "state": "Active",
            "created": "2026-03-20T00:00:00Z",
            "updated": "2026-03-20T00:00:00Z",
            "lastSeenActive": "2026-03-20T00:00:00Z",
            "sent": "2026-03-20T00:00:00Z",
            "effective": "2026-03-20T00:00:00Z",
            "onset": "2026-03-20T00:00:00Z",
            "expires": "2026-03-20T01:00:00Z",
            "ends": "2026-03-20T01:00:00Z",
            "severity": "Extreme",
            "urgency": "Future",
            "certainty": "Possible",
            "areaDesc": "Denver Metro",
            "senderName": "NWS Test",
            "headline": "Test headline",
            "description": "Test description",
            "instructions": "Test instructions",
            "response": "Monitor",
            "h3Cells": [613725958748241919]
          }
        ]
        """

        let decoded: [DeviceAlertPayload]? = JsonParser.decode(from: Data(json.utf8))
        let payload = try #require(decoded?.first)

        #expect(payload.ugc == nil)
        #expect(payload.h3Cells == [613725958748241919])
    }
}
