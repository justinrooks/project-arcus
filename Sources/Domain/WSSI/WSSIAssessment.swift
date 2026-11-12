import Foundation

/// Validated input for one product/period. Creation does not establish source publication coherence.
struct WSSIAssessmentLayer: Sendable {
    let product: WSSIProduct
    let period: WSSIPeriod
    let issuedAt: Date
    let validFrom: Date
    let validTo: Date
    let scope: WSSIScope
    let features: [WSSIFeature]

    init(product: WSSIProduct, period: WSSIPeriod, issuedAt: Date, validFrom: Date,
         validTo: Date, scope: WSSIScope, features: [WSSIFeature]) throws {
        guard issuedAt.timeIntervalSince1970.isFinite,
              validFrom.timeIntervalSince1970.isFinite, validTo.timeIntervalSince1970.isFinite,
              validFrom < validTo, issuedAt < validTo,
              features.allSatisfy({
                  $0.product == product && $0.period == period && $0.issuedAt == issuedAt &&
                  $0.validFrom == validFrom && $0.validTo == validTo
              }) else { throw WSSIAssessmentError.inconsistentLayer }
        self.product = product
        self.period = period
        self.issuedAt = issuedAt
        self.validFrom = validFrom
        self.validTo = validTo
        self.scope = scope
        self.features = features
    }
}

enum WSSIAssessmentError: Error { case inconsistentLayer, duplicateLayer }

enum WSSIImpactAssessment: Sendable, Equatable {
    case notLoaded
    case outsideCoverage
    case notYetValid
    case expired
    case noImpact
    case impact(WSSIImpact)
}

struct WSSIAssessment: Sendable {
    struct Entry: Sendable {
        let product: WSSIProduct
        let period: WSSIPeriod
        let issuedAt: Date?
        let validFrom: Date?
        let validTo: Date?
        let result: WSSIImpactAssessment
    }

    let entries: [Entry]

    /// Supply only layers whose completeness, coverage and publication identity were accepted by the caller.
    /// Nil/missing layers remain notLoaded; retrieval success alone is insufficient for this input.
    static func evaluate(layers: [WSSIAssessmentLayer], at point: Coordinate2D,
                         time: Date) throws -> Self {
        for product in WSSIProduct.allCases {
            for period in WSSIPeriod.allCases {
                guard layers.filter({ $0.product == product && $0.period == period }).count <= 1 else {
                    throw WSSIAssessmentError.duplicateLayer
                }
            }
        }
        return Self(entries: WSSIPeriod.allCases.flatMap { period in
            WSSIProduct.allCases.map { product in
                let layer = layers.first { $0.product == product && $0.period == period }
                return Entry(product: product, period: period, issuedAt: layer?.issuedAt,
                             validFrom: layer?.validFrom, validTo: layer?.validTo,
                             result: layer.map { assess($0, at: point, time: time) } ?? .notLoaded)
            }
        })
    }

    private static func assess(_ layer: WSSIAssessmentLayer, at point: Coordinate2D,
                               time: Date) -> WSSIImpactAssessment {
        guard point.latitude.isFinite, point.longitude.isFinite,
              (layer.scope.south...layer.scope.north).contains(point.latitude),
              (layer.scope.west...layer.scope.east).contains(point.longitude) else { return .outsideCoverage }
        guard time >= layer.validFrom else { return .notYetValid }
        guard time < layer.validTo else { return .expired }
        let impacts = layer.features.filter { feature in
            feature.polygons.contains { polygon in
                guard let exterior = polygon.rings.first else { return false }
                return MesoGeometry.contains(point.location, inRing: exterior.map(\.location)) &&
                    polygon.rings.dropFirst().allSatisfy {
                        !MesoGeometry.contains(point.location, inRing: $0.map(\.location))
                    }
            }
        }.map(\.impact)
        let severity: [WSSIImpact] = [.winterWeatherArea, .minor, .moderate, .major, .extreme]
        return severity.last(where: impacts.contains).map(WSSIImpactAssessment.impact) ?? .noImpact
    }
}
