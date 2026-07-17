import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import SkyAware

private struct MultiProductMockClient: SpcClient {
    let geoJsonByProduct: [GeoJSONProduct: Data]

    func fetchRssData(for product: RssProduct) async throws -> Data {
        throw SpcError.missingRssData
    }

    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data {
        guard let data = geoJsonByProduct[product] else {
            throw SpcError.missingGeoJsonData
        }
        return data
    }
}

@Suite("SevereRiskRepo.active", .serialized)
struct SevereRiskRepoActiveSelectionTests {
    @Test("Tornado active lookup excludes parsed interior holes")
    func tornadoActiveLookupExcludesParsedInteriorHoles() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        let repo = SevereRiskRepo(modelContainer: container)
        let geometry = makeMultiPolygonGeometry(
            squareAtLonLat: (-100.0, 40.0),
            size: 4.0,
            interiorSquares: [((-98.5, 41.5), 1.0)]
        )
        let properties = makeProperties(
            label: "0.05",
            label2: "5% Tornado Risk",
            issue: "202509200000",
            valid: "202509200000",
            expire: "202509200200",
            dn: 5
        )
        let data = try JSONEncoder().encode(
            makeFeatureCollection(features: [makeFeature(properties: properties, geometry: geometry)])
        )

        try await repo.refreshTornadoRisk(
            using: MultiProductMockClient(geoJsonByProduct: [.tornado: data])
        )

        let asOf = makeUTCDate(2025, 9, 20, 1, 0)
        let hole = try await repo.active(
            asOf: asOf,
            for: CLLocationCoordinate2D(latitude: 42.0, longitude: -98.0)
        )
        let exterior = try await repo.active(
            asOf: asOf,
            for: CLLocationCoordinate2D(latitude: 40.5, longitude: -99.5)
        )

        #expect(hole == .allClear)
        #expect(exterior == .tornado(probability: 0.05))
    }

    @Test("Newer tornado issuance removes stale older polygon from active lookup")
    func newerTornadoIssuanceRemovesStaleOlderPolygonFromActiveLookup() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)

        let olderGeometry = makeMultiPolygonGeometry(squareAtLonLat: (-100.0, 40.0), size: 1.0)
        let newerGeometry = makeMultiPolygonGeometry(squareAtLonLat: (-98.0, 40.0), size: 1.0)
        let olderProps = makeProperties(
            label: "0.02",
            label2: "2% Tornado Risk",
            issue: "202705011200",
            valid: "202705011200",
            expire: "202705012000",
            dn: 2
        )
        let newerProps = makeProperties(
            label: "0.02",
            label2: "2% Tornado Risk",
            issue: "202705011630",
            valid: "202705011200",
            expire: "202705012000",
            dn: 2
        )

        let tornadoData = try JSONEncoder().encode(
            makeFeatureCollection(
                features: [
                    makeFeature(properties: olderProps, geometry: olderGeometry),
                    makeFeature(properties: newerProps, geometry: newerGeometry)
                ]
            )
        )
        let mock = MultiProductMockClient(geoJsonByProduct: [.tornado: tornadoData])

        try await repo.refreshTornadoRisk(using: mock)

        let asOf = makeUTCDate(2027, 5, 1, 17, 0)
        let point = CLLocationCoordinate2D(latitude: 40.5, longitude: -99.5)
        let active = try await repo.active(asOf: asOf, for: point)
        #expect(active == .allClear)
    }

    @Test("Overlapping tornado polygons prefer the higher tornado probability")
    func overlappingTornadoPolygonsPreferHigherProbability() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)

        let geometry = makeMultiPolygonGeometry(squareAtLonLat: (-100.0, 40.0), size: 1.0)
        let props2 = makeProperties(
            label: "0.02",
            label2: "2% Tornado Risk",
            issue: "202509200000",
            valid: "202509200000",
            expire: "202509200200",
            dn: 2
        )
        let props5 = makeProperties(
            label: "0.05",
            label2: "5% Tornado Risk",
            issue: "202509200000",
            valid: "202509200000",
            expire: "202509200200",
            dn: 5
        )

        let tornadoData = try JSONEncoder().encode(
            makeFeatureCollection(
                features: [
                    makeFeature(properties: props2, geometry: geometry),
                    makeFeature(properties: props5, geometry: geometry)
                ]
            )
        )
        let mock = MultiProductMockClient(geoJsonByProduct: [.tornado: tornadoData])

        try await repo.refreshTornadoRisk(using: mock)

        let asOf = makeUTCDate(2025, 9, 20, 1, 0)
        let point = CLLocationCoordinate2D(latitude: 40.5, longitude: -99.5)
        let active = try await repo.active(asOf: asOf, for: point)
        #expect(active == .tornado(probability: 0.05))
    }

    @Test("Threat priority still wins across risk types")
    func threatPriorityStillWinsAcrossRiskTypes() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)

        let geometry = makeMultiPolygonGeometry(squareAtLonLat: (-100.0, 40.0), size: 1.0)
        let tornadoProps = makeProperties(
            label: "0.02",
            label2: "2% Tornado Risk",
            issue: "202509200000",
            valid: "202509200000",
            expire: "202509200200",
            dn: 2
        )
        let hailProps = makeProperties(
            label: "0.30",
            label2: "30% Hail Risk",
            issue: "202509200000",
            valid: "202509200000",
            expire: "202509200200",
            dn: 30
        )

        let tornadoData = try JSONEncoder().encode(
            makeFeatureCollection(features: [makeFeature(properties: tornadoProps, geometry: geometry)])
        )
        let hailData = try JSONEncoder().encode(
            makeFeatureCollection(features: [makeFeature(properties: hailProps, geometry: geometry)])
        )
        let mock = MultiProductMockClient(
            geoJsonByProduct: [
                .tornado: tornadoData,
                .hail: hailData
            ]
        )

        try await repo.refreshHailRisk(using: mock)
        try await repo.refreshTornadoRisk(using: mock)

        let asOf = makeUTCDate(2025, 9, 20, 1, 0)
        let point = CLLocationCoordinate2D(latitude: 40.5, longitude: -99.5)
        let active = try await repo.active(asOf: asOf, for: point)
        #expect(active == .tornado(probability: 0.02))
    }

    @Test("Overlapping hail polygons prefer the higher hail probability")
    func overlappingHailPolygonsPreferHigherProbability() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)

        let geometry = makeMultiPolygonGeometry(squareAtLonLat: (-100.0, 40.0), size: 1.0)
        let props5 = makeProperties(
            label: "0.05",
            label2: "5% Hail Risk",
            issue: "202509200000",
            valid: "202509200000",
            expire: "202509200200",
            dn: 5
        )
        let props30 = makeProperties(
            label: "0.30",
            label2: "30% Hail Risk",
            issue: "202509200000",
            valid: "202509200000",
            expire: "202509200200",
            dn: 30
        )

        let hailData = try JSONEncoder().encode(
            makeFeatureCollection(
                features: [
                    makeFeature(properties: props5, geometry: geometry),
                    makeFeature(properties: props30, geometry: geometry)
                ]
            )
        )
        let mock = MultiProductMockClient(geoJsonByProduct: [.hail: hailData])

        try await repo.refreshHailRisk(using: mock)

        let asOf = makeUTCDate(2025, 9, 20, 1, 0)
        let point = CLLocationCoordinate2D(latitude: 40.5, longitude: -99.5)
        let active = try await repo.active(asOf: asOf, for: point)
        #expect(active == .hail(probability: 0.30))
    }

    @Test("Overlapping wind polygons prefer the higher wind probability")
    func overlappingWindPolygonsPreferHigherProbability() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)

        let geometry = makeMultiPolygonGeometry(squareAtLonLat: (-100.0, 40.0), size: 1.0)
        let props5 = makeProperties(
            label: "0.05",
            label2: "5% Wind Risk",
            issue: "202509200000",
            valid: "202509200000",
            expire: "202509200200",
            dn: 5
        )
        let props15 = makeProperties(
            label: "0.15",
            label2: "15% Wind Risk",
            issue: "202509200000",
            valid: "202509200000",
            expire: "202509200200",
            dn: 15
        )

        let windData = try JSONEncoder().encode(
            makeFeatureCollection(
                features: [
                    makeFeature(properties: props5, geometry: geometry),
                    makeFeature(properties: props15, geometry: geometry)
                ]
            )
        )
        let mock = MultiProductMockClient(geoJsonByProduct: [.wind: windData])

        try await repo.refreshWindRisk(using: mock)

        let asOf = makeUTCDate(2025, 9, 20, 1, 0)
        let point = CLLocationCoordinate2D(latitude: 40.5, longitude: -99.5)
        let active = try await repo.active(asOf: asOf, for: point)
        #expect(active == .wind(probability: 0.15))
    }
}

private func makeFeatureCollection(features: [GeoJSONFeature]) -> GeoJSONFeatureCollection {
    GeoJSONFeatureCollection(type: "FeatureCollection", features: features)
}

private func makeFeature(properties: GeoJSONProperties, geometry: GeoJSONGeometry) -> GeoJSONFeature {
    GeoJSONFeature(type: "Feature", geometry: geometry, properties: properties)
}

private func makeProperties(
    label: String,
    label2: String,
    issue: String,
    valid: String,
    expire: String,
    dn: Int,
    stroke: String = "#000000",
    fill: String = "#000000"
) -> GeoJSONProperties {
    GeoJSONProperties(
        DN: dn,
        VALID: valid,
        EXPIRE: expire,
        ISSUE: issue,
        LABEL: label,
        LABEL2: label2,
        stroke: stroke,
        fill: fill
    )
}

private func makeMultiPolygonGeometry(
    squareAtLonLat origin: (Double, Double),
    size: Double,
    interiorSquares: [((Double, Double), Double)] = []
) -> GeoJSONGeometry {
    let (lon, lat) = origin
    let exteriorRing = squareRing(longitude: lon, latitude: lat, size: size)
    let interiorRings = interiorSquares.map { origin, size in
        squareRing(longitude: origin.0, latitude: origin.1, size: size)
    }
    return GeoJSONGeometry(type: "MultiPolygon", coordinates: [[exteriorRing] + interiorRings])
}

private func squareRing(longitude: Double, latitude: Double, size: Double) -> [[Double]] {
    [
        [longitude, latitude],
        [longitude, latitude + size],
        [longitude + size, latitude + size],
        [longitude + size, latitude],
        [longitude, latitude]
    ]
}

private func makeUTCDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(
        from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    )!
}
