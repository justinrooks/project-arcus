//
//  MapPolygonMapper.swift
//  SkyAware
//
//  Created by Justin Rooks on 2/15/26.
//

import MapKit

struct MapPolygonMapper {
    func polygons(
        for layer: MapLayer,
        stormRisk: [StormRiskDTO],
        severeRisks: [SevereRiskShapeDTO],
        mesos: [MdDTO],
        fires: [FireRiskDTO]
    ) -> MKMultiPolygon {
        switch layer {
        case .categorical:
            // Draw lower categories first so higher severity sits on top.
            let source = stormRisk.sorted { $0.riskLevel < $1.riskLevel }
            let polygons = source.flatMap { risk -> [MKPolygon] in
                risk.polygons.map { polygon in
                    let coordinates = polygon.ringCoordinates
                    let mkPolygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
                    mkPolygon.title = polygon.title
                    mkPolygon.subtitle = StormRiskPolygonStyleMetadata(
                        fillHex: risk.fill,
                        strokeHex: risk.stroke
                    ).encoded
                    return mkPolygon
                }
            }
            return MKMultiPolygon(polygons)

        case .tornado:
            return MKMultiPolygon(
                severePolygons(
                    from: severeRisks,
                    type: .tornado
                )
            )

        case .hail:
            return MKMultiPolygon(
                severePolygons(
                    from: severeRisks,
                    type: .hail
                )
            )

        case .wind:
            return MKMultiPolygon(
                severePolygons(
                    from: severeRisks,
                    type: .wind
                )
            )

        case .meso:
            let polygons = makeMKPolygons(
                from: mesos,
                coordinates: { $0.coordinates.map { $0.location } },
                title: { _ in layer.key }
            )
            return MKMultiPolygon(polygons)
            
        case .fire:
            let polygons = fires.flatMap { fire -> [MKPolygon] in
                fire.polygons.map { polygon in
                    let coordinates = polygon.ringCoordinates
                    let mkPolygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
                    mkPolygon.title = polygon.title
                    mkPolygon.subtitle = StormRiskPolygonStyleMetadata(
                        fillHex: fire.fill,
                        strokeHex: fire.stroke
                    ).encoded
                    return mkPolygon
                }
            }
            return MKMultiPolygon(polygons)
        }
    }

    private func makeMKPolygons<Element>(
        from source: [Element],
        coordinates: (Element) -> [CLLocationCoordinate2D],
        title: (Element) -> String?
    ) -> [MKPolygon] {
        source.map { element in
            let coords = coordinates(element)
            let mkPolygon = MKPolygon(coordinates: coords, count: coords.count)
            mkPolygon.title = title(element)
            return mkPolygon
        }
    }

    private func severePolygons(
        from severeRisks: [SevereRiskShapeDTO],
        type: ThreatType
    ) -> [MKPolygon] {
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

        return source.flatMap { severe -> [MKPolygon] in
            severe.polygons.map { polygon in
                let coordinates = polygon.ringCoordinates
                let mkPolygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
                mkPolygon.title = polygon.title
                mkPolygon.subtitle = StormRiskPolygonStyleMetadata(
                    fillHex: severe.fill,
                    strokeHex: severe.stroke
                ).encoded
                return mkPolygon
            }
        }
    }

    private func isSignificant(_ probability: ThreatProbability) -> Bool {
        if case .significant = probability {
            return true
        }
        return false
    }
}
