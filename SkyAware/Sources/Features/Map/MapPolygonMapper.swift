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
        mesos: [MdDTO]
    ) -> MKMultiPolygon {
        switch layer {
        case .categorical:
            // Draw lower categories first so higher severity sits on top.
            let source = stormRisk
                .sorted { $0.riskLevel < $1.riskLevel }
                .flatMap { $0.polygons }

            let polygons = makeMKPolygons(
                from: source,
                coordinates: { $0.ringCoordinates },
                title: { $0.title }
            )
            return MKMultiPolygon(polygons)

        case .tornado:
            let source = severeRisks
                .filter { $0.type == .tornado }
                .flatMap { $0.polygons }

            let polygons = makeMKPolygons(
                from: source,
                coordinates: { $0.ringCoordinates },
                title: { $0.title }
            )
            return MKMultiPolygon(polygons)

        case .hail:
            let source = severeRisks
                .filter { $0.type == .hail }
                .flatMap { $0.polygons }

            let polygons = makeMKPolygons(
                from: source,
                coordinates: { $0.ringCoordinates },
                title: { $0.title }
            )
            return MKMultiPolygon(polygons)

        case .wind:
            let source = severeRisks
                .filter { $0.type == .wind }
                .flatMap { $0.polygons }

            let polygons = makeMKPolygons(
                from: source,
                coordinates: { $0.ringCoordinates },
                title: { $0.title }
            )
            return MKMultiPolygon(polygons)

        case .meso:
            let polygons = makeMKPolygons(
                from: mesos,
                coordinates: { $0.coordinates.map { $0.location } },
                title: { _ in layer.key }
            )
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
}
