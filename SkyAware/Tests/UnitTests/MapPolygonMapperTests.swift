//
//  MapPolygonMapperTests.swift
//  SkyAwareTests
//
//  Created by Justin Rooks on 2/15/26.
//

import Foundation
import Testing
@testable import SkyAware

@Suite("MapPolygonMapper")
struct MapPolygonMapperTests {
    private let mapper = MapPolygonMapper()
    private let now = Date(timeIntervalSince1970: 1_735_689_600) // Jan 1, 2025 00:00:00 UTC

    @Test("Categorical polygons render from low to high severity")
    func categoricalPolygons_areOrderedBySeverity() {
        let stormRisk: [StormRiskDTO] = [
            makeStormRisk(level: .high, title: "HIGH"),
            makeStormRisk(level: .slight, title: "SLGT"),
            makeStormRisk(level: .thunderstorm, title: "TSTM"),
            makeStormRisk(level: .marginal, title: "MRGL")
        ]

        let result = mapper.polygons(
            for: .categorical,
            stormRisk: stormRisk,
            severeRisks: [],
            mesos: [],
            fires: []
        )

        let titles = result.polygons.compactMap { $0.title }
        #expect(titles == ["TSTM", "MRGL", "SLGT", "HIGH"])
    }

    @Test("Severe layers only include polygons for selected threat type")
    func severePolygons_areFilteredByThreatType() {
        let severeRisks: [SevereRiskShapeDTO] = [
            SevereRiskShapeDTO(type: .wind, probabilities: .percent(0.15), polygons: [makeGeoPolygon(title: "15% Wind Risk")]),
            SevereRiskShapeDTO(type: .hail, probabilities: .percent(0.05), polygons: [makeGeoPolygon(title: "5% Hail Risk")]),
            SevereRiskShapeDTO(type: .wind, probabilities: .significant(30), polygons: [makeGeoPolygon(title: "30% Significant Wind Risk")])
        ]

        let wind = mapper.polygons(
            for: .wind,
            stormRisk: [],
            severeRisks: severeRisks,
            mesos: [],
            fires: []
        )
        let hail = mapper.polygons(
            for: .hail,
            stormRisk: [],
            severeRisks: severeRisks,
            mesos: [],
            fires: []
        )

        #expect(wind.polygons.compactMap { $0.title } == ["15% Wind Risk", "30% Significant Wind Risk"])
        #expect(hail.polygons.compactMap { $0.title } == ["5% Hail Risk"])
    }

    @Test("Meso polygons are titled MESO for consistent map styling")
    func mesoPolygons_useMesoTitle() throws {
        let mesos: [MdDTO] = [
            try makeMeso(number: 1001, coordinates: [Coordinate2D(latitude: 35.0, longitude: -97.0),
                                                     Coordinate2D(latitude: 35.1, longitude: -96.9),
                                                     Coordinate2D(latitude: 35.2, longitude: -97.1)]),
            try makeMeso(number: 1002, coordinates: [Coordinate2D(latitude: 36.0, longitude: -98.0),
                                                     Coordinate2D(latitude: 36.1, longitude: -97.9),
                                                     Coordinate2D(latitude: 36.2, longitude: -98.1)])
        ]

        let result = mapper.polygons(
            for: .meso,
            stormRisk: [],
            severeRisks: [],
            mesos: mesos,
            fires: []
        )

        #expect(result.polygons.count == 2)
        #expect(result.polygons.allSatisfy { $0.title == MapLayer.meso.key })
    }

    @Test("Fire polygons include encoded SPC style metadata")
    func firePolygons_includeStyleMetadata() {
        let fires: [FireRiskDTO] = [
            FireRiskDTO(
                product: "WindRH",
                issued: now,
                expires: now.addingTimeInterval(3600),
                valid: now,
                riskLevel: 8,
                riskLevelDescription: "Critical",
                label: "Critical Fire Weather Area",
                stroke: "#123456",
                fill: "#ABCDEF",
                polygons: [makeGeoPolygon(title: "Critical Fire Weather Area")]
            )
        ]

        let result = mapper.polygons(
            for: .fire,
            stormRisk: [],
            severeRisks: [],
            mesos: [],
            fires: fires
        )

        #expect(result.polygons.count == 1)
        let metadata = StormRiskPolygonStyleMetadata.decode(from: result.polygons.first?.subtitle)
        #expect(metadata?.strokeHex == "#123456")
        #expect(metadata?.fillHex == "#ABCDEF")
    }

    private func makeStormRisk(level: StormRiskLevel, title: String) -> StormRiskDTO {
        StormRiskDTO(
            riskLevel: level,
            issued: now,
            expires: now.addingTimeInterval(3600),
            valid: now,
            stroke: nil,
            fill: nil,
            polygons: [makeGeoPolygon(title: title)]
        )
    }

    private func makeGeoPolygon(title: String) -> GeoPolygonEntity {
        GeoPolygonEntity(
            title: title,
            coordinates: [
                Coordinate2D(latitude: 35.0, longitude: -97.0),
                Coordinate2D(latitude: 35.1, longitude: -96.9),
                Coordinate2D(latitude: 35.2, longitude: -97.1)
            ]
        )
    }

    private func makeMeso(number: Int, coordinates: [Coordinate2D]) throws -> MdDTO {
        let link = try #require(URL(string: "https://example.com/md/\(number)"))
        return MdDTO(
            number: number,
            title: "SPC MD \(number)",
            link: link,
            issued: now,
            validStart: now,
            validEnd: now.addingTimeInterval(3600),
            areasAffected: "Test Area",
            summary: "Test Summary",
            watchProbability: "40",
            threats: nil,
            coordinates: coordinates
        )
    }
}
