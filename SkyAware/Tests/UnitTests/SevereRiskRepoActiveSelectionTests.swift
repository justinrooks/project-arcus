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

private func makeMultiPolygonGeometry(squareAtLonLat origin: (Double, Double), size: Double) -> GeoJSONGeometry {
    let (lon, lat) = origin
    let ring: [[Double]] = [
        [lon, lat],
        [lon, lat + size],
        [lon + size, lat + size],
        [lon + size, lat],
        [lon, lat]
    ]
    return GeoJSONGeometry(type: "MultiPolygon", coordinates: [[ring]])
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
