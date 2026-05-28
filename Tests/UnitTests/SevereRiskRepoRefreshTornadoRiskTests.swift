import Testing
@testable import SkyAware
import SwiftData
import Foundation
import CoreLocation

private struct MockClient: SpcClient {
    enum Mode {
        case success(Data)
        case failure(Error)
    }

    var mode: Mode

    func fetchRssData(for product: RssProduct) async throws -> Data {
        throw SpcError.missingRssData
    }

    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data {
        switch product {
        case .tornado:
            switch mode {
            case .success(let data):
                return data
            case .failure(let error):
                throw error
            }
        default:
            throw SpcError.missingGeoJsonData
        }
    }
}

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

        let emptyFC = makeFeatureCollection(features: [])
        let data = try JSONEncoder().encode(emptyFC)
        let mock = MockClient(mode: .success(data))

        try await repo.refreshTornadoRisk(using: mock)
        let active = try await repo.active(
            asOf: makeUTCDate(2027, 5, 1, 13, 0),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .tornado(probability: 0.02))
    }

    @Test("Coherent newer tornado all-clear transition is still allowed")
    func coherentNewerTornadoAllClearTransitionIsAllowed() async throws {
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
        #expect(active == .allClear)
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

private struct CategoricalMockClient: SpcClient {
    let categoricalData: Data

    func fetchRssData(for product: RssProduct) async throws -> Data {
        throw SpcError.missingRssData
    }

    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data {
        guard product == .categorical else {
            throw SpcError.missingGeoJsonData
        }
        return categoricalData
    }
}

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

        let active = try await repo.active(
            asOf: makeUTCDate(2027, 5, 1, 13, 0),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .marginal)
    }

    @Test("Coherent newer categorical all-clear transition is still allowed")
    func coherentNewerCategoricalAllClearTransitionIsAllowed() async throws {
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

        let coherentClearData = try JSONEncoder().encode(makeFeatureCollection(features: []))
        try await repo.refreshStormRisk(using: CategoricalMockClient(categoricalData: coherentClearData))

        let active = try await repo.active(
            asOf: makeUTCDate(2027, 5, 1, 13, 30),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .allClear)
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

@Suite("SpcProvider.syncMapProducts", .serialized)
struct SpcProviderSyncMapProductsTests {
    @Test("Map sync caps concurrent product fanout at three")
    func mapSyncCapsFanoutAtThree() async throws {
        let container = try await makeMapSyncContainer()
        let client = CountingMapSyncClient(delayNanoseconds: 50_000_000)
        let provider = makeSpcProviderForMapSyncTests(container: container, client: client)

        await provider.syncMapProducts()

        #expect(await client.geoJsonCallCount() == 5)
        #expect(await client.maxConcurrentGeoJsonCalls() <= 3)
    }

    @Test("Concurrent calls share one in-flight map sync run")
    func concurrentCallsShareOneRun() async throws {
        let container = try await makeMapSyncContainer()
        let client = CountingMapSyncClient(delayNanoseconds: 50_000_000)
        let provider = makeSpcProviderForMapSyncTests(container: container, client: client)

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await provider.syncMapProducts() }
            group.addTask { await provider.syncMapProducts() }
            await group.waitForAll()
        }

        let calls = await client.geoJsonCallCount()
        #expect(calls == 5)
    }

    @Test("Back-to-back calls are throttled by map sync cooldown")
    func backToBackCallsAreThrottled() async throws {
        let container = try await makeMapSyncContainer()
        let client = CountingMapSyncClient()
        let provider = makeSpcProviderForMapSyncTests(container: container, client: client)

        await provider.syncMapProducts()
        await provider.syncMapProducts()

        let calls = await client.geoJsonCallCount()
        #expect(calls == 5)
    }

    @Test("Failed map product run does not trigger cooldown")
    func failedRunDoesNotTriggerCooldown() async throws {
        let container = try await makeMapSyncContainer()
        let client = CountingMapSyncClient(failingProduct: .hail)
        let provider = makeSpcProviderForMapSyncTests(container: container, client: client)

        await provider.syncMapProducts()
        await provider.syncMapProducts()

        let calls = await client.geoJsonCallCount()
        #expect(calls == 10)
    }

    @Test("Rejected empty categorical candidate preserves existing persisted risks")
    func rejectedEmptyCategoricalPreservesExistingPersistedRisks() async throws {
        let container = try await makeMapSyncContainer()
        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(geoJsonByProduct: makeCoherentBatch(categoricalFeatures: []))
        )

        let stormRepo = StormRiskRepo(modelContainer: container)
        let severeRepo = SevereRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(using: CategoricalMockClient(categoricalData: makeCategoricalData()))
        try await severeRepo.refreshTornadoRisk(using: MockClient(mode: .success(makeTornadoData())))

        await provider.syncMapProducts()

        let activeStorm = try await stormRepo.active(
            asOf: makeUTCDate(2027, 5, 1, 13, 0),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        let activeTornado = try await severeRepo.active(
            asOf: makeUTCDate(2027, 5, 1, 13, 0),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(activeStorm == .marginal)
        #expect(activeTornado == .tornado(probability: 0.02))
    }

    @Test("Future-only categorical candidate does not replace active projection window")
    func futureOnlyCategoricalDoesNotReplaceActiveProjectionWindow() async throws {
        let container = try await makeMapSyncContainer()
        let futureCategoricalData = makeCategoricalData(issue: "209905011200", valid: "209905011200", expire: "209905012000")
        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: makeCoherentBatch(
                    categoricalFeatures: try JSONDecoder()
                        .decode(GeoJSONFeatureCollection.self, from: futureCategoricalData).features
                )
            )
        )

        let stormRepo = StormRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(using: CategoricalMockClient(categoricalData: makeCategoricalData()))

        await provider.syncMapProducts()

        let active = try await stormRepo.active(
            asOf: makeUTCDate(2027, 5, 1, 13, 0),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .marginal)
    }

    @Test("Coherent categorical candidate allows empty severe product to clear active severe threat")
    func coherentCategoricalAllowsEmptySevereClear() async throws {
        let container = try await makeMapSyncContainer()
        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: makeCoherentBatch(categoricalFeatures: try JSONDecoder()
                    .decode(GeoJSONFeatureCollection.self, from: makeCategoricalData()).features, tornadoData: emptyGeoJSONData())
            )
        )

        let severeRepo = SevereRiskRepo(modelContainer: container)
        try await severeRepo.refreshTornadoRisk(using: MockClient(mode: .success(makeTornadoData())))

        await provider.syncMapProducts()

        let active = try await severeRepo.active(
            asOf: makeUTCDate(2027, 5, 1, 13, 0),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .allClear)
    }
}

private actor CountingMapSyncClient: SpcClient {
    private var geoJsonCalls = 0
    private var inFlightGeoJsonCalls = 0
    private var maxConcurrentGeoJsonCallsValue = 0
    private let delayNanoseconds: UInt64
    private let failingProduct: GeoJSONProduct?

    init(delayNanoseconds: UInt64 = 0, failingProduct: GeoJSONProduct? = nil) {
        self.delayNanoseconds = delayNanoseconds
        self.failingProduct = failingProduct
    }

    func fetchRssData(for product: RssProduct) async throws -> Data {
        Data()
    }

    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data {
        geoJsonCalls += 1
        inFlightGeoJsonCalls += 1
        maxConcurrentGeoJsonCallsValue = max(maxConcurrentGeoJsonCallsValue, inFlightGeoJsonCalls)

        defer {
            inFlightGeoJsonCalls -= 1
        }

        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if product == failingProduct {
            throw SpcError.missingData
        }
        if product == .categorical {
            return makeCategoricalData()
        }
        return emptyGeoJSONData()
    }

    func geoJsonCallCount() -> Int {
        geoJsonCalls
    }

    func maxConcurrentGeoJsonCalls() -> Int {
        maxConcurrentGeoJsonCallsValue
    }
}

private struct ScriptedMapSyncClient: SpcClient {
    let geoJsonByProduct: [GeoJSONProduct: Data]

    func fetchRssData(for product: RssProduct) async throws -> Data {
        Data()
    }

    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data {
        guard let data = geoJsonByProduct[product] else {
            throw SpcError.missingGeoJsonData
        }
        return data
    }
}

private func makeSpcProviderForMapSyncTests(container: ModelContainer, client: any SpcClient) -> SpcProvider {
    let outlookRepo = ConvectiveOutlookRepo(modelContainer: container)
    let mesoRepo = MesoRepo(modelContainer: container)
    let alertRepo = AlertRepo(modelContainer: container)
    let stormRiskRepo = StormRiskRepo(modelContainer: container)
    let severeRiskRepo = SevereRiskRepo(modelContainer: container)
    let fireRiskRepo = FireRiskRepo(modelContainer: container)

    return SpcProvider(
        outlookRepo: outlookRepo,
        mesoRepo: mesoRepo,
        alertRepo: alertRepo,
        stormRiskRepo: stormRiskRepo,
        severeRiskRepo: severeRiskRepo,
        fireRiskRepo: fireRiskRepo,
        client: client
    )
}

private func makeMapSyncContainer() async throws -> ModelContainer {
    try await MainActor.run {
        let container = try TestStore.container(
            for: [ConvectiveOutlook.self, MD.self, Watch.self, StormRisk.self, SevereRisk.self, FireRisk.self]
        )
        try TestStore.reset(ConvectiveOutlook.self, in: container)
        try TestStore.reset(MD.self, in: container)
        try TestStore.reset(Watch.self, in: container)
        try TestStore.reset(StormRisk.self, in: container)
        try TestStore.reset(SevereRisk.self, in: container)
        try TestStore.reset(FireRisk.self, in: container)
        return container
    }
}

private func makeCoherentBatch(
    categoricalFeatures: [GeoJSONFeature],
    tornadoData: Data? = nil
) -> [GeoJSONProduct: Data] {
    [
        .categorical: (try? JSONEncoder().encode(makeFeatureCollection(features: categoricalFeatures))) ?? emptyGeoJSONData(),
        .hail: emptyGeoJSONData(),
        .wind: emptyGeoJSONData(),
        .tornado: tornadoData ?? emptyGeoJSONData(),
        .fireRH: emptyGeoJSONData()
    ]
}

private func emptyGeoJSONData() -> Data {
    (try? JSONEncoder().encode(GeoJSONFeatureCollection.empty)) ?? Data()
}

private func makeCategoricalData(
    issue: String? = nil,
    valid: String? = nil,
    expire: String? = nil
) -> Data {
    let now = Date()
    let issueTimestamp = issue ?? spcTimestamp(now.addingTimeInterval(-3600))
    let validTimestamp = valid ?? spcTimestamp(now.addingTimeInterval(-3600))
    let expireTimestamp = expire ?? spcTimestamp(now.addingTimeInterval(6 * 3600))

    let feature = makeFeature(
        properties: makeProperties(
            label: "MRGL",
            label2: "Marginal Risk",
            issue: issueTimestamp,
            valid: validTimestamp,
            expire: expireTimestamp,
            dn: 2
        ),
        geometry: makeMultiPolygonGeometry(squareAtLonLat: (-105.0, 39.0), size: 1.5)
    )
    return (try? JSONEncoder().encode(makeFeatureCollection(features: [feature]))) ?? emptyGeoJSONData()
}

private func makeTornadoData() -> Data {
    let now = Date()
    let feature = makeFeature(
        properties: makeProperties(
            label: "0.02",
            label2: "2% Tornado Risk",
            issue: spcTimestamp(now.addingTimeInterval(-3600)),
            valid: spcTimestamp(now.addingTimeInterval(-3600)),
            expire: spcTimestamp(now.addingTimeInterval(6 * 3600)),
            dn: 2
        ),
        geometry: makeMultiPolygonGeometry(squareAtLonLat: (-105.0, 39.0), size: 1.5)
    )
    return (try? JSONEncoder().encode(makeFeatureCollection(features: [feature]))) ?? emptyGeoJSONData()
}

private func spcTimestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMddHHmm"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
}
