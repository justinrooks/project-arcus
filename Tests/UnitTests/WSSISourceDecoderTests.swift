import Foundation
import Testing
@testable import SkyAware

struct WSSISourceDecoderTests {
    private let revision = "8afb87e2-451c-431c-8b0d-e18ea577ce0d"
    private let stamp = "2026-11-23T19:15:00+00:00"
    private let end = "2026-11-24T19:15:00+00:00"

    private func entry(_ product: String = "Overall_Impact", _ day: Int = 1) -> [String: Any] {
        ["product": product, "day": day, "validity": "Valid", "sourceStatus": "Available", "pollHealth": "Successful", "coverage": "unknown", "accepted": ["revision": revision, "issuedAt": stamp, "validFrom": stamp, "validTo": end, "retrievedAt": stamp, "geometryPath": "/geometry"]]
    }

    private func manifest(_ entries: [[String: Any]]) throws -> WSSIManifest {
        try WSSISourceDecoder.manifest(from: JSONSerialization.data(withJSONObject: ["datasets": entries, "pollFreshness": "Scheduled"]))
    }

    private func allEntries() -> [[String: Any]] {
        ["Overall_Impact", "Snow_Amount", "Snow_Load", "Ice_Accumulation", "Blowing_Snow"].flatMap { product in (1...3).map { entry(product, $0) } }
    }

    private func payload(_ product: String = "Overall_Impact", _ day: Int = 1) -> [String: Any] {
        let ring = [[0, 0], [10, 0], [10, 10], [0, 0]]
        let hole = [[1, 1], [2, 1], [2, 2], [1, 1]]
        let features: [[String: Any]] = WSSISeverity.allCases.enumerated().map { index, severity in
            ["type": "Feature", "id": index + 1, "properties": ["sourceObjectId": index + 1, "severity": severity.rawValue], "geometry": ["type": "MultiPolygon", "coordinates": [[ring, hole], [ring]]]]
        }
        return ["type": "FeatureCollection", "metadata": ["product": product, "day": day, "revision": revision, "issuedAt": stamp, "validFrom": stamp, "validTo": end, "retrievedAt": stamp, "coverage": "unknown"], "features": features]
    }

    private func decode(_ object: [String: Any], entry: WSSIManifestEntry) throws -> WSSIFeatureCollection {
        try WSSISourceDecoder.geometry(from: JSONSerialization.data(withJSONObject: object), for: entry)
    }

    @Test func allIdentitiesAndSeveritiesPreserveGeometry() throws {
        let entries = try manifest(allEntries()).datasets
        #expect(entries.count == 15)
        for entry in entries {
            let result = try decode(payload(entry.product.rawValue, entry.day), entry: entry)
            #expect(result.features.map(\.properties.severity) == WSSISeverity.allCases)
            #expect(result.features[0].geometry.coordinates.count == 2)
            #expect(result.features[0].geometry.coordinates[0].rings.count == 2)
            #expect(result.metadata.issuedAt == entry.accepted?.issuedAt)
        }
    }

    @Test(arguments: ["revision", "product", "day", "issuedAt", "validTo", "coverage", "missing", "empty", "severity", "coordinate", "ring", "degenerate", "collinear", "geometry", "feature", "id", "sourceId", "timestamp", "fraction", "precision"])
    func rejectsInvalidPayload(_ kind: String) throws {
        let entry = try manifest(allEntries()).datasets[0]
        var object = payload(entry.product.rawValue, entry.day)
        var metadata = object["metadata"] as! [String: Any]
        var features = object["features"] as! [[String: Any]]
        switch kind {
        case "revision": metadata["revision"] = UUID().uuidString
        case "product": metadata["product"] = "Snow_Load"
        case "day": metadata["day"] = 4
        case "issuedAt": metadata["issuedAt"] = end
        case "validTo": metadata["validTo"] = stamp
        case "coverage": metadata["coverage"] = "complete"
        case "timestamp": metadata["retrievedAt"] = "2026-02-30T19:15:00+00:00"
        case "precision": metadata["retrievedAt"] = "2026-11-23T19:15:00.00000001+00:00"
        case "fraction": metadata["retrievedAt"] = "2026-11-23T19:15:00.0001+00:00"
        case "id": features[0]["id"] = 2
        case "sourceId": features[0]["properties"] = ["sourceObjectId": 2, "severity": "Minor"]
        case "missing": metadata.removeValue(forKey: "retrievedAt")
        case "empty": features = []
        case "severity": features[0]["properties"] = ["sourceObjectId": 1, "severity": "Unknown"]
        case "coordinate": features[0]["geometry"] = ["type": "MultiPolygon", "coordinates": [[[[181, 0], [1, 0], [1, 1], [181, 0]]]]]
        case "ring": features[0]["geometry"] = ["type": "MultiPolygon", "coordinates": [[[[0, 0], [1, 0], [1, 1], [0, 1]]]]]
        case "degenerate": features[0]["geometry"] = ["type": "MultiPolygon", "coordinates": [[[[0, 0], [1, 0], [0, 0], [0, 0]]]]]
        case "collinear": features[0]["geometry"] = ["type": "MultiPolygon", "coordinates": [[[[0, 0], [1, 1], [2, 2], [0, 0]]]]]
        case "geometry": features[0]["geometry"] = ["type": "Polygon", "coordinates": []]
        default: features[0]["type"] = "Invalid"
        }
        object["metadata"] = metadata
        object["features"] = features
        #expect(throws: (any Error).self) { try decode(object, entry: entry) }
    }

    @Test func absenceAndUnavailableRemainDistinct() throws {
        var entries = allEntries()
        entries[0]["accepted"] = NSNull()
        entries[0]["validity"] = "NeverAccepted"
        entries[0]["sourceStatus"] = "Unavailable"
        entries[1]["sourceStatus"] = "Unavailable"
        entries[1]["pollHealth"] = "Failed"
        entries[1]["validity"] = "Expired"
        let mixed = try manifest(entries)
        #expect(mixed.datasets[1].accepted != nil)
        #expect(mixed.datasets[1].sourceStatus == .unavailable)
        #expect(mixed.datasets[1].pollHealth == .failed)
        let first = try #require(mixed.datasets.first)
        #expect(first.accepted == nil)
        #expect(first.sourceStatus == .unavailable)
        #expect(first.coverage == .unknown)
        #expect(throws: (any Error).self) { try decode(payload(), entry: first) }
        entries[0]["validity"] = "Valid"
        #expect(throws: (any Error).self) { try manifest(entries) }
        entries = allEntries()
        var revision = entries[0]["accepted"] as! [String: Any]
        revision["issuedAt"] = end
        entries[0]["accepted"] = revision
        #expect(throws: (any Error).self) { try manifest(entries) }
        entries = allEntries()
        entries[1] = entries[0]
        #expect(throws: (any Error).self) { try manifest(entries) }
    }

    @Test func capturedForgeGeometryPreservesFullResolution() throws {
        let url = try #require(Bundle(for: WSSIFixtureLocator.self).url(forResource: "overall-1", withExtension: "geojson"))
        let data = try Data(contentsOf: url)
        let raw = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let metadata = try #require(raw["metadata"] as? [String: Any])
        var first = entry()
        var accepted = try #require(first["accepted"] as? [String: Any])
        for key in ["revision", "issuedAt", "validFrom", "validTo", "gisFileDate", "gisIngestDate", "retrievedAt"] { accepted[key] = metadata[key] }
        first["accepted"] = accepted
        var entries = allEntries()
        entries[0] = first
        let decoded = try WSSISourceDecoder.geometry(from: data, for: manifest(entries).datasets[0])
        let rawFeatures = try #require(raw["features"] as? [[String: Any]])
        for (feature, rawFeature) in zip(decoded.features, rawFeatures) {
            let properties = try #require(rawFeature["properties"] as? [String: Any])
            #expect(feature.properties.sourceObjectId == (properties["sourceObjectId"] as? Int64))
            let geometry = try #require(rawFeature["geometry"] as? [String: Any])
            let coordinates = try #require(geometry["coordinates"] as? [[[[Double]]]])
            #expect(feature.geometry.coordinates.map { $0.rings.map { $0.map { [$0.longitude, $0.latitude] } } } == coordinates)
        }
        let polygons = decoded.features.flatMap(\.geometry.coordinates)
        #expect(abs(decoded.metadata.retrievedAt.timeIntervalSince1970 - 1795465838.47224) < 0.000001)
        #expect(decoded.features.map(\.properties.severity) == [.winterWeatherArea, .minor, .moderate, .major, .extreme])
        #expect(decoded.features.count == 5)
        #expect(polygons.count == 478)
        #expect(polygons.flatMap(\.rings).count == 639)
        #expect(polygons.flatMap(\.rings).reduce(0) { $0 + $1.count } == 55_440)
    }
}
private final class WSSIFixtureLocator: NSObject {}
