import Foundation
import SwiftData
import Testing
@testable import SkyAware

@MainActor
struct WSSIPersistenceTests {
    @Test("V6 migrates in place and WSSI layers survive reopen", arguments: [false, true])
    func diskRoundTrip(migrate: Bool) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("test.store")
        if migrate {
            let schema = Schema(versionedSchema: SkyAwarePersistenceSchemaV6.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(container)
            context.insert(ConvectiveOutlook(title: "Preserved outlook", link: URL(fileURLWithPath: "/outlook"),
                                            published: .distantPast, fullText: "Text", summary: "Summary", day: 1,
                                            riskLevel: "SLGT", issued: .distantPast, validUntil: .distantFuture))
            context.insert(SPCHazardForecast(
                snapshot: SPCHazardForecastSnapshot(day: .day2, issued: Date(timeIntervalSince1970: 100),
                                                    valid: Date(timeIntervalSince1970: 200),
                                                    expires: Date(timeIntervalSince1970: 300), shapes: []),
                tornado: Data("tornado".utf8), hail: Data("hail".utf8), wind: Data("wind".utf8),
                now: Date(timeIntervalSince1970: 150)))
            try context.save()
        }
        let schema = Schema(versionedSchema: SkyAwarePersistenceSchema.self)
        let configuration = ModelConfiguration(schema: schema, url: url)
        let issued = Date(timeIntervalSince1970: 100)
        let start = Date(timeIntervalSince1970: 200)
        let end = Date(timeIntervalSince1970: 300)
        let scope = try WSSIScope(south: 0, west: 0, north: 10, east: 10)
        let ring = [Coordinate2D(latitude: 1, longitude: 1), Coordinate2D(latitude: 1, longitude: 9),
                    Coordinate2D(latitude: 9, longitude: 9), Coordinate2D(latitude: 9, longitude: 1),
                    Coordinate2D(latitude: 1, longitude: 1)]
        let hole = [Coordinate2D(latitude: 2, longitude: 2), Coordinate2D(latitude: 2, longitude: 3),
                    Coordinate2D(latitude: 3, longitude: 3), Coordinate2D(latitude: 3, longitude: 2),
                    Coordinate2D(latitude: 2, longitude: 2)]
        do {
            let container = try ModelContainer(for: schema, migrationPlan: SkyAwarePersistenceMigrationPlan.self,
                                               configurations: configuration)
            let context = ModelContext(container)
            for product in WSSIProduct.allCases {
                for period in WSSIPeriod.allCases {
                    let features = product == .overall ? [] : WSSIImpact.allCases.map {
                        WSSIFeature(product: product, period: period, impact: $0, issuedAt: issued,
                                    validFrom: start, validTo: end, polygons: [WSSIPolygon(rings: [ring, hole])])
                    }
                    let layer = try WSSIAssessmentLayer(product: product, period: period, issuedAt: issued,
                                                        validFrom: start, validTo: end, scope: scope, features: features)
                    context.insert(try WSSIForecastLayer(layer: layer, acceptedAt: start, provenance: "fixture-publication"))
                }
            }
            try context.save()
        }
        let reopened = try ModelContainer(for: schema, migrationPlan: SkyAwarePersistenceMigrationPlan.self,
                                          configurations: configuration)
        let context = ModelContext(reopened)
        let rows = try context.fetch(FetchDescriptor<WSSIForecastLayer>())
        #expect(rows.count == 20)
        for row in rows {
            #expect(row.acceptedAt == start)
            #expect(row.provenance == "fixture-publication")
            let layer = try row.assessmentLayer()
            #expect(layer.issuedAt == issued && layer.validFrom == start && layer.validTo == end)
            #expect(layer.scope == scope)
            #expect(layer.features.map(\.impact) == (layer.product == .overall ? [] : WSSIImpact.allCases))
            #expect(layer.features.allSatisfy { $0.polygons.first?.rings == [ring, hole] })
        }
        let assessment = try WSSIAssessment.evaluate(layers: rows.map { try $0.assessmentLayer() },
                                                    at: Coordinate2D(latitude: 5, longitude: 5),
                                                    time: Date(timeIntervalSince1970: 250))
        #expect(assessment.entries.allSatisfy { $0.result == ($0.product == .overall ? .noImpact : .impact(.extreme)) })
        if migrate {
            let hazard = try #require(context.fetch(FetchDescriptor<SPCHazardForecast>()).first)
            #expect(hazard.issued == issued && hazard.valid == start && hazard.expires == end)
            #expect(hazard.acceptedAt == Date(timeIntervalSince1970: 150))
            #expect(hazard.tornado == Data("tornado".utf8))
            #expect(hazard.hail == Data("hail".utf8) && hazard.wind == Data("wind".utf8))
            #expect(try context.fetch(FetchDescriptor<ConvectiveOutlook>()).first?.title == "Preserved outlook")
        }
    }
}
