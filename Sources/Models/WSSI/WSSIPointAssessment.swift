import Foundation

/// A single product and source day, evaluated independently of every other dataset.
struct WSSIPointAssessment: Sendable {
    enum Impact: Sendable, Equatable {
        case disabled
        case unavailable
        case invalidPoint
        case match(WSSISeverity)
        case noMatchUnknownCoverage
        case confirmedNoImpact
    }

    let product: WSSIProduct
    let day: Int
    let point: Coordinate2D
    let revision: WSSIAcceptedRevision?
    let validity: WSSIValidity
    let sourceStatus: WSSISourceStatus
    let pollHealth: WSSIPollHealth
    let impact: Impact

    /// Coverage must be verified independently for this dataset, revision and point.
    /// Future periods retain their point impact; consumers use validity to distinguish them from current periods.
    static func evaluate(
        entry: WSSIManifestEntry,
        point: Coordinate2D,
        at time: Date,
        enabled: Bool = true,
        verifiedCoverage: Bool = false,
        geometryData: () -> Data?
    ) throws -> Self {
        let validity: WSSIValidity
        if let accepted = entry.accepted {
            if time < accepted.validFrom {
                validity = .notYetValid
            } else {
                validity = time < accepted.validTo ? .valid : .expired
            }
        } else {
            validity = .neverAccepted
        }

        let impact: Impact
        if !enabled {
            impact = .disabled
        } else if !(-90...90).contains(point.latitude) || !(-180...180).contains(point.longitude) {
            impact = .invalidPoint
        } else if validity == .expired || validity == .neverAccepted {
            impact = .unavailable
        } else if let data = geometryData() {
            let geometry = try WSSISourceDecoder.geometry(from: data, for: entry)
            let strongest = WSSISeverity.allCases.reversed().first { severity in
                geometry.features.contains { feature in
                    feature.properties.severity == severity &&
                        feature.geometry.coordinates.contains { contains(point, polygon: $0) }
                }
            }
            if let strongest {
                impact = .match(strongest)
            } else {
                impact = verifiedCoverage ? .confirmedNoImpact : .noMatchUnknownCoverage
            }
        } else {
            impact = .unavailable
        }

        return Self(product: entry.product, day: entry.day, point: point, revision: entry.accepted,
                    validity: validity, sourceStatus: entry.sourceStatus, pollHealth: entry.pollHealth, impact: impact)
    }

    private static func contains(_ point: Coordinate2D, polygon: WSSIPolygon) -> Bool {
        let exterior = polygon.rings[0]
        var minLat = exterior[0].latitude, maxLat = minLat
        var minLon = exterior[0].longitude, maxLon = minLon
        for vertex in exterior.dropFirst() {
            minLat = min(minLat, vertex.latitude)
            maxLat = max(maxLat, vertex.latitude)
            minLon = min(minLon, vertex.longitude)
            maxLon = max(maxLon, vertex.longitude)
        }

        guard (minLat...maxLat).contains(point.latitude), (minLon...maxLon).contains(point.longitude),
              contains(point, ring: exterior) else { return false }
        return !polygon.rings.dropFirst().contains { contains(point, ring: $0) }
    }

    // GeoJSON rings are closed. Include exterior edges and exclude hole edges.
    private static func contains(_ point: Coordinate2D, ring: [WSSIPosition]) -> Bool {
        var inside = false
        for (a, b) in zip(ring, ring.dropFirst()) {
            let dx = b.longitude - a.longitude
            let dy = b.latitude - a.latitude
            let cross = (point.longitude - a.longitude) * dy - (point.latitude - a.latitude) * dx
            if cross == 0,
               (min(a.longitude, b.longitude)...max(a.longitude, b.longitude)).contains(point.longitude),
               (min(a.latitude, b.latitude)...max(a.latitude, b.latitude)).contains(point.latitude) {
                return true
            }
            if (a.latitude > point.latitude) != (b.latitude > point.latitude),
               point.longitude < dx * (point.latitude - a.latitude) / dy + a.longitude {
                inside.toggle()
            }
        }
        return inside
    }
}
