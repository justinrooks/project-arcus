import Testing
@testable import SkyAware
import Foundation

@Suite("DeviceAlertPayload decoding")
struct DeviceAlertPayloadTests {
    @Test("Missing ugc still decodes for cell-based Arcus matches")
    func missingUgc_decodes() throws {
        let json = payloadJSON()

        let decoded: [DeviceAlertPayload]? = JsonParser.decode(from: Data(json.utf8))
        let payload = try #require(decoded?.first)

        #expect(payload.ugc == nil)
        #expect(payload.h3Cells == [613725958748241919])
        #expect(payload.geometry == nil)
    }

    @Test("Polygon geometry decodes with longitude latitude transport order")
    func polygonGeometry_decodes() throws {
        let json = payloadJSON(
            geometry: """
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
        )

        let decoded: [DeviceAlertPayload]? = JsonParser.decode(from: Data(json.utf8))
        let payload = try #require(decoded?.first)
        let geometry = try #require(payload.geometry)

        guard case .polygon(let rings) = geometry else {
            Issue.record("Expected polygon geometry")
            return
        }

        #expect(rings.count == 1)
        #expect(
            rings.first == [
                DeviceAlertCoordinate(longitude: -104.9903, latitude: 39.7392),
                DeviceAlertCoordinate(longitude: -104.8200, latitude: 39.7392),
                DeviceAlertCoordinate(longitude: -104.8200, latitude: 39.8800),
                DeviceAlertCoordinate(longitude: -104.9903, latitude: 39.8800),
                DeviceAlertCoordinate(longitude: -104.9903, latitude: 39.7392)
            ]
        )
    }

    @Test("MultiPolygon geometry decodes")
    func multiPolygonGeometry_decodes() throws {
        let json = payloadJSON(
            geometry: """
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
        )

        let decoded: [DeviceAlertPayload]? = JsonParser.decode(from: Data(json.utf8))
        let payload = try #require(decoded?.first)
        let geometry = try #require(payload.geometry)

        guard case .multiPolygon(let polygons) = geometry else {
            Issue.record("Expected multipolygon geometry")
            return
        }

        #expect(polygons.count == 2)
        #expect(polygons[0][0].first == DeviceAlertCoordinate(longitude: -104.9903, latitude: 39.7392))
        #expect(polygons[1][0].first == DeviceAlertCoordinate(longitude: -105.1200, latitude: 39.6500))
    }
}

private func payloadJSON(geometry: String? = nil) -> String {
    let geometryField = geometry.map { ",\n        \"geometry\": \($0)" } ?? ""

    return """
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
        "h3Cells": [613725958748241919]\(geometryField)
      }
    ]
    """
}
