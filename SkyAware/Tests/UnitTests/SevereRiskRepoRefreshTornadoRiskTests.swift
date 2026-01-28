import Testing
@testable import SkyAware
import SwiftData
import Foundation

private struct MockClient: SpcClient {
    var tornadoData: Data?

    func fetchRssData(for product: RssProduct) async throws -> Data? {
        return nil
    }

    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data? {
        switch product {
        case .tornado:
            return tornadoData
        default:
            return nil
        }
    }
}

@Suite("SevereRiskRepo.refreshTornadoRisk", .serialized)
struct SevereRiskRepoRefreshTornadoRiskTests {

    @Test("Does nothing when client returns nil")
    func nilResultNoInsert() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)
        let mock = MockClient(tornadoData: nil)
        try await repo.refreshTornadoRisk(using: mock)
        let count = try ModelContext(container).fetchCount(FetchDescriptor<SevereRisk>())
        #expect(count == 0)
    }

    @Test("Empty feature collection results in no inserts")
    func emptyCollectionNoInsert() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)
        let emptyFC = makeFeatureCollection(features: [])
        let data = try JSONEncoder().encode(emptyFC)
        let mock = MockClient(tornadoData: data)

        try await repo.refreshTornadoRisk(using: mock)
        let count = try ModelContext(container).fetchCount(FetchDescriptor<SevereRisk>())
        #expect(count == 0)
    }

    @Test("Inserts models for each feature returned")
    func insertsForEachFeature() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)
        // Build two minimal features with properties sufficient for makeSevereRisk
        let props1 = makeProperties(label: "0.10", label2: "tornado", issue: "2025-09-20T00:00:00Z", valid: "2025-09-20T00:00:00Z", expire: "2025-09-20T02:00:00Z", dn: 10)
        let props2 = makeProperties(label: "SIGN", label2: "10% Significant Tornado Risk", issue: "2025-09-20T00:00:00Z", valid: "2025-09-20T00:00:00Z", expire: "2025-09-20T02:00:00Z", dn: 99)

        let geom = makeMultiPolygonGeometry(squareAtLonLat: (-100.0, 40.0), size: 1.0)
        let f1 = makeFeature(properties: props1, geometry: geom)
        let f2 = makeFeature(properties: props2, geometry: geom)

        let fc = makeFeatureCollection(features: [f1, f2])
        let data = try JSONEncoder().encode(fc)
        let mock = MockClient(tornadoData: data)

        try await repo.refreshTornadoRisk(using: mock)

        let ctx = ModelContext(container)
        let items = try ctx.fetch(FetchDescriptor<SevereRisk>())
        #expect(items.count == 2)
        // Spot check: both are tornado type
        #expect(items.allSatisfy { $0.type == .tornado })
    }
}

// MARK: - Test JSON Builders

private func makeFeatureCollection(features: [GeoJSONFeature]) -> GeoJSONFeatureCollection {
    GeoJSONFeatureCollection(type: "FeatureCollection", features: features)
}

private func makeFeature(properties: GeoJSONProperties, geometry: GeoJSONGeometry) -> GeoJSONFeature {
    // GeoJSONFeature is Decodable-only in app code, but tests can construct via init if visible.
    // If not visible, we can encode/decode via dictionaries. Here, we rely on the internal struct being visible to tests via @testable.
    return GeoJSONFeature(type: "Feature", geometry: geometry, properties: properties)
}

private func makeProperties(label: String, label2: String, issue: String, valid: String, expire: String, dn: Int) -> GeoJSONProperties {
    // Include required stroke/fill fields to satisfy Decodable shape
    return GeoJSONProperties(DN: dn, VALID: valid, EXPIRE: expire, ISSUE: issue, LABEL: label, LABEL2: label2, stroke: "#000000", fill: "#000000")
}

private func makeMultiPolygonGeometry(squareAtLonLat origin: (Double, Double), size: Double) -> GeoJSONGeometry {
    let (lon, lat) = origin
    // MultiPolygon → [[[[lon, lat]...]]]
    let ring: [[Double]] = [
        [lon, lat],
        [lon, lat + size],
        [lon + size, lat + size],
        [lon + size, lat],
        [lon, lat]
    ]
    let coordinates = [[ring]]
    return GeoJSONGeometry(type: "MultiPolygon", coordinates: coordinates)
}
