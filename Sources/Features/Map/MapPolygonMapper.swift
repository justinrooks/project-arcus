//
//  MapPolygonMapper.swift
//  SkyAware
//
//  Created by Justin Rooks on 2/15/26.
//

import MapKit

struct MapPolygonEntry: Sendable {
    let key: String
    let title: String?
    let subtitle: String?
    let coordinates: [Coordinate2D]

    var polygon: MKPolygon {
        let ringCoordinates = coordinates.map(\.location)
        let polygon = MKPolygon(coordinates: ringCoordinates, count: ringCoordinates.count)
        polygon.title = title
        polygon.subtitle = subtitle
        return polygon
    }
}

struct KeyedMapPolygons: Sendable {
    let keyedPolygons: [MapPolygonEntry]

    var polygons: [MKPolygon] {
        keyedPolygons.map(\.polygon)
    }

    var multiPolygon: MKMultiPolygon {
        MKMultiPolygon(polygons)
    }

    init(entries: [MapPolygonEntry]) {
        self.keyedPolygons = entries
    }
}

struct MapPolygonMapper: Sendable {
    func polygons(
        for layer: MapLayer,
        stormRisk: [StormRiskDTO],
        severeRisks: [SevereRiskShapeDTO],
        mesos: [MdDTO],
        fires: [FireRiskDTO]
    ) -> KeyedMapPolygons {
        switch layer {
        case .categorical:
            // Draw lower categories first so higher severity sits on top.
            let source = stormRisk.sorted { $0.riskLevel < $1.riskLevel }
            let entries = source.flatMap { risk -> [MapPolygonEntry] in
                risk.polygons.map { polygon in
                    let subtitle = StormRiskPolygonStyleMetadata(
                        fillHex: risk.fill,
                        strokeHex: risk.stroke
                    ).encoded
                    return MapPolygonEntry(
                        key: "cat|\(risk.riskLevel.rawValue)|\(Int(risk.issued.timeIntervalSince1970))|\(polygonFingerprint(for: polygon))",
                        title: polygon.title,
                        subtitle: subtitle,
                        coordinates: polygon.coordinates
                    )
                }
            }
            return KeyedMapPolygons(entries: entries)

        case .tornado:
            return KeyedMapPolygons(
                entries: severePolygons(
                    from: severeRisks,
                    type: .tornado
                )
            )

        case .hail:
            return KeyedMapPolygons(
                entries: severePolygons(
                    from: severeRisks,
                    type: .hail
                )
            )

        case .wind:
            return KeyedMapPolygons(
                entries: severePolygons(
                    from: severeRisks,
                    type: .wind
                )
            )

        case .meso:
            let entries = mesos.map { meso in
                return MapPolygonEntry(
                    key: "meso|\(meso.number)|\(polygonFingerprint(title: meso.title, coordinates: meso.coordinates))",
                    title: layer.key,
                    subtitle: nil,
                    coordinates: meso.coordinates
                )
            }
            return KeyedMapPolygons(entries: entries)
            
        case .fire:
            let entries = fires.flatMap { fire -> [MapPolygonEntry] in
                fire.polygons.map { polygon in
                    let subtitle = StormRiskPolygonStyleMetadata(
                        fillHex: fire.fill,
                        strokeHex: fire.stroke
                    ).encoded
                    return MapPolygonEntry(
                        key: "fire|\(fire.riskLevel)|\(Int(fire.issued.timeIntervalSince1970))|\(polygonFingerprint(for: polygon))",
                        title: polygon.title,
                        subtitle: subtitle,
                        coordinates: polygon.coordinates
                    )
                }
            }
            return KeyedMapPolygons(entries: entries)
        }
    }

    private func severeProbabilityKey(_ probability: ThreatProbability) -> String {
        switch probability {
        case .percent(let value):
            return "p\(Int((value * 100).rounded()))"
        case .significant(let value):
            return "sig\(value)"
        }
    }

    private func sanitizedKeyPart(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "|", with: "_")
    }

    private func severePolygons(
        from severeRisks: [SevereRiskShapeDTO],
        type: ThreatType
    ) -> [MapPolygonEntry] {
        // Draw lower probabilities first so higher severity sits on top.
        // When probabilities match (same DN), draw SIGN last (above non-significant).
        let source = severeRisks
            .filter { $0.type == type }
            .sorted {
                let lhsProbability = $0.probabilities.intValue
                let rhsProbability = $1.probabilities.intValue
                if lhsProbability != rhsProbability {
                    return lhsProbability < rhsProbability
                }

                let lhsSignificanceRank = isSignificant($0.probabilities) ? 1 : 0
                let rhsSignificanceRank = isSignificant($1.probabilities) ? 1 : 0
                if lhsSignificanceRank != rhsSignificanceRank {
                    return lhsSignificanceRank < rhsSignificanceRank
                }

                return $0.title < $1.title
            }

        return source.flatMap { severe -> [MapPolygonEntry] in
            let probabilityKey = severeProbabilityKey(severe.probabilities)
            let labelKey = sanitizedKeyPart(severe.label)
            return severe.polygons.map { polygon in
                let subtitle = StormRiskPolygonStyleMetadata(
                    fillHex: severe.fill,
                    strokeHex: severe.stroke,
                    cigLevel: severe.intensityLevel
                ).encoded
                return MapPolygonEntry(
                    key: "sev|\(type.rawValue)|\(probabilityKey)|\(labelKey)|\(polygonFingerprint(for: polygon))",
                    title: polygon.title,
                    subtitle: subtitle,
                    coordinates: polygon.coordinates
                )
            }
        }
    }

    private func isSignificant(_ probability: ThreatProbability) -> Bool {
        if case .significant = probability {
            return true
        }
        return false
    }

    private func polygonFingerprint(for polygon: GeoPolygonEntity) -> String {
        polygonFingerprint(title: polygon.title, coordinates: polygon.coordinates)
    }

    private func polygonFingerprint(title: String, coordinates: [Coordinate2D]) -> String {
        var hasher = StableMapHasher()
        hasher.combine(title)
        hasher.combine(coordinates.count)

        for coordinate in coordinates {
            hasher.combine(coordinate)
        }

        return hasher.hexString
    }
}
