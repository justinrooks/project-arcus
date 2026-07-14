import Testing
@testable import SkyAware
import SwiftData
import Foundation
import CoreLocation

@Suite("StormRiskRepo.refreshStormRisk", .serialized)
struct StormRiskRepoRefreshCategoricalRiskTests {
    @Test("Transient empty categorical must not clear an existing active categorical risk")
    func transientEmptyCategoricalDoesNotClearExistingActiveRisk() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [StormRisk.self]) }
        try await MainActor.run { try TestStore.reset(StormRisk.self, in: container) }
        let repo = StormRiskRepo(modelContainer: container)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                StormRisk(
                    riskLevel: .marginal,
                    issued: makeUTCDate(2027, 5, 1, 12, 0),
                    expires: makeUTCDate(2027, 5, 1, 20, 0),
                    valid: makeUTCDate(2027, 5, 1, 12, 0),
                    stroke: "#AA0000",
                    fill: "#110000",
                    polygons: []
                )
            )
            try context.save()
        }

        let emptyBatch = makeFeatureCollection(features: [])
        let data = try JSONEncoder().encode(emptyBatch)
        try await repo.refreshStormRisk(using: CategoricalMockClient(categoricalData: data))

        let persisted = try ModelContext(container).fetch(FetchDescriptor<StormRisk>())
        #expect(persisted.count == 1)
        #expect(persisted.first?.riskLevel == .marginal)
        #expect(persisted.first?.issued == makeUTCDate(2027, 5, 1, 12, 0))
    }

    @Test("Coherent newer non-empty all-clear categorical transition is still allowed")
    func coherentNewerCategoricalAllClearFeatureTransitionIsAllowed() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [StormRisk.self]) }
        try await MainActor.run { try TestStore.reset(StormRisk.self, in: container) }
        let repo = StormRiskRepo(modelContainer: container)

        let priorFeature = makeFeature(
            properties: makeProperties(
                label: "MRGL",
                label2: "Marginal Risk",
                issue: "202705011200",
                valid: "202705011200",
                expire: "202705011500",
                dn: 2
            ),
            geometry: makeMultiPolygonGeometry(squareAtLonLat: (-105.0, 39.0), size: 1.5)
        )
        let priorData = try JSONEncoder().encode(makeFeatureCollection(features: [priorFeature]))
        try await repo.refreshStormRisk(using: CategoricalMockClient(categoricalData: priorData))

        let coherentAllClearFeature = makeFeature(
            properties: makeProperties(
                label: "CLR",
                label2: "Clear",
                issue: "202705011230",
                valid: "202705011230",
                expire: "202705011800",
                dn: 0
            ),
            geometry: makeMultiPolygonGeometry(squareAtLonLat: (-105.0, 39.0), size: 1.5)
        )
        let coherentClearData = try JSONEncoder().encode(makeFeatureCollection(features: [coherentAllClearFeature]))
        try await repo.refreshStormRisk(using: CategoricalMockClient(categoricalData: coherentClearData))

        let active = try await repo.active(
            asOf: makeUTCDate(2027, 5, 1, 13, 30),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .allClear)
    }

    @Test("Malformed categorical dates fail closed and preserve active risk")
    func malformedCategoricalDatesFailClosed() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [StormRisk.self]) }
        try await MainActor.run { try TestStore.reset(StormRisk.self, in: container) }
        let repo = StormRiskRepo(modelContainer: container)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                StormRisk(
                    riskLevel: .marginal,
                    issued: makeUTCDate(2027, 5, 1, 12, 0),
                    expires: makeUTCDate(2027, 5, 1, 20, 0),
                    valid: makeUTCDate(2027, 5, 1, 12, 0),
                    stroke: "#AA0000",
                    fill: "#110000",
                    polygons: []
                )
            )
            try context.save()
        }

        let malformedFeature = makeFeature(
            properties: makeProperties(
                label: "MRGL",
                label2: "Marginal Risk",
                issue: "bad",
                valid: "202705011200",
                expire: "202705011500",
                dn: 2
            ),
            geometry: makeMultiPolygonGeometry(squareAtLonLat: (-105.0, 39.0), size: 1.5)
        )

        do {
            let data = try JSONEncoder().encode(makeFeatureCollection(features: [malformedFeature]))
            try await repo.refreshStormRisk(using: CategoricalMockClient(categoricalData: data))
            #expect(Bool(false), "Expected malformed categorical metadata to throw")
        } catch let error as SpcError {
            #expect(error == .parsingError)
        }

        let persisted = try ModelContext(container).fetch(FetchDescriptor<StormRisk>())
        #expect(persisted.count == 1)
        #expect(persisted.first?.issued == makeUTCDate(2027, 5, 1, 12, 0))
        #expect(persisted.first?.valid == makeUTCDate(2027, 5, 1, 12, 0))
        #expect(persisted.first?.expires == makeUTCDate(2027, 5, 1, 20, 0))
    }
}

private func makeFeatureCollection(features: [GeoJSONFeature]) -> GeoJSONFeatureCollection {
    GeoJSONFeatureCollection(type: "FeatureCollection", features: features)
}

private func makeFeature(properties: GeoJSONProperties, geometry: GeoJSONGeometry) -> GeoJSONFeature {
    // GeoJSONFeature is Decodable-only in app code, but tests can construct via init if visible.
    // If not visible, we can encode/decode via dictionaries. Here, we rely on the internal struct being visible to tests via @testable.
    return GeoJSONFeature(type: "Feature", geometry: geometry, properties: properties)
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
    // Include required stroke/fill fields to satisfy Decodable shape
    return GeoJSONProperties(DN: dn, VALID: valid, EXPIRE: expire, ISSUE: issue, LABEL: label, LABEL2: label2, stroke: stroke, fill: fill)
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
