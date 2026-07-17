import Foundation
import CoreLocation
import SwiftData
import Testing
@testable import SkyAware

@Suite("MapData freshness filtering", .serialized)
struct MapDataFreshnessRepoTests {
    @Test("Fire map returns only the newest valid issuance")
    func fireMapReturnsOnlyNewestValidIssuance() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [FireRisk.self]) }
        try await MainActor.run { try TestStore.reset(FireRisk.self, in: container) }

        let repo = FireRiskRepo(modelContainer: container)
        let asOf = makeUTCDate(2026, 3, 1, 12, 0)
        let valid = makeUTCDate(2026, 3, 1, 9, 0)
        let expires = makeUTCDate(2026, 3, 1, 21, 0)
        let olderIssue = makeUTCDate(2026, 3, 1, 9, 0)
        let newerIssue = makeUTCDate(2026, 3, 1, 11, 0)
        let level5Issue = makeUTCDate(2026, 3, 1, 10, 0)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                FireRisk(
                    product: "FireRH",
                    issued: olderIssue,
                    expires: expires,
                    valid: valid,
                    riskLevel: 8,
                    label: "Critical",
                    stroke: "#AA0000",
                    fill: "#110000",
                    polygons: []
                )
            )
            context.insert(
                FireRisk(
                    product: "FireRH",
                    issued: newerIssue,
                    expires: expires,
                    valid: valid,
                    riskLevel: 8,
                    label: "Critical",
                    stroke: "#BB0000",
                    fill: "#220000",
                    polygons: []
                )
            )
            context.insert(
                FireRisk(
                    product: "FireRH",
                    issued: level5Issue,
                    expires: expires,
                    valid: valid,
                    riskLevel: 5,
                    label: "Elevated",
                    stroke: "#CCCC00",
                    fill: "#333300",
                    polygons: []
                )
            )
            try context.save()
        }

        let results = try await repo.getLatestMapData(asOf: asOf)
        #expect(results.count == 1)

        let byLevel = Dictionary(uniqueKeysWithValues: results.map { ($0.riskLevel, $0) })
        #expect(byLevel[8]?.issued == newerIssue)
        #expect(byLevel[5] == nil)
    }

    @Test("Fire map includes products exactly at the expiry boundary")
    func fireMapIncludesProductsAtExpiryBoundary() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [FireRisk.self]) }
        try await MainActor.run { try TestStore.reset(FireRisk.self, in: container) }

        let repo = FireRiskRepo(modelContainer: container)
        let asOf = makeUTCDate(2026, 3, 1, 21, 0)
        let valid = makeUTCDate(2026, 3, 1, 9, 0)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                FireRisk(
                    product: "FireRH",
                    issued: makeUTCDate(2026, 3, 1, 11, 0),
                    expires: asOf,
                    valid: valid,
                    riskLevel: 8,
                    label: "Critical",
                    stroke: "#BB0000",
                    fill: "#220000",
                    polygons: []
                )
            )
            try context.save()
        }

        let results = try await repo.getLatestMapData(asOf: asOf)
        #expect(results.map(\.riskLevel) == [8])
    }

    @Test("Categorical map returns only the newest valid issuance")
    func stormMapReturnsOnlyNewestValidIssuance() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [StormRisk.self]) }
        try await MainActor.run { try TestStore.reset(StormRisk.self, in: container) }

        let repo = StormRiskRepo(modelContainer: container)
        let asOf = makeUTCDate(2026, 3, 1, 12, 0)
        let valid = makeUTCDate(2026, 3, 1, 8, 0)
        let expires = makeUTCDate(2026, 3, 1, 22, 0)
        let olderIssue = makeUTCDate(2026, 3, 1, 8, 0)
        let newerIssue = makeUTCDate(2026, 3, 1, 11, 30)
        let slightIssue = makeUTCDate(2026, 3, 1, 10, 0)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                StormRisk(
                    riskLevel: .enhanced,
                    issued: olderIssue,
                    expires: expires,
                    valid: valid,
                    stroke: "#111111",
                    fill: "#222222",
                    polygons: []
                )
            )
            context.insert(
                StormRisk(
                    riskLevel: .enhanced,
                    issued: newerIssue,
                    expires: expires,
                    valid: valid,
                    stroke: "#333333",
                    fill: "#444444",
                    polygons: []
                )
            )
            context.insert(
                StormRisk(
                    riskLevel: .slight,
                    issued: slightIssue,
                    expires: expires,
                    valid: valid,
                    stroke: "#555555",
                    fill: "#666666",
                    polygons: []
                )
            )
            try context.save()
        }

        let results = try await repo.getLatestMapData(asOf: asOf)
        #expect(results.count == 1)

        let byLevel = Dictionary(uniqueKeysWithValues: results.map { ($0.riskLevel, $0) })
        #expect(byLevel[.enhanced]?.issued == newerIssue)
        #expect(byLevel[.slight] == nil)
    }

    @Test("Categorical map includes products exactly at the expiry boundary")
    func stormMapIncludesProductsAtExpiryBoundary() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [StormRisk.self]) }
        try await MainActor.run { try TestStore.reset(StormRisk.self, in: container) }

        let repo = StormRiskRepo(modelContainer: container)
        let asOf = makeUTCDate(2026, 3, 1, 22, 0)
        let valid = makeUTCDate(2026, 3, 1, 8, 0)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                StormRisk(
                    riskLevel: .enhanced,
                    issued: makeUTCDate(2026, 3, 1, 11, 30),
                    expires: asOf,
                    valid: valid,
                    stroke: "#333333",
                    fill: "#444444",
                    polygons: []
                )
            )
            try context.save()
        }

        let results = try await repo.getLatestMapData(asOf: asOf)
        #expect(results.map(\.riskLevel) == [.enhanced])
    }

    @Test("Categorical active lookup ignores stale polygons from older valid issuances")
    func stormActiveIgnoresStalePolygonsFromOlderValidIssuances() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [StormRisk.self]) }
        try await MainActor.run { try TestStore.reset(StormRisk.self, in: container) }

        let repo = StormRiskRepo(modelContainer: container)
        let asOf = makeUTCDate(2026, 3, 1, 17, 0)
        let valid = makeUTCDate(2026, 3, 1, 12, 0)
        let expires = makeUTCDate(2026, 3, 1, 20, 0)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                StormRisk(
                    riskLevel: .marginal,
                    issued: makeUTCDate(2026, 3, 1, 12, 0),
                    expires: expires,
                    valid: valid,
                    stroke: "#111111",
                    fill: "#222222",
                    polygons: [makePolygon(squareAtLonLat: (-100.0, 40.0), size: 1.0)]
                )
            )
            context.insert(
                StormRisk(
                    riskLevel: .marginal,
                    issued: makeUTCDate(2026, 3, 1, 16, 30),
                    expires: expires,
                    valid: valid,
                    stroke: "#333333",
                    fill: "#444444",
                    polygons: [makePolygon(squareAtLonLat: (-98.0, 40.0), size: 1.0)]
                )
            )
            try context.save()
        }

        let point = CLLocationCoordinate2D(latitude: 40.5, longitude: -99.5)
        let active = try await repo.active(asOf: asOf, for: point)
        #expect(active == .allClear)
    }

    @MainActor
    @Test("Categorical active lookup matches points inside an exterior and outside its holes")
    func stormActiveMatchesExteriorOutsideHoles() async throws {
        let container = try TestStore.container(for: [StormRisk.self])
        let repo = StormRiskRepo(modelContainer: container)
        let polygon = GeoPolygonEntity(
            title: "Slight",
            coordinates: squareRing(longitude: -100, latitude: 40, size: 10),
            interiorCoordinates: [squareRing(longitude: -96, latitude: 44, size: 2)]
        )

        try insertActiveStormRisks([makeActiveStormRisk(level: .slight, polygons: [polygon])], in: container)

        let active = try await repo.active(
            asOf: activeStormRiskAsOf,
            for: CLLocationCoordinate2D(latitude: 42, longitude: -98)
        )
        #expect(active == .slight)
    }

    @MainActor
    @Test("Categorical active lookup excludes every interior hole and exterior misses")
    func stormActiveExcludesInteriorHolesAndExteriorMisses() async throws {
        let container = try TestStore.container(for: [StormRisk.self])
        let repo = StormRiskRepo(modelContainer: container)
        let polygon = GeoPolygonEntity(
            title: "Enhanced",
            coordinates: squareRing(longitude: -100, latitude: 40, size: 10),
            interiorCoordinates: [
                squareRing(longitude: -98, latitude: 42, size: 2),
                squareRing(longitude: -94, latitude: 46, size: 2)
            ]
        )

        try insertActiveStormRisks([makeActiveStormRisk(level: .enhanced, polygons: [polygon])], in: container)

        let firstHole = try await repo.active(
            asOf: activeStormRiskAsOf,
            for: CLLocationCoordinate2D(latitude: 43, longitude: -97)
        )
        let secondHole = try await repo.active(
            asOf: activeStormRiskAsOf,
            for: CLLocationCoordinate2D(latitude: 47, longitude: -93)
        )
        let exteriorMiss = try await repo.active(
            asOf: activeStormRiskAsOf,
            for: CLLocationCoordinate2D(latitude: 52, longitude: -98)
        )

        #expect(firstHole == .allClear)
        #expect(secondHole == .allClear)
        #expect(exteriorMiss == .allClear)
    }

    @MainActor
    @Test("Categorical active lookup continues after a higher-risk hole")
    func stormActiveFallsBackToLowerRiskOutsideHigherRiskHole() async throws {
        let container = try TestStore.container(for: [StormRisk.self])
        let repo = StormRiskRepo(modelContainer: container)
        let higherRisk = GeoPolygonEntity(
            title: "Enhanced",
            coordinates: squareRing(longitude: -100, latitude: 40, size: 10),
            interiorCoordinates: [squareRing(longitude: -97, latitude: 43, size: 2)]
        )
        let lowerRisk = GeoPolygonEntity(
            title: "Slight",
            coordinates: squareRing(longitude: -98, latitude: 42, size: 4)
        )

        try insertActiveStormRisks(
            [
                makeActiveStormRisk(level: .enhanced, polygons: [higherRisk]),
                makeActiveStormRisk(level: .slight, polygons: [lowerRisk])
            ],
            in: container
        )

        let active = try await repo.active(
            asOf: activeStormRiskAsOf,
            for: CLLocationCoordinate2D(latitude: 44, longitude: -96)
        )
        #expect(active == .slight)
    }

    @MainActor
    @Test("Categorical active lookup preserves single-ring polygon behavior")
    func stormActiveMatchesSingleRingPolygon() async throws {
        let container = try TestStore.container(for: [StormRisk.self])
        let repo = StormRiskRepo(modelContainer: container)
        let polygon = GeoPolygonEntity(
            title: "Marginal",
            coordinates: squareRing(longitude: -100, latitude: 40, size: 10)
        )

        try insertActiveStormRisks([makeActiveStormRisk(level: .marginal, polygons: [polygon])], in: container)

        let active = try await repo.active(
            asOf: activeStormRiskAsOf,
            for: CLLocationCoordinate2D(latitude: 45, longitude: -95)
        )
        #expect(active == .marginal)
    }

    @Test("Severe map returns newest issuance per type and probability bucket")
    func severeMapReturnsNewestIssuancePerBucket() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }

        let repo = SevereRiskRepo(modelContainer: container)
        let asOf = makeUTCDate(2026, 3, 1, 12, 0)
        let valid = makeUTCDate(2026, 3, 1, 7, 0)
        let expires = makeUTCDate(2026, 3, 1, 23, 0)
        let olderIssue = makeUTCDate(2026, 3, 1, 8, 0)
        let newerIssue = makeUTCDate(2026, 3, 1, 11, 0)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                SevereRisk(
                    type: .tornado,
                    probability: .percent(0.15),
                    threatLevel: .tornado(probability: 0.15),
                    issued: olderIssue,
                    valid: valid,
                    expires: expires,
                    dn: 15,
                    stroke: "#AA0000",
                    fill: "#110000",
                    polygons: [],
                    label: "0.15"
                )
            )
            context.insert(
                SevereRisk(
                    type: .tornado,
                    probability: .percent(0.15),
                    threatLevel: .tornado(probability: 0.15),
                    issued: newerIssue,
                    valid: valid,
                    expires: expires,
                    dn: 15,
                    stroke: "#BB0000",
                    fill: "#220000",
                    polygons: [],
                    label: "0.15"
                )
            )
            context.insert(
                SevereRisk(
                    type: .tornado,
                    probability: .significant(15),
                    threatLevel: .tornado(probability: 0.15),
                    issued: newerIssue,
                    valid: valid,
                    expires: expires,
                    dn: 15,
                    stroke: "#CC0000",
                    fill: "#330000",
                    polygons: [],
                    label: "SIGN"
                )
            )
            try context.save()
        }

        let results = try await repo.getSevereRiskShapes(asOf: asOf)
        #expect(results.count == 2)

        let percent15 = results.first { $0.type == .tornado && $0.probabilities == .percent(0.15) }
        #expect(percent15?.fill == "#220000")
        #expect(results.contains { $0.fill == "#110000" } == false)

        let significant15 = results.first { $0.type == .tornado && $0.probabilities == .significant(15) }
        #expect(significant15?.fill == "#330000")
    }

    @Test("Severe map includes products exactly at the expiry boundary")
    func severeMapIncludesProductsAtExpiryBoundary() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }

        let repo = SevereRiskRepo(modelContainer: container)
        let asOf = makeUTCDate(2026, 3, 1, 23, 0)
        let valid = makeUTCDate(2026, 3, 1, 7, 0)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                SevereRisk(
                    type: .tornado,
                    probability: .percent(0.15),
                    threatLevel: .tornado(probability: 0.15),
                    issued: makeUTCDate(2026, 3, 1, 11, 0),
                    valid: valid,
                    expires: asOf,
                    dn: 15,
                    stroke: "#BB0000",
                    fill: "#220000",
                    polygons: [],
                    label: "0.15"
                )
            )
            try context.save()
        }

        let results = try await repo.getSevereRiskShapes(asOf: asOf)
        #expect(results.map(\.type) == [.tornado])
    }

    @Test("Severe map keeps separate CIG intensity buckets")
    func severeMapKeepsSeparateCigBuckets() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }

        let repo = SevereRiskRepo(modelContainer: container)
        let asOf = makeUTCDate(2026, 3, 1, 12, 0)
        let valid = makeUTCDate(2026, 3, 1, 7, 0)
        let expires = makeUTCDate(2026, 3, 1, 23, 0)
        let issue = makeUTCDate(2026, 3, 1, 11, 0)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                SevereRisk(
                    type: .tornado,
                    probability: .percent(0),
                    threatLevel: .tornado(probability: 0),
                    issued: issue,
                    valid: valid,
                    expires: expires,
                    dn: 1,
                    stroke: "#AA0000",
                    fill: "#110000",
                    polygons: [],
                    label: "CIG1"
                )
            )
            context.insert(
                SevereRisk(
                    type: .tornado,
                    probability: .percent(0),
                    threatLevel: .tornado(probability: 0),
                    issued: issue,
                    valid: valid,
                    expires: expires,
                    dn: 2,
                    stroke: "#BB0000",
                    fill: "#220000",
                    polygons: [],
                    label: "CIG2"
                )
            )
            try context.save()
        }

        let results = try await repo.getSevereRiskShapes(asOf: asOf)
        #expect(results.count == 2)
        #expect(results.contains { $0.label == "CIG1" && $0.intensityLevel == 1 })
        #expect(results.contains { $0.label == "CIG2" && $0.intensityLevel == 2 })
    }

    @Test("Mesoscale map includes discussions exactly at the valid-end boundary")
    func mesoMapIncludesProductsAtValidEndBoundary() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [MD.self]) }
        try await MainActor.run { try TestStore.reset(MD.self, in: container) }

        let repo = MesoRepo(modelContainer: container)
        let asOf = makeUTCDate(2026, 3, 1, 18, 0)
        let issued = makeUTCDate(2026, 3, 1, 16, 0)
        let validStart = makeUTCDate(2026, 3, 1, 15, 0)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                MD(
                    number: 1895,
                    title: "SPC MD 1895",
                    link: URL(string: "https://example.com/md1895.html")!,
                    issued: issued,
                    validStart: validStart,
                    validEnd: asOf,
                    areasAffected: "Wisconsin",
                    summary: "Boundary inclusion check",
                    watchProbability: "40",
                    threats: nil,
                    coordinates: [],
                    alertType: .mesoscale
                )
            )
            try context.save()
        }

        let results = try await repo.getLatestMapData(asOf: asOf)
        #expect(results.map(\.number) == [1895])
    }

    @Test("Severe risk key differentiates CIG label with same DN and issuance")
    func severeRiskKeyDifferentiatesCigLabel() {
        let issued = makeUTCDate(2026, 3, 1, 11, 0)
        let valid = makeUTCDate(2026, 3, 1, 7, 0)
        let expires = makeUTCDate(2026, 3, 1, 23, 0)

        let base = SevereRisk(
            type: .tornado,
            probability: .percent(0),
            threatLevel: .tornado(probability: 0),
            issued: issued,
            valid: valid,
            expires: expires,
            dn: 1,
            stroke: "#AA0000",
            fill: "#110000",
            polygons: [],
            label: "0.00"
        )

        let cig = SevereRisk(
            type: .tornado,
            probability: .percent(0),
            threatLevel: .tornado(probability: 0),
            issued: issued,
            valid: valid,
            expires: expires,
            dn: 1,
            stroke: "#AA0000",
            fill: "#110000",
            polygons: [],
            label: "CIG1"
        )

        #expect(base.key != cig.key)
        #expect(cig.key.hasSuffix("_CIG1"))
    }
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

private func makePolygon(squareAtLonLat origin: (Double, Double), size: Double) -> GeoPolygonEntity {
    let (lon, lat) = origin
    return GeoPolygonEntity(
        title: "Test Polygon",
        coordinates: [
            Coordinate2D(latitude: lat, longitude: lon),
            Coordinate2D(latitude: lat + size, longitude: lon),
            Coordinate2D(latitude: lat + size, longitude: lon + size),
            Coordinate2D(latitude: lat, longitude: lon + size),
            Coordinate2D(latitude: lat, longitude: lon)
        ]
    )
}

private let activeStormRiskAsOf = makeUTCDate(2026, 3, 1, 12, 0)

private func makeActiveStormRisk(level: StormRiskLevel, polygons: [GeoPolygonEntity]) -> StormRisk {
    StormRisk(
        riskLevel: level,
        issued: makeUTCDate(2026, 3, 1, 11, 0),
        expires: makeUTCDate(2026, 3, 1, 20, 0),
        valid: makeUTCDate(2026, 3, 1, 8, 0),
        stroke: nil,
        fill: nil,
        polygons: polygons
    )
}

@MainActor
private func insertActiveStormRisks(_ risks: [StormRisk], in container: ModelContainer) throws {
    let context = ModelContext(container)
    for risk in risks {
        context.insert(risk)
    }
    try context.save()
}

private func squareRing(longitude: Double, latitude: Double, size: Double) -> [Coordinate2D] {
    [
        Coordinate2D(latitude: latitude, longitude: longitude),
        Coordinate2D(latitude: latitude + size, longitude: longitude),
        Coordinate2D(latitude: latitude + size, longitude: longitude + size),
        Coordinate2D(latitude: latitude, longitude: longitude + size),
        Coordinate2D(latitude: latitude, longitude: longitude)
    ]
}
