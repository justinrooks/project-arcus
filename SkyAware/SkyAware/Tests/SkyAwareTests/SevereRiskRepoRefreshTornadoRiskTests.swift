import Testing
@testable import SkyAware
import SwiftData
import Foundation

private struct MockClient: SPCClienting {
    var tornadoResult: GeoJsonResult?
    func fetchTornadoRisk() async throws -> GeoJsonResult? { tornadoResult }
}

@Suite("SevereRiskRepo.refreshTornadoRisk")
struct SevereRiskRepoRefreshTornadoRiskTests {
    let container: ModelContainer
    let repo: SevereRiskRepo

    init() throws {
        let schema = Schema([SevereRisk.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        repo = SevereRiskRepo(modelContainer: container)
    }

    @Test("Does nothing when client returns nil")
    func nilResultNoInsert() async throws {
        let mock = MockClient(tornadoResult: nil)
        try await repo.refreshTornadoRisk(using: mock)
        let count = try ModelContext(container).fetchCount(FetchDescriptor<SevereRisk>())
        #expect(count == 0)
    }

    @Test("Empty feature collection results in no inserts")
    func emptyCollectionNoInsert() async throws {
        let emptyFC = GeoJSONFeatureCollection.empty
        let result = GeoJsonResult(product: .tornado, featureCollection: emptyFC)
        let mock = MockClient(tornadoResult: result)

        try await repo.refreshTornadoRisk(using: mock)
        let count = try ModelContext(container).fetchCount(FetchDescriptor<SevereRisk>())
        #expect(count == 0)
    }

    @Test("Inserts models for each feature returned")
    func insertsForEachFeature() async throws {
        // Build two minimal features with properties sufficient for makeSevereRisk
        // You likely have convenience initializers; adjust if necessary.
        let props1 = GeoJSONProperties(LABEL: "0.10", LABEL2: "tornado", ISSUE: "2025-09-20T00:00:00Z", VALID: "2025-09-20T00:00:00Z", EXPIRE: "2025-09-20T02:00:00Z", DN: 10)
        let props2 = GeoJSONProperties(LABEL: "SIGN", LABEL2: "10% Significant Tornado Risk", ISSUE: "2025-09-20T00:00:00Z", VALID: "2025-09-20T00:00:00Z", EXPIRE: "2025-09-20T02:00:00Z", DN: 99)

        let geom = GeoJSONGeometry.polygon([[[-100.0,40.0],[-100.0,41.0],[-99.0,41.0],[-99.0,40.0],[-100.0,40.0]]])
        let f1 = GeoJSONFeature(properties: props1, geometry: geom, title: "T1")
        let f2 = GeoJSONFeature(properties: props2, geometry: geom, title: "T2")

        let fc = GeoJSONFeatureCollection(type: "FeatureCollection", features: [f1, f2])
        let result = GeoJsonResult(product: .tornado, featureCollection: fc)
        let mock = MockClient(tornadoResult: result)

        try await repo.refreshTornadoRisk(using: mock)

        let ctx = ModelContext(container)
        let items = try ctx.fetch(FetchDescriptor<SevereRisk>())
        #expect(items.count == 2)
        // Spot check: both are tornado type
        #expect(items.allSatisfy { $0.type == .tornado })
    }
}
