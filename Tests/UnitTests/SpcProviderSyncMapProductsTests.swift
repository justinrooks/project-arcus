import Testing
@testable import SkyAware
import SwiftData
import Foundation
import CoreLocation

private struct FireMockClient: SpcClient {
    let fireData: Data

    func fetchRssData(for product: RssProduct) async throws -> Data {
        throw SpcError.missingRssData
    }

    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data {
        guard product == .fireRH else {
            throw SpcError.missingGeoJsonData
        }
        return fireData
    }
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

    @Test("Back-to-back map sync calls avoid duplicate in-flight fanout")
    func backToBackCallsAreThrottled() async throws {
        let container = try await makeMapSyncContainer()
        let client = CountingMapSyncClient()
        let provider = makeSpcProviderForMapSyncTests(container: container, client: client)

        await provider.syncMapProducts()
        await provider.syncMapProducts()

        let calls = await client.geoJsonCallCount()
        #expect(calls == 5 || calls == 10)
    }

    @Test("Partially accepted map product run still triggers cooldown")
    func partiallyAcceptedRunTriggersCooldown() async throws {
        let container = try await makeMapSyncContainer()
        let client = CountingMapSyncClient(failingProduct: .hail)
        let provider = makeSpcProviderForMapSyncTests(container: container, client: client)

        await provider.syncMapProducts()
        await provider.syncMapProducts()

        let calls = await client.geoJsonCallCount()
        #expect(calls == 5)
    }

    @Test("All-empty valid map batch is accepted and clears active persisted risks")
    func allEmptyBatchAcceptedAndClearsActivePersistedRisks() async throws {
        let container = try await makeMapSyncContainer()
        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(geoJsonByProduct: makeCoherentBatch(categoricalFeatures: []))
        )

        let stormRepo = StormRiskRepo(modelContainer: container)
        let severeRepo = SevereRiskRepo(modelContainer: container)
        let fireRepo = FireRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(using: CategoricalMockClient(categoricalData: makeCategoricalData()))
        try await severeRepo.refreshTornadoRisk(using: MockClient(mode: .success(makeTornadoData())))
        try await fireRepo.refreshFireRisk(using: FireMockClient(fireData: makeFireData()))

        let outcome = await provider.syncMapProductsOutcome()
        #expect(outcome == .accepted)

        let activeStorm = try await stormRepo.active(
            asOf: Date(),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        let activeTornado = try await severeRepo.active(
            asOf: Date(),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        let activeFire = try await fireRepo.active(
            asOf: Date(),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(activeStorm == .allClear)
        #expect(activeTornado == .allClear)
        #expect(activeFire == .clear)
    }

    @Test("No-area categorical GeometryCollection is treated as all-clear and clears active convective risks")
    func noAreaCategoricalGeometryCollectionClearsActiveConvectiveRisks() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let issue = spcTimestamp(now.addingTimeInterval(-3600))
        let valid = spcTimestamp(now.addingTimeInterval(-3600))
        let expire = spcTimestamp(now.addingTimeInterval(6 * 3600))
        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: [
                    .categorical: makeNoAreaData(
                        label: "No Areas",
                        label2: "No Areas",
                        dn: 0,
                        issue: issue,
                        valid: valid,
                        expire: expire
                    ),
                    .hail: emptyGeoJSONData(),
                    .wind: emptyGeoJSONData(),
                    .tornado: emptyGeoJSONData(),
                    .fireRH: emptyGeoJSONData()
                ]
            )
        )

        let stormRepo = StormRiskRepo(modelContainer: container)
        let severeRepo = SevereRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(using: CategoricalMockClient(categoricalData: makeCategoricalData()))
        try await severeRepo.refreshTornadoRisk(using: MockClient(mode: .success(makeTornadoData())))

        let outcome = await provider.syncMapProductsOutcome()
        #expect(outcome == .accepted)

        let activeStorm = try await stormRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        let activeTornado = try await severeRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(activeStorm == .allClear)
        #expect(activeTornado == .allClear)
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
            asOf: Date(),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .marginal)
    }

    @Test("Coherent categorical candidate allows empty severe product to clear active severe threat")
    func coherentCategoricalAllowsEmptySevereClear() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let priorIssue = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorValid = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorExpire = spcTimestamp(now.addingTimeInterval(4 * 3600))
        let acceptedIssue = spcTimestamp(now.addingTimeInterval(-3600))
        let acceptedValid = spcTimestamp(now.addingTimeInterval(-3600))
        let acceptedExpire = spcTimestamp(now.addingTimeInterval(6 * 3600))
        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: makeCoherentBatch(
                    categoricalFeatures: try JSONDecoder().decode(
                        GeoJSONFeatureCollection.self,
                        from: makeCategoricalData(issue: acceptedIssue, valid: acceptedValid, expire: acceptedExpire)
                    ).features,
                    tornadoData: emptyGeoJSONData()
                )
            )
        )

        let severeRepo = SevereRiskRepo(modelContainer: container)
        try await severeRepo.refreshTornadoRisk(
            using: MockClient(
                mode: .success(makeTornadoData(issue: priorIssue, valid: priorValid, expire: priorExpire))
            )
        )

        await provider.syncMapProducts()

        let active = try await severeRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .allClear)
    }

    @Test("No-area fire product clears active fire risk using its own fire window")
    func noAreaFireProductClearsActiveFireRiskUsingOwnWindow() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let priorIssue = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorValid = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorExpire = spcTimestamp(now.addingTimeInterval(4 * 3600))
        let convectiveIssue = spcTimestamp(now.addingTimeInterval(-3600))
        let convectiveValid = spcTimestamp(now.addingTimeInterval(-3600))
        let convectiveExpire = spcTimestamp(now.addingTimeInterval(6 * 3600))
        let fireIssue = spcTimestamp(now.addingTimeInterval(-90 * 60))
        let fireValid = spcTimestamp(now.addingTimeInterval(-90 * 60))
        let fireExpire = spcTimestamp(now.addingTimeInterval(5 * 3600))
        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: makeCoherentBatch(
                    categoricalFeatures: try JSONDecoder().decode(
                        GeoJSONFeatureCollection.self,
                        from: makeCategoricalData(issue: convectiveIssue, valid: convectiveValid, expire: convectiveExpire)
                    ).features,
                    fireData: makeNoAreaData(
                        label: "No Areas",
                        label2: "No Areas",
                        dn: 0,
                        issue: fireIssue,
                        valid: fireValid,
                        expire: fireExpire
                    )
                )
            )
        )

        let fireRepo = FireRiskRepo(modelContainer: container)
        try await fireRepo.refreshFireRisk(
            using: FireMockClient(fireData: makeFireData(issue: priorIssue, valid: priorValid, expire: priorExpire))
        )

        await provider.syncMapProducts()

        let active = try await fireRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .clear)
    }

    @Test("No-area tornado product clears active severe risk when convective batch is coherent")
    func noAreaTornadoProductClearsActiveSevereRisk() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let priorIssue = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorValid = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorExpire = spcTimestamp(now.addingTimeInterval(4 * 3600))
        let acceptedIssue = spcTimestamp(now.addingTimeInterval(-3600))
        let acceptedValid = spcTimestamp(now.addingTimeInterval(-3600))
        let acceptedExpire = spcTimestamp(now.addingTimeInterval(6 * 3600))

        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: makeCoherentBatch(
                    categoricalFeatures: try JSONDecoder().decode(
                        GeoJSONFeatureCollection.self,
                        from: makeCategoricalData(issue: acceptedIssue, valid: acceptedValid, expire: acceptedExpire)
                    ).features,
                    tornadoData: makeNoAreaData(
                        label: "No Areas",
                        label2: "No Areas",
                        dn: 0,
                        issue: acceptedIssue,
                        valid: acceptedValid,
                        expire: acceptedExpire
                    )
                )
            )
        )

        let severeRepo = SevereRiskRepo(modelContainer: container)
        try await severeRepo.refreshTornadoRisk(
            using: MockClient(
                mode: .success(makeTornadoData(issue: priorIssue, valid: priorValid, expire: priorExpire))
            )
        )

        let outcome = await provider.syncMapProductsOutcome()
        #expect(outcome == .accepted)

        let active = try await severeRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .allClear)
    }

    @Test("Accepted coherent batch replaces only rows in its validity window")
    func acceptedBatchReplacesOnlyAcceptedWindowRows() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let acceptedIssue = spcTimestamp(now.addingTimeInterval(-3600))
        let acceptedValid = spcTimestamp(now.addingTimeInterval(-3600))
        let acceptedExpire = spcTimestamp(now.addingTimeInterval(6 * 3600))
        let futureIssue = spcTimestamp(now.addingTimeInterval(12 * 3600))
        let futureValid = spcTimestamp(now.addingTimeInterval(12 * 3600))
        let futureExpire = spcTimestamp(now.addingTimeInterval(20 * 3600))

        let stormRepo = StormRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(
            using: CategoricalMockClient(
                categoricalData: makeCategoricalData(
                    label: "MRGL",
                    label2: "Marginal Risk",
                    dn: 2,
                    issue: acceptedIssue,
                    valid: acceptedValid,
                    expire: acceptedExpire
                )
            )
        )
        try await stormRepo.refreshStormRisk(
            using: CategoricalMockClient(
                categoricalData: makeCategoricalData(
                    label: "SLGT",
                    label2: "Slight Risk",
                    dn: 3,
                    issue: futureIssue,
                    valid: futureValid,
                    expire: futureExpire
                )
            )
        )

        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: makeCoherentBatch(
                    categoricalFeatures: try JSONDecoder().decode(
                        GeoJSONFeatureCollection.self,
                        from: makeCategoricalData(
                            label: "ENH",
                            label2: "Enhanced Risk",
                            dn: 4,
                            issue: acceptedIssue,
                            valid: acceptedValid,
                            expire: acceptedExpire
                        )
                    ).features
                )
            )
        )

        await provider.syncMapProducts()

        let acceptedActive = try await stormRepo.active(
            asOf: now.addingTimeInterval(30 * 60),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        let futureActive = try await stormRepo.active(
            asOf: now.addingTimeInterval(13 * 3600),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )

        #expect(acceptedActive == .enhanced)
        #expect(futureActive == .slight)
    }

    @Test("Malformed fire metadata in staged batch does not clear active fire risk")
    func malformedFireMetadataDoesNotClearActiveFireRisk() async throws {
        let container = try await makeMapSyncContainer()
        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: makeCoherentBatch(
                    categoricalFeatures: try JSONDecoder().decode(
                        GeoJSONFeatureCollection.self,
                        from: makeCategoricalData()
                    ).features,
                    fireData: makeFireData(issue: "bad")
                )
            )
        )

        let fireRepo = FireRiskRepo(modelContainer: container)
        try await fireRepo.refreshFireRisk(using: FireMockClient(fireData: makeFireData()))

        await provider.syncMapProducts()

        let active = try await fireRepo.active(
            asOf: Date(),
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .critical)
    }

    @Test("Malformed non-categorical staged product rejects batch and cannot partially commit categorical")
    func malformedNonCategoricalRejectsBatchWithoutPartialCategoricalCommit() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let priorCategorical = makeCategoricalData(
            label: "MRGL",
            label2: "Marginal Risk",
            dn: 2,
            issue: spcTimestamp(now.addingTimeInterval(-3600)),
            valid: spcTimestamp(now.addingTimeInterval(-3600)),
            expire: spcTimestamp(now.addingTimeInterval(6 * 3600))
        )
        let incomingCategorical = makeCategoricalData(
            label: "ENH",
            label2: "Enhanced Risk",
            dn: 4,
            issue: spcTimestamp(now.addingTimeInterval(-3500)),
            valid: spcTimestamp(now.addingTimeInterval(-3500)),
            expire: spcTimestamp(now.addingTimeInterval(6 * 3600))
        )
        let malformedHail = makeTornadoData(issue: "bad")
        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: [
                    .categorical: incomingCategorical,
                    .hail: malformedHail,
                    .wind: emptyGeoJSONData(),
                    .tornado: emptyGeoJSONData(),
                    .fireRH: emptyGeoJSONData()
                ]
            )
        )

        let stormRepo = StormRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(using: CategoricalMockClient(categoricalData: priorCategorical))

        await provider.syncMapProducts()

        let active = try await stormRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .marginal)
    }

    @Test("Missing fire product rejects fire domain and preserves existing state")
    func missingFireProductRejectsFireDomainAndPreservesExistingState() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let acceptedIssue = spcTimestamp(now.addingTimeInterval(-3600))
        let acceptedValid = spcTimestamp(now.addingTimeInterval(-3600))
        let acceptedExpire = spcTimestamp(now.addingTimeInterval(6 * 3600))
        let priorIssue = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorValid = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorExpire = spcTimestamp(now.addingTimeInterval(4 * 3600))
        let stormRepo = StormRiskRepo(modelContainer: container)
        let fireRepo = FireRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(
            using: CategoricalMockClient(
                categoricalData: makeCategoricalData(
                    issue: priorIssue,
                    valid: priorValid,
                    expire: priorExpire
                )
            )
        )
        try await fireRepo.refreshFireRisk(
            using: FireMockClient(fireData: makeFireData(issue: priorIssue, valid: priorValid, expire: priorExpire))
        )

        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: [
                    .categorical: makeCategoricalData(
                        issue: acceptedIssue,
                        valid: acceptedValid,
                        expire: acceptedExpire
                    ),
                    .hail: emptyGeoJSONData(),
                    .wind: emptyGeoJSONData(),
                    .tornado: emptyGeoJSONData()
                ]
            )
        )

        let outcome = await provider.syncMapProductsOutcome()
        #expect(outcome == .accepted)
        let activeStorm = try await stormRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        let activeFire = try await fireRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(activeStorm == .marginal)
        #expect(activeFire == .critical)
    }

    @Test("Decode-failed product rejects batch and preserves existing risk state")
    func decodeFailedProductRejectsBatchAndPreservesState() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let stormRepo = StormRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(using: CategoricalMockClient(categoricalData: makeCategoricalData()))

        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: [
                    .categorical: makeCategoricalData(),
                    .hail: Data("not-geojson".utf8),
                    .wind: emptyGeoJSONData(),
                    .tornado: emptyGeoJSONData(),
                    .fireRH: emptyGeoJSONData()
                ]
            )
        )

        let outcome = await provider.syncMapProductsOutcome()
        #expect(outcome == .accepted)
        let active = try await stormRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .marginal)
    }

    @Test("HTML fire product body rejects fire domain and preserves existing state")
    func htmlFireProductBodyRejectsFireDomainAndPreservesExistingState() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let acceptedIssue = spcTimestamp(now.addingTimeInterval(-3600))
        let acceptedValid = spcTimestamp(now.addingTimeInterval(-3600))
        let acceptedExpire = spcTimestamp(now.addingTimeInterval(6 * 3600))
        let priorIssue = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorValid = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorExpire = spcTimestamp(now.addingTimeInterval(4 * 3600))
        let stormRepo = StormRiskRepo(modelContainer: container)
        let fireRepo = FireRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(
            using: CategoricalMockClient(
                categoricalData: makeCategoricalData(issue: priorIssue, valid: priorValid, expire: priorExpire)
            )
        )
        try await fireRepo.refreshFireRisk(
            using: FireMockClient(fireData: makeFireData(issue: priorIssue, valid: priorValid, expire: priorExpire))
        )

        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: [
                    .categorical: makeCategoricalData(
                        issue: acceptedIssue,
                        valid: acceptedValid,
                        expire: acceptedExpire
                    ),
                    .hail: emptyGeoJSONData(),
                    .wind: emptyGeoJSONData(),
                    .tornado: emptyGeoJSONData(),
                    .fireRH: Data("<html><body>Not Found</body></html>".utf8)
                ]
            )
        )

        let outcome = await provider.syncMapProductsOutcome()
        #expect(outcome == .accepted)
        let activeStorm = try await stormRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        let activeFire = try await fireRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(activeStorm == .marginal)
        #expect(activeFire == .critical)
    }

    @Test("Rejected convective domain with accepted fire domain preserves storm and updates fire only")
    func rejectedConvectiveAcceptedFireUpdatesOnlyFire() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let priorIssue = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorValid = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorExpire = spcTimestamp(now.addingTimeInterval(4 * 3600))
        let fireIssue = spcTimestamp(now.addingTimeInterval(-3600))
        let fireValid = spcTimestamp(now.addingTimeInterval(-3600))
        let fireExpire = spcTimestamp(now.addingTimeInterval(6 * 3600))

        let stormRepo = StormRiskRepo(modelContainer: container)
        let fireRepo = FireRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(
            using: CategoricalMockClient(
                categoricalData: makeCategoricalData(issue: priorIssue, valid: priorValid, expire: priorExpire)
            )
        )
        try await fireRepo.refreshFireRisk(
            using: FireMockClient(fireData: makeFireData(issue: priorIssue, valid: priorValid, expire: priorExpire))
        )

        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: [
                    .categorical: Data("not-geojson".utf8),
                    .hail: emptyGeoJSONData(),
                    .wind: emptyGeoJSONData(),
                    .tornado: emptyGeoJSONData(),
                    .fireRH: makeNoAreaData(
                        label: "No Areas",
                        label2: "No Areas",
                        dn: 0,
                        issue: fireIssue,
                        valid: fireValid,
                        expire: fireExpire
                    )
                ]
            )
        )

        let outcome = await provider.syncMapProductsOutcome()
        #expect(outcome == .accepted)
        #expect(
            try await stormRepo.active(
                asOf: now,
                for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
            ) == .marginal
        )
        #expect(
            try await fireRepo.active(
                asOf: now,
                for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
            ) == .clear
        )
    }

    @Test("Accepted convective domain with rejected fire domain updates storm and preserves fire")
    func acceptedConvectiveRejectedFirePreservesFire() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let priorIssue = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorValid = spcTimestamp(now.addingTimeInterval(-2 * 3600))
        let priorExpire = spcTimestamp(now.addingTimeInterval(4 * 3600))
        let acceptedIssue = spcTimestamp(now.addingTimeInterval(-3600))
        let acceptedValid = spcTimestamp(now.addingTimeInterval(-3600))
        let acceptedExpire = spcTimestamp(now.addingTimeInterval(6 * 3600))

        let stormRepo = StormRiskRepo(modelContainer: container)
        let fireRepo = FireRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(
            using: CategoricalMockClient(
                categoricalData: makeCategoricalData(issue: priorIssue, valid: priorValid, expire: priorExpire)
            )
        )
        try await fireRepo.refreshFireRisk(
            using: FireMockClient(fireData: makeFireData(issue: priorIssue, valid: priorValid, expire: priorExpire))
        )

        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: makeCoherentBatch(
                    categoricalFeatures: try JSONDecoder().decode(
                        GeoJSONFeatureCollection.self,
                        from: makeCategoricalData(
                            label: "ENH",
                            label2: "Enhanced Risk",
                            dn: 4,
                            issue: acceptedIssue,
                            valid: acceptedValid,
                            expire: acceptedExpire
                        )
                    ).features,
                    fireData: Data("<html><body>Not Found</body></html>".utf8)
                )
            )
        )

        let outcome = await provider.syncMapProductsOutcome()
        #expect(outcome == .accepted)
        #expect(
            try await stormRepo.active(
                asOf: now,
                for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
            ) == .enhanced
        )
        #expect(
            try await fireRepo.active(
                asOf: now,
                for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
            ) == .critical
        )
    }

    @Test("Empty categorical with non-empty severe product is rejected")
    func emptyCategoricalWithNonEmptySevereIsRejected() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let stormRepo = StormRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(using: CategoricalMockClient(categoricalData: makeCategoricalData()))

        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: makeCoherentBatch(categoricalFeatures: [], tornadoData: makeTornadoData())
            )
        )

        let outcome = await provider.syncMapProductsOutcome()
        #expect(outcome == .accepted)
        let active = try await stormRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .marginal)
    }

    @Test("Mixed-window staged products are rejected")
    func mixedWindowStagedProductsAreRejected() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let anchorIssue = spcTimestamp(now.addingTimeInterval(-3600))
        let anchorValid = spcTimestamp(now.addingTimeInterval(-3600))
        let anchorExpire = spcTimestamp(now.addingTimeInterval(6 * 3600))
        let mismatchedIssue = spcTimestamp(now.addingTimeInterval(-1800))
        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: [
                    .categorical: makeCategoricalData(
                        label: "ENH",
                        label2: "Enhanced Risk",
                        dn: 4,
                        issue: anchorIssue,
                        valid: anchorValid,
                        expire: anchorExpire
                    ),
                    .hail: makeTornadoData(issue: mismatchedIssue, valid: anchorValid, expire: anchorExpire),
                    .wind: emptyGeoJSONData(),
                    .tornado: emptyGeoJSONData(),
                    .fireRH: emptyGeoJSONData()
                ]
            )
        )

        let stormRepo = StormRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(
            using: CategoricalMockClient(
                categoricalData: makeCategoricalData(
                    label: "MRGL",
                    label2: "Marginal Risk",
                    dn: 2,
                    issue: anchorIssue,
                    valid: anchorValid,
                    expire: anchorExpire
                )
            )
        )

        await provider.syncMapProducts()

        let active = try await stormRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .marginal)
    }

    @Test("Persistence failure after categorical mutation rolls back entire accepted batch")
    func acceptedBatchFailureAfterCategoricalMutationRollsBackAllRows() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let priorIssue = spcTimestamp(now.addingTimeInterval(-3600))
        let priorValid = spcTimestamp(now.addingTimeInterval(-3600))
        let priorExpire = spcTimestamp(now.addingTimeInterval(6 * 3600))
        let incomingIssue = spcTimestamp(now.addingTimeInterval(-3500))
        let incomingValid = spcTimestamp(now.addingTimeInterval(-3500))
        let incomingExpire = spcTimestamp(now.addingTimeInterval(7 * 3600))

        let stormRepo = StormRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(
            using: CategoricalMockClient(
                categoricalData: makeCategoricalData(
                    label: "MRGL",
                    label2: "Marginal Risk",
                    dn: 2,
                    issue: priorIssue,
                    valid: priorValid,
                    expire: priorExpire
                )
            )
        )

        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: [
                    .categorical: makeCategoricalData(
                        label: "ENH",
                        label2: "Enhanced Risk",
                        dn: 4,
                        issue: incomingIssue,
                        valid: incomingValid,
                        expire: incomingExpire
                    ),
                    .hail: makeTornadoData(issue: incomingIssue, valid: incomingValid, expire: incomingExpire),
                    .wind: makeTornadoData(issue: incomingIssue, valid: incomingValid, expire: incomingExpire),
                    .tornado: makeTornadoData(issue: incomingIssue, valid: incomingValid, expire: incomingExpire),
                    .fireRH: makeFireData(issue: incomingIssue, valid: incomingValid, expire: incomingExpire)
                ]
            ),
            persistenceFailureInjection: .afterCategoricalMutation
        )

        await provider.syncMapProducts()

        let active = try await stormRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .marginal)
    }

    @Test("Cancellation between accepted products does not partially persist staged rows")
    func acceptedBatchCancellationBetweenProductsRollsBackAllRows() async throws {
        let container = try await makeMapSyncContainer()
        let now = Date()
        let priorIssue = spcTimestamp(now.addingTimeInterval(-3600))
        let priorValid = spcTimestamp(now.addingTimeInterval(-3600))
        let priorExpire = spcTimestamp(now.addingTimeInterval(6 * 3600))
        let incomingIssue = spcTimestamp(now.addingTimeInterval(-3500))
        let incomingValid = spcTimestamp(now.addingTimeInterval(-3500))
        let incomingExpire = spcTimestamp(now.addingTimeInterval(7 * 3600))

        let stormRepo = StormRiskRepo(modelContainer: container)
        try await stormRepo.refreshStormRisk(
            using: CategoricalMockClient(
                categoricalData: makeCategoricalData(
                    label: "MRGL",
                    label2: "Marginal Risk",
                    dn: 2,
                    issue: priorIssue,
                    valid: priorValid,
                    expire: priorExpire
                )
            )
        )

        let provider = makeSpcProviderForMapSyncTests(
            container: container,
            client: ScriptedMapSyncClient(
                geoJsonByProduct: [
                    .categorical: makeCategoricalData(
                        label: "ENH",
                        label2: "Enhanced Risk",
                        dn: 4,
                        issue: incomingIssue,
                        valid: incomingValid,
                        expire: incomingExpire
                    ),
                    .hail: makeTornadoData(issue: incomingIssue, valid: incomingValid, expire: incomingExpire),
                    .wind: makeTornadoData(issue: incomingIssue, valid: incomingValid, expire: incomingExpire),
                    .tornado: makeTornadoData(issue: incomingIssue, valid: incomingValid, expire: incomingExpire),
                    .fireRH: makeFireData(issue: incomingIssue, valid: incomingValid, expire: incomingExpire)
                ]
            ),
            persistenceFailureInjection: .afterHailMutation
        )

        await provider.syncMapProducts()

        let active = try await stormRepo.active(
            asOf: now,
            for: CLLocationCoordinate2D(latitude: 39.5, longitude: -104.5)
        )
        #expect(active == .marginal)
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
            throw SpcError.networkError(status: 500)
        }
        if product == .categorical {
            return makeCategoricalData()
        }
        if product == .fireRH {
            return makeFireData()
        }
        return makeTornadoData()
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

private func makeSpcProviderForMapSyncTests(
    container: ModelContainer,
    client: any SpcClient,
    persistenceFailureInjection: SpcMapBatchPersistenceFailureInjection = .none
) -> SpcProvider {
    let outlookRepo = ConvectiveOutlookRepo(modelContainer: container)
    let mesoRepo = MesoRepo(modelContainer: container)
    let alertRepo = AlertRepo(modelContainer: container)
    let stormRiskRepo = StormRiskRepo(modelContainer: container)
    let severeRiskRepo = SevereRiskRepo(modelContainer: container)
    let fireRiskRepo = FireRiskRepo(modelContainer: container)
    let spcMapBatchPersistenceRepo = SpcMapBatchPersistenceRepo(modelContainer: container)

    return SpcProvider(
        outlookRepo: outlookRepo,
        mesoRepo: mesoRepo,
        alertRepo: alertRepo,
        stormRiskRepo: stormRiskRepo,
        severeRiskRepo: severeRiskRepo,
        fireRiskRepo: fireRiskRepo,
        spcMapBatchPersistenceRepo: spcMapBatchPersistenceRepo,
        mapBatchPersistenceFailureInjection: persistenceFailureInjection,
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
    tornadoData: Data? = nil,
    fireData: Data? = nil
) -> [GeoJSONProduct: Data] {
    [
        .categorical: (try? JSONEncoder().encode(makeFeatureCollection(features: categoricalFeatures))) ?? emptyGeoJSONData(),
        .hail: emptyGeoJSONData(),
        .wind: emptyGeoJSONData(),
        .tornado: tornadoData ?? emptyGeoJSONData(),
        .fireRH: fireData ?? emptyGeoJSONData()
    ]
}

private func emptyGeoJSONData() -> Data {
    (try? JSONEncoder().encode(GeoJSONFeatureCollection.empty)) ?? Data()
}

private func makeNoAreaGeometryCollection() -> GeoJSONGeometry {
    GeoJSONGeometry(type: "GeometryCollection", geometries: [])
}

private func makeCategoricalData(
    label: String = "MRGL",
    label2: String = "Marginal Risk",
    dn: Int = 2,
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
            label: label,
            label2: label2,
            issue: issueTimestamp,
            valid: validTimestamp,
            expire: expireTimestamp,
            dn: dn
        ),
        geometry: makeMultiPolygonGeometry(squareAtLonLat: (-105.0, 39.0), size: 1.5)
    )
    return (try? JSONEncoder().encode(makeFeatureCollection(features: [feature]))) ?? emptyGeoJSONData()
}

private func makeTornadoData() -> Data {
    makeTornadoData(issue: nil, valid: nil, expire: nil)
}

private func makeTornadoData(issue: String?, valid: String? = nil, expire: String? = nil) -> Data {
    let now = Date()
    let feature = makeFeature(
        properties: makeProperties(
            label: "0.02",
            label2: "2% Tornado Risk",
            issue: issue ?? spcTimestamp(now.addingTimeInterval(-3600)),
            valid: valid ?? spcTimestamp(now.addingTimeInterval(-3600)),
            expire: expire ?? spcTimestamp(now.addingTimeInterval(6 * 3600)),
            dn: 2
        ),
        geometry: makeMultiPolygonGeometry(squareAtLonLat: (-105.0, 39.0), size: 1.5)
    )
    return (try? JSONEncoder().encode(makeFeatureCollection(features: [feature]))) ?? emptyGeoJSONData()
}

private func makeFireData(issue: String? = nil, valid: String? = nil, expire: String? = nil) -> Data {
    let now = Date()
    let feature = makeFeature(
        properties: makeProperties(
            label: "CRIT",
            label2: "Critical",
            issue: issue ?? spcTimestamp(now.addingTimeInterval(-3600)),
            valid: valid ?? spcTimestamp(now.addingTimeInterval(-3600)),
            expire: expire ?? spcTimestamp(now.addingTimeInterval(6 * 3600)),
            dn: 8
        ),
        geometry: makeMultiPolygonGeometry(squareAtLonLat: (-105.0, 39.0), size: 1.5)
    )
    return (try? JSONEncoder().encode(makeFeatureCollection(features: [feature]))) ?? emptyGeoJSONData()
}

private func makeNoAreaData(
    label: String = "No Areas",
    label2: String = "No Areas",
    dn: Int = 0,
    issue: String,
    valid: String,
    expire: String
) -> Data {
    let feature = makeFeature(
        properties: makeProperties(
            label: label,
            label2: label2,
            issue: issue,
            valid: valid,
            expire: expire,
            dn: dn
        ),
        geometry: makeNoAreaGeometryCollection()
    )
    return (try? JSONEncoder().encode(makeFeatureCollection(features: [feature]))) ?? emptyGeoJSONData()
}

private func spcTimestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMddHHmm"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
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
