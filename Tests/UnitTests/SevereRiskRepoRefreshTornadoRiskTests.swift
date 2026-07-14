import Testing
@testable import SkyAware
import SwiftData
import Foundation
import CoreLocation

@Suite("SevereRiskRepo.refreshTornadoRisk", .serialized)
struct SevereRiskRepoRefreshTornadoRiskTests {

    @Test("Propagates client failures and inserts nothing")
    func clientFailureNoInsert() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)
        let mock = MockClient(mode: .failure(SpcError.missingData))

        do {
            try await repo.refreshTornadoRisk(using: mock)
            #expect(Bool(false), "Expected client failure to propagate")
        } catch let error as SpcError {
            #expect(error == .missingData)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }

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
        let mock = MockClient(mode: .success(data))

        try await repo.refreshTornadoRisk(using: mock)
        let count = try ModelContext(container).fetchCount(FetchDescriptor<SevereRisk>())
        #expect(count == 0)
    }

    @Test("Transient empty feature collection must not clear existing active tornado risk")
    func transientEmptyCollectionDoesNotClearExistingActiveTornadoRisk() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)

        try await MainActor.run {
            let context = ModelContext(container)
            let geometry = makeMultiPolygonGeometry(squareAtLonLat: (-105.0, 39.0), size: 1.5)
            let feature = makeFeature(
                properties: makeProperties(
                    label: "0.02",
                    label2: "2% Tornado Risk",
                    issue: "202705011200",
                    valid: "202705011200",
                    expire: "202705012000",
                    dn: 2
                ),
                geometry: geometry
            )
            context.insert(
                SevereRisk(
                    type: .tornado,
                    probability: .percent(0.02),
                    threatLevel: .tornado(probability: 0.02),
                    issued: makeUTCDate(2027, 5, 1, 12, 0),
                    valid: makeUTCDate(2027, 5, 1, 12, 0),
                    expires: makeUTCDate(2027, 5, 1, 20, 0),
                    dn: 2,
                    stroke: "#AA0000",
                    fill: "#110000",
                    polygons: feature.createPolygonEntities(polyTitle: "2% Tornado Risk"),
                    label: "0.02"
                )
            )
            try context.save()
        }

        let emptyFC = makeFeatureCollection(features: [])
        let data = try JSONEncoder().encode(emptyFC)
        let mock = MockClient(mode: .success(data))

        try await repo.refreshTornadoRisk(using: mock)
        let persisted = try ModelContext(container).fetch(FetchDescriptor<SevereRisk>())
        #expect(persisted.count == 1)
        #expect(persisted.first?.threatLevel == .tornado(probability: 0.02))
    }

    @Test("Legacy tornado refresh preserves active threat when response is empty")
    func legacyRefreshEmptyCollectionPreservesActiveTornadoThreat() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)

        let priorPolygon = makeMultiPolygonGeometry(squareAtLonLat: (-105.0, 39.0), size: 1.5)
        let priorProps = makeProperties(
            label: "0.02",
            label2: "2% Tornado Risk",
            issue: "202705011200",
            valid: "202705011200",
            expire: "202705011500",
            dn: 2
        )
        let priorData = try JSONEncoder().encode(
            makeFeatureCollection(features: [makeFeature(properties: priorProps, geometry: priorPolygon)])
        )
        try await repo.refreshTornadoRisk(using: MockClient(mode: .success(priorData)))

        let coherentClearData = try JSONEncoder().encode(makeFeatureCollection(features: []))
        try await repo.refreshTornadoRisk(using: MockClient(mode: .success(coherentClearData)))

        let active = try await repo.active(
            asOf: makeUTCDate(2027, 5, 1, 13, 30),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .tornado(probability: 0.02))
    }

    @Test("Malformed severe dates fail closed and preserve active tornado risk")
    func malformedTornadoDatesFailClosed() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                SevereRisk(
                    type: .tornado,
                    probability: .percent(0.02),
                    threatLevel: .tornado(probability: 0.02),
                    issued: makeUTCDate(2027, 5, 1, 12, 0),
                    valid: makeUTCDate(2027, 5, 1, 12, 0),
                    expires: makeUTCDate(2027, 5, 1, 20, 0),
                    dn: 2,
                    stroke: "#AA0000",
                    fill: "#110000",
                    polygons: [],
                    label: "0.02"
                )
            )
            try context.save()
        }

        let malformedFeature = makeFeature(
            properties: makeProperties(
                label: "0.02",
                label2: "2% Tornado Risk",
                issue: "202705011200",
                valid: "not-a-date",
                expire: "202705011500",
                dn: 2
            ),
            geometry: makeMultiPolygonGeometry(squareAtLonLat: (-105.0, 39.0), size: 1.5)
        )

        do {
            let data = try JSONEncoder().encode(makeFeatureCollection(features: [malformedFeature]))
            try await repo.refreshTornadoRisk(using: MockClient(mode: .success(data)))
            #expect(Bool(false), "Expected malformed severe metadata to throw")
        } catch let error as SpcError {
            #expect(error == .parsingError)
        }

        let persisted = try ModelContext(container).fetch(FetchDescriptor<SevereRisk>())
        #expect(persisted.count == 1)
        #expect(persisted.first?.issued == makeUTCDate(2027, 5, 1, 12, 0))
        #expect(persisted.first?.valid == makeUTCDate(2027, 5, 1, 12, 0))
        #expect(persisted.first?.expires == makeUTCDate(2027, 5, 1, 20, 0))
    }

    @Test("Inserts models for each feature returned")
    func insertsForEachFeature() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)
        // Build two minimal features with properties sufficient for makeSevereRisk
        let props1 = makeProperties(label: "0.10", label2: "tornado", issue: "202509200000", valid: "202509200000", expire: "202509200200", dn: 10)
        let props2 = makeProperties(label: "SIGN", label2: "10% Significant Tornado Risk", issue: "202509200000", valid: "202509200000", expire: "202509200200", dn: 99)

        let geom = makeMultiPolygonGeometry(squareAtLonLat: (-100.0, 40.0), size: 1.0)
        let f1 = makeFeature(properties: props1, geometry: geom)
        let f2 = makeFeature(properties: props2, geometry: geom)

        let fc = makeFeatureCollection(features: [f1, f2])
        let data = try JSONEncoder().encode(fc)
        let mock = MockClient(mode: .success(data))

        try await repo.refreshTornadoRisk(using: mock)

        let ctx = ModelContext(container)
        let items = try ctx.fetch(FetchDescriptor<SevereRisk>())
        #expect(items.count == 2)
        // Spot check: both are tornado type
        #expect(items.allSatisfy { $0.type == .tornado })
    }

    @Test("Severe shape DTO includes SPC stroke and fill from persistence")
    func shapeDtoIncludesStrokeAndFill() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)

        let props = makeProperties(
            label: "0.10",
            label2: "10% Tornado Risk",
            issue: "202509200000",
            valid: "202509200000",
            expire: "202509200200",
            dn: 10,
            stroke: "#ABCDEF",
            fill: "#123456"
        )
        let geom = makeMultiPolygonGeometry(squareAtLonLat: (-100.0, 40.0), size: 1.0)
        let feature = makeFeature(properties: props, geometry: geom)
        let data = try JSONEncoder().encode(makeFeatureCollection(features: [feature]))
        let mock = MockClient(mode: .success(data))

        try await repo.refreshTornadoRisk(using: mock)
        let activeAt = Date(timeIntervalSince1970: 1_758_326_400) // 2025-09-20 01:00:00 UTC
        let shapes = try await repo.getSevereRiskShapes(asOf: activeAt)

        #expect(shapes.count == 1)
        #expect(shapes.first?.stroke == "#ABCDEF")
        #expect(shapes.first?.fill == "#123456")
        #expect(shapes.first?.probabilities == .percent(0.10))
    }

    @Test("CIG label is preserved and exposes intensity level")
    func cigLabel_isPreservedInShapeDTO() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }
        let repo = SevereRiskRepo(modelContainer: container)

        let props = makeProperties(
            label: "CIG1",
            label2: "15% Tornado Risk",
            issue: "202509200000",
            valid: "202509200000",
            expire: "202509200200",
            dn: 15,
            stroke: "#AA0000",
            fill: "#220000"
        )
        let geom = makeMultiPolygonGeometry(squareAtLonLat: (-100.0, 40.0), size: 1.0)
        let feature = makeFeature(properties: props, geometry: geom)
        let data = try JSONEncoder().encode(makeFeatureCollection(features: [feature]))
        let mock = MockClient(mode: .success(data))

        try await repo.refreshTornadoRisk(using: mock)
        let activeAt = Date(timeIntervalSince1970: 1_758_326_400) // 2025-09-20 01:00:00 UTC
        let shapes = try await repo.getSevereRiskShapes(asOf: activeAt)

        #expect(shapes.count == 1)
        #expect(shapes.first?.label == "CIG1")
        #expect(shapes.first?.intensityLevel == 1)
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
