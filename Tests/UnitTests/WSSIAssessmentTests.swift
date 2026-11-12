import Foundation
import Testing
@testable import SkyAware

struct WSSIAssessmentTests {
    private let start = Date(timeIntervalSince1970: 1_000)
    private func ring(_ low: Double, _ high: Double) -> [Coordinate2D] {
        [(low, low), (high, low), (high, high), (low, high), (low, low)].map {
            Coordinate2D(latitude: $0.0, longitude: $0.1)
        }
    }
    private func layer(_ product: WSSIProduct = .overall, _ period: WSSIPeriod = .day1,
                       impacts: [WSSIImpact] = [.minor], hole: Bool = false) throws -> WSSIAssessmentLayer {
        try WSSIAssessmentLayer(product: product, period: period, issuedAt: start,
            validFrom: start, validTo: start.addingTimeInterval(21 * 3600),
            scope: WSSIScope(south: -10, west: -10, north: 10, east: 10),
            features: impacts.map {
                WSSIFeature(product: product, period: period, impact: $0, issuedAt: start,
                    validFrom: start, validTo: start.addingTimeInterval(21 * 3600),
                    polygons: [WSSIPolygon(rings: hole ? [ring(0, 8), ring(2, 4)] : [ring(0, 8)])])
            })
    }
    private func result(_ layers: [WSSIAssessmentLayer], _ coordinate: Double = 1,
                        time: Date? = nil) throws -> WSSIImpactAssessment {
        try WSSIAssessment.evaluate(layers: layers,
            at: Coordinate2D(latitude: coordinate, longitude: coordinate), time: time ?? start).entries[0].result
    }

    @Test func allProductsAndPeriodsPreserveSourceOverall() throws {
        let layers = try WSSIPeriod.allCases.flatMap { period in
            try WSSIProduct.allCases.map { product in
                try layer(product, period, impacts: [product == .overall ? .minor : .extreme])
            }
        }
        let entries = try WSSIAssessment.evaluate(layers: layers,
            at: Coordinate2D(latitude: 1, longitude: 1), time: start).entries
        #expect(entries.count == 20)
        for entry in entries {
            #expect(entry.result == .impact(entry.product == .overall ? .minor : .extreme))
            #expect(entry.issuedAt == start)
            #expect(entry.validTo == start.addingTimeInterval(21 * 3600))
        }
    }

    @Test func overlappingSeverityAndLocations() throws {
        let layers = [try layer(impacts: [.extreme, .minor, .major])]
        #expect(try result(layers) == .impact(.extreme))
        #expect(try result(layers, -1) == .noImpact)
        #expect(try result(layers) == .impact(.extreme))
    }

    @Test func holesAndBoundaries() throws {
        let layers = [try layer(hole: true)]
        #expect(try result(layers, 0) == .impact(.minor))
        #expect(try result(layers, 3) == .noImpact)
        #expect(try result(layers, 2) == .noImpact)
        #expect(try result(layers, 8) == .impact(.minor))
    }

    @Test func availabilityAndSourceRollover() throws {
        let layers = [try layer()]
        #expect(try result([]) == .notLoaded)
        #expect(try result(layers, 11) == .outsideCoverage)
        #expect(try result(layers, time: start.addingTimeInterval(-1)) == .notYetValid)
        #expect(try result(layers, time: start.addingTimeInterval(21 * 3600 - 1)) == .impact(.minor))
        #expect(try result(layers, time: start.addingTimeInterval(21 * 3600)) == .expired)
        #expect(try result([layer(impacts: [])]) == .noImpact)
        #expect(throws: WSSIAssessmentError.self) { try result([layer(), layer()]) }
    }

    @Test(arguments: [0.0, 1.0])
    func rejectsEmptyLayerIssuedAtOrAfterValidityEnd(offset: TimeInterval) throws {
        let end = start.addingTimeInterval(21 * 3600)
        let scope = try WSSIScope(south: -10, west: -10, north: 10, east: 10)
        #expect(throws: WSSIAssessmentError.self) {
            try WSSIAssessmentLayer(product: .overall, period: .day1,
                issuedAt: end.addingTimeInterval(offset), validFrom: start, validTo: end,
                scope: scope, features: [])
        }
        let valid = try WSSIAssessmentLayer(product: .overall, period: .day1,
            issuedAt: end.addingTimeInterval(-1), validFrom: start, validTo: end,
            scope: scope, features: [])
        #expect(try result([valid], time: end.addingTimeInterval(-1)) == .noImpact)
    }

}
