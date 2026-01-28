import Foundation
import Testing
@testable import SkyAware

@Suite("GeoJsonParser")
struct GeoJsonParserTests {
    private let validGeoJson: String = {
        return """
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "MultiPolygon",
                "coordinates": [
                  [
                    [
                      [-97.0, 35.0],
                      [-97.1, 35.1],
                      [-97.2, 35.2]
                    ]
                  ],
                  [
                    [
                      [-98.0, 36.0],
                      [-98.1, 36.1],
                      [-98.2, 36.2]
                    ]
                  ]
                ]
              },
              "properties": {
                "DN": 1,
                "VALID": "2026-01-01T12:00:00Z",
                "EXPIRE": "2026-01-01T18:00:00Z",
                "ISSUE": "2026-01-01T11:55:00Z",
                "LABEL": "MRGL",
                "LABEL2": "Marginal",
                "stroke": "#000000",
                "fill": "#111111"
              }
            }
          ]
        }
        """
    }()

    @Test("decode parses a valid GeoJSON FeatureCollection")
    func decode_validGeoJson() throws {
        let data = try #require(validGeoJson.data(using: .utf8))
        let decoded = GeoJsonParser.decode(from: data)

        #expect(decoded.type == "FeatureCollection")
        #expect(decoded.features.count == 1)

        let feature = try #require(decoded.features.first)
        #expect(feature.type == "Feature")
        #expect(feature.geometry.type == "MultiPolygon")
        #expect(feature.geometry.coordinates.count == 2)
        #expect(feature.properties.LABEL == "MRGL")
        #expect(feature.properties.LABEL2 == "Marginal")
    }

    @Test("decode returns empty when required keys are missing")
    func decode_missingKeyReturnsEmpty() throws {
        let missingFeatures = """
        { "type": "FeatureCollection" }
        """
        let data = try #require(missingFeatures.data(using: .utf8))
        let decoded = GeoJsonParser.decode(from: data)

        #expect(decoded.features.isEmpty)
    }

    @Test("decode returns empty for corrupted JSON")
    func decode_corruptedJsonReturnsEmpty() throws {
        let data = try #require("{ not json".data(using: .utf8))
        let decoded = GeoJsonParser.decode(from: data)

        #expect(decoded.features.isEmpty)
    }

    @Test("createPolygonEntities returns entities for each ring in MultiPolygon")
    func createPolygonEntities_multiPolygon() throws {
        let data = try #require(validGeoJson.data(using: .utf8))
        let decoded = GeoJsonParser.decode(from: data)
        let feature = try #require(decoded.features.first)

        let entities = feature.createPolygonEntities(polyTitle: "Test Risk")
        #expect(entities.count == 2)

        let first = try #require(entities.first)
        #expect(first.title == "Test Risk")
        #expect(first.coordinates.count == 3)
        #expect(first.coordinates.first?.latitude == 35.0)
        #expect(first.coordinates.first?.longitude == -97.0)
    }

    @Test("createPolygonEntities returns empty for non-MultiPolygon geometry")
    func createPolygonEntities_nonMultiPolygonReturnsEmpty() {
        let geometry = GeoJSONGeometry(type: "Polygon", coordinates: [])
        let properties = GeoJSONProperties(
            DN: 1,
            VALID: "2026-01-01T12:00:00Z",
            EXPIRE: "2026-01-01T18:00:00Z",
            ISSUE: "2026-01-01T11:55:00Z",
            LABEL: "MRGL",
            LABEL2: "Marginal",
            stroke: "#000000",
            fill: "#111111"
        )
        let feature = GeoJSONFeature(type: "Feature", geometry: geometry, properties: properties)

        let entities = feature.createPolygonEntities(polyTitle: "Test Risk")
        #expect(entities.isEmpty)
    }
}
