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

    @Test("Severe risks save and reopen every threat variant")
    @MainActor
    func severeRisks_saveAndReopenEveryThreatVariant() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SevereRiskRepoActiveSelectionTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let schema = Schema([SevereRisk.self])
        let storeURL = root.appendingPathComponent("SkyAware_Data.sqlite")
        let configuration = ModelConfiguration("SkyAware_Data", schema: schema, url: storeURL)
        let initialValues: [(ThreatType, ThreatProbability, SevereWeatherThreat)] = [
            (.unknown, .percent(0), .allClear),
            (.wind, .percent(0.20), .wind(probability: 0.20)),
            (.hail, .percent(0.35), .hail(probability: 0.35)),
            (.tornado, .significant(10), .tornado(probability: 0.10))
        ]
        let updatedValues: [(ThreatProbability, SevereWeatherThreat)] = [
            (.percent(0), .allClear),
            (.significant(15), .wind(probability: 0.15)),
            (.percent(0.25), .hail(probability: 0.25)),
            (.percent(0.05), .tornado(probability: 0.05))
        ]

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            let context = ModelContext(container)

            for (index, value) in initialValues.enumerated() {
                context.insert(
                    SevereRisk(
                        type: value.0,
                        probability: value.1,
                        threatLevel: value.2,
                        issued: Date(timeIntervalSince1970: TimeInterval(100 + index)),
                        valid: Date(timeIntervalSince1970: 100),
                        expires: Date(timeIntervalSince1970: 200),
                        dn: index,
                        stroke: nil,
                        fill: nil,
                        polygons: [],
                        label: value.0.rawValue
                    )
                )
            }
            try context.save()

            let saved = try context.fetch(FetchDescriptor<SevereRisk>())
            #expect(saved.count == initialValues.count)
            for value in initialValues {
                #expect(saved.contains { $0.threatLevel == value.2 })
                #expect(saved.contains { $0.probability == value.1 })
            }
        }

        do {
            let reopenedContainer = try ModelContainer(for: schema, configurations: configuration)
            let context = ModelContext(reopenedContainer)
            let descriptor = FetchDescriptor<SevereRisk>(sortBy: [SortDescriptor(\.issued)])
            let reopened = try context.fetch(descriptor)
            #expect(reopened.count == initialValues.count)

            for (risk, value) in zip(reopened, updatedValues) {
                risk.probability = value.0
                risk.threatLevel = value.1
            }
            try context.save()
        }

        let updatedContainer = try ModelContainer(for: schema, configurations: configuration)
        let descriptor = FetchDescriptor<SevereRisk>(sortBy: [SortDescriptor(\.issued)])
        let updated = try ModelContext(updatedContainer).fetch(descriptor)
        #expect(updated.count == updatedValues.count)
        for (risk, value) in zip(updated, updatedValues) {
            #expect(risk.probability == value.0)
            #expect(risk.threatLevel == value.1)
        }
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
