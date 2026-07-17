import Foundation
import SwiftData
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

    private let noAreaGeoJson: String = """
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "GeometryCollection",
            "geometries": []
          },
          "properties": {
            "DN": 0,
            "VALID": "202605311200",
            "EXPIRE": "202605311800",
            "ISSUE": "202605311155",
            "LABEL": "No Areas",
            "LABEL2": "No Areas",
            "stroke": "#000000",
            "fill": "#111111"
          }
        }
      ]
    }
    """

    @Test("decode parses a valid GeoJSON FeatureCollection")
    func decode_validGeoJson() throws {
        let data = try #require(validGeoJson.data(using: .utf8))
        let decoded: GeoJSONFeatureCollection = try #require(
            JsonParser.decode(from: data) as GeoJSONFeatureCollection?
        )

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
        let decoded = (JsonParser.decode(from: data) as GeoJSONFeatureCollection?) ?? .empty

        #expect(decoded.features.isEmpty)
    }

    @Test("decode returns empty for corrupted JSON")
    func decode_corruptedJsonReturnsEmpty() throws {
        let data = try #require("{ not json".data(using: .utf8))
        let decoded = (JsonParser.decode(from: data) as GeoJSONFeatureCollection?) ?? .empty

        #expect(decoded.features.isEmpty)
    }

    @Test("createPolygonEntities returns entities for each MultiPolygon member")
    func createPolygonEntities_multiPolygon() throws {
        let data = try #require(validGeoJson.data(using: .utf8))
        let decoded: GeoJSONFeatureCollection = try #require(
            JsonParser.decode(from: data) as GeoJSONFeatureCollection?
        )
        let feature = try #require(decoded.features.first)

        let entities = feature.createPolygonEntities(polyTitle: "Test Risk")
        #expect(entities.count == 2)

        let first = try #require(entities.first)
        #expect(first.title == "Test Risk")
        #expect(first.coordinates.count == 3)
        #expect(first.coordinates.first?.latitude == 35.0)
        #expect(first.coordinates.first?.longitude == -97.0)
    }

    @Test("createPolygonEntities preserves interior rings for each MultiPolygon member")
    func createPolygonEntities_preservesInteriorRings() {
        let feature = makeFeature(
            coordinates: [
                [
                    ring(longitude: -100, latitude: 40),
                    ring(longitude: -99.8, latitude: 40.2),
                    ring(longitude: -99.6, latitude: 40.4)
                ],
                [
                    ring(longitude: -90, latitude: 30)
                ]
            ]
        )

        let entities = feature.createPolygonEntities(polyTitle: "TSTM")

        #expect(entities.count == 2)
        #expect(entities[0].coordinates.count == 3)
        #expect(entities[0].interiorCoordinates.count == 2)
        #expect(entities[0].interiorCoordinates.allSatisfy { $0.count == 3 })
        #expect(entities[1].interiorCoordinates.isEmpty)
        #expect(feature.materialPolygonCount == 2)
    }

    @Test("legacy GeoPolygonEntity data defaults missing interior rings to empty")
    func geoPolygonEntity_legacyDataDefaultsInteriorRings() throws {
        let data = try #require(
            """
            {
              "title": "Legacy",
              "coordinates": [
                { "latitude": 35.0, "longitude": -97.0 },
                { "latitude": 35.1, "longitude": -96.9 },
                { "latitude": 35.2, "longitude": -97.1 }
              ],
              "minLat": 35.0,
              "maxLat": 35.2,
              "minLon": -97.1,
              "maxLon": -96.9
            }
            """.data(using: .utf8)
        )

        let polygon = try JSONDecoder().decode(GeoPolygonEntity.self, from: data)

        #expect(polygon.interiorCoordinates.isEmpty)
    }

    @MainActor
    @Test("SwiftData save and reopen preserves interior rings")
    func geoPolygonEntity_swiftDataRoundTripPreservesInteriorRings() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeoJsonParserTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let schema = Schema([StormRisk.self])
        let storeURL = root.appendingPathComponent("SkyAware_Data.sqlite")
        let configuration = ModelConfiguration("SkyAware_Data", schema: schema, url: storeURL)
        let polygon = GeoPolygonEntity(
            title: "TSTM",
            coordinates: ring(longitude: -100, latitude: 40).map { pair in
                Coordinate2D(latitude: pair[1], longitude: pair[0])
            },
            interiorCoordinates: [ring(longitude: -99.8, latitude: 40.2).map { pair in
                Coordinate2D(latitude: pair[1], longitude: pair[0])
            }]
        )

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            let context = ModelContext(container)
            context.insert(
                StormRisk(
                    riskLevel: .thunderstorm,
                    issued: .now,
                    expires: .now.addingTimeInterval(3_600),
                    valid: .now,
                    stroke: nil,
                    fill: nil,
                    polygons: [polygon]
                )
            )
            try context.save()
        }

        let reopenedContainer = try ModelContainer(for: schema, configurations: configuration)
        let persisted = try #require(
            ModelContext(reopenedContainer).fetch(FetchDescriptor<StormRisk>()).first
        )

        #expect(persisted.polygons.count == 1)
        #expect(persisted.polygons[0].interiorCoordinates == polygon.interiorCoordinates)
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

    @Test("decode parses SPC no-area GeometryCollection feature")
    func decode_noAreaGeometryCollection() throws {
        let data = try #require(noAreaGeoJson.data(using: .utf8))
        let decoded: GeoJSONFeatureCollection = try #require(
            JsonParser.decode(from: data) as GeoJSONFeatureCollection?
        )

        let feature = try #require(decoded.features.first)
        #expect(feature.geometry.type == "GeometryCollection")
        #expect(feature.geometry.coordinates.isEmpty)
        #expect(feature.geometry.geometries.isEmpty)
        #expect(feature.materialPolygonCount == 0)
        #expect(feature.createPolygonEntities(polyTitle: "No Areas").isEmpty)
        #expect(feature.properties.LABEL == "No Areas")
    }

    private func makeFeature(coordinates: [[[[Double]]]]) -> GeoJSONFeature {
        GeoJSONFeature(
            type: "Feature",
            geometry: GeoJSONGeometry(type: "MultiPolygon", coordinates: coordinates),
            properties: GeoJSONProperties(
                DN: 1,
                VALID: "2026-01-01T12:00:00Z",
                EXPIRE: "2026-01-01T18:00:00Z",
                ISSUE: "2026-01-01T11:55:00Z",
                LABEL: "TSTM",
                LABEL2: "General Thunderstorms Risk",
                stroke: "#000000",
                fill: "#111111"
            )
        )
    }

    private func ring(longitude: Double, latitude: Double) -> [[Double]] {
        [
            [longitude, latitude],
            [longitude + 0.1, latitude],
            [longitude, latitude + 0.1]
        ]
    }
}
