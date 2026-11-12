import Foundation
import SwiftData

/// One accepted layer. Absence means not loaded; an empty payload means accepted no-impact coverage.
/// WSSI-06 owns acceptance/replacement and pruning: keep at most one layer per product/period,
/// deleting superseded layers on acceptance and expired layers after their validTo.
@Model
final class WSSIForecastLayer {
    var productIdentifier: String
    var periodIdentifier: String
    var issuedAt: Date
    var validFrom: Date
    var validTo: Date
    var south: Double
    var west: Double
    var north: Double
    var east: Double
    var acceptedAt: Date
    /// Evidence identifying the source publication and coverage accepted by the caller.
    var provenance: String
    private var featuresData: Data

    init(layer: WSSIAssessmentLayer, acceptedAt: Date, provenance: String) throws {
        productIdentifier = layer.product.rawValue
        periodIdentifier = layer.period.rawValue
        issuedAt = layer.issuedAt
        validFrom = layer.validFrom
        validTo = layer.validTo
        south = layer.scope.south
        west = layer.scope.west
        north = layer.scope.north
        east = layer.scope.east
        self.acceptedAt = acceptedAt
        self.provenance = provenance
        featuresData = try JSONEncoder().encode(layer.features.map(StoredFeature.init))
    }

    func assessmentLayer() throws -> WSSIAssessmentLayer {
        guard let product = WSSIProduct(rawValue: productIdentifier),
              let period = WSSIPeriod(rawValue: periodIdentifier) else {
            throw WSSIAssessmentError.inconsistentLayer
        }
        let features = try JSONDecoder().decode([StoredFeature].self, from: featuresData).map { stored in
            guard let impact = WSSIImpact(rawValue: stored.impact) else {
                throw WSSIAssessmentError.inconsistentLayer
            }
            return WSSIFeature(product: product, period: period, impact: impact, issuedAt: issuedAt,
                               validFrom: validFrom, validTo: validTo,
                               polygons: stored.polygons.map { WSSIPolygon(rings: $0) })
        }
        return try WSSIAssessmentLayer(product: product, period: period, issuedAt: issuedAt,
                                       validFrom: validFrom, validTo: validTo,
                                       scope: WSSIScope(south: south, west: west, north: north, east: east),
                                       features: features)
    }
}

/// Explicit primitive Data encoding keeps custom domain values out of the SwiftData attribute schema.
private struct StoredFeature: Codable {
    let impact: String
    let polygons: [[[Coordinate2D]]]

    init(_ feature: WSSIFeature) {
        impact = feature.impact.rawValue
        polygons = feature.polygons.map(\.rings)
    }
}
