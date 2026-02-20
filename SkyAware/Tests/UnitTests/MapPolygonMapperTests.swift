//
//  MapPolygonMapperTests.swift
//  SkyAwareTests
//
//  Created by Justin Rooks on 2/15/26.
//

import Foundation
import Testing
import UIKit
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
            SevereRiskShapeDTO(
                type: .wind,
                probabilities: .percent(0.15),
                stroke: nil,
                fill: nil,
                polygons: [makeGeoPolygon(title: "15% Wind Risk")]
            ),
            SevereRiskShapeDTO(
                type: .hail,
                probabilities: .percent(0.05),
                stroke: nil,
                fill: nil,
                polygons: [makeGeoPolygon(title: "5% Hail Risk")]
            ),
            SevereRiskShapeDTO(
                type: .wind,
                probabilities: .significant(30),
                stroke: nil,
                fill: nil,
                polygons: [makeGeoPolygon(title: "30% Significant Wind Risk")]
            )
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

    @Test("Severe polygons render SIGN above non-significant when probability ties")
    func severePolygons_significantRendersOnTopForEqualProbability() {
        let severeRisks: [SevereRiskShapeDTO] = [
            SevereRiskShapeDTO(
                type: .tornado,
                probabilities: .significant(10),
                stroke: nil,
                fill: nil,
                polygons: [makeGeoPolygon(title: "10% Significant Tornado Risk")]
            ),
            SevereRiskShapeDTO(
                type: .tornado,
                probabilities: .percent(0.10),
                stroke: nil,
                fill: nil,
                polygons: [makeGeoPolygon(title: "10% Tornado Risk")]
            )
        ]

        let tornado = mapper.polygons(
            for: .tornado,
            stormRisk: [],
            severeRisks: severeRisks,
            mesos: [],
            fires: []
        )

        // Lower/equal non-significant should be first; SIGN should render last on top.
        #expect(tornado.polygons.compactMap { $0.title } == [
            "10% Tornado Risk",
            "10% Significant Tornado Risk"
        ])
    }

    @Test("Severe polygons include encoded SPC style metadata")
    func severePolygons_includeStyleMetadata() {
        let severeRisks: [SevereRiskShapeDTO] = [
            SevereRiskShapeDTO(
                type: .tornado,
                probabilities: .percent(0.10),
                stroke: "#654321",
                fill: "#FEDCBA",
                polygons: [makeGeoPolygon(title: "10% Tornado Risk")]
            )
        ]

        let result = mapper.polygons(
            for: .tornado,
            stormRisk: [],
            severeRisks: severeRisks,
            mesos: [],
            fires: []
        )

        #expect(result.polygons.count == 1)
        let metadata = StormRiskPolygonStyleMetadata.decode(from: result.polygons.first?.subtitle)
        #expect(metadata?.strokeHex == "#654321")
        #expect(metadata?.fillHex == "#FEDCBA")
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

    @Test("Severe polygons without style metadata keep subtitle nil")
    func severePolygons_withoutStyleMetadataHaveNilSubtitle() {
        let severeRisks: [SevereRiskShapeDTO] = [
            SevereRiskShapeDTO(
                type: .wind,
                probabilities: .percent(0.15),
                stroke: nil,
                fill: nil,
                polygons: [makeGeoPolygon(title: "15% Wind Risk")]
            )
        ]

        let result = mapper.polygons(
            for: .wind,
            stormRisk: [],
            severeRisks: severeRisks,
            mesos: [],
            fires: []
        )

        #expect(result.polygons.count == 1)
        #expect(result.polygons.first?.subtitle == nil)
    }

    @Test("Legend severe styles match map styles including alpha")
    func legendSevereStyle_matchesMapStyle() {
        let mapStyle = PolygonStyleProvider.getPolygonStyle(
            risk: "TOR",
            probability: "10",
            context: .map,
            spcFillHex: "#112233",
            spcStrokeHex: "#445566"
        )
        let legendStyle = PolygonStyleProvider.getPolygonStyleForLegend(
            risk: "TOR",
            probability: "10",
            spcFillHex: "#112233",
            spcStrokeHex: "#445566"
        )

        #expect(rgba(of: mapStyle.0) == rgba(of: legendStyle.0))
        #expect(rgba(of: mapStyle.1) == rgba(of: legendStyle.1))
    }

    @Test("SPC fill alpha is normalized to overlay alpha for map and legend")
    func spcFillAlpha_isNormalizedForMapAndLegend() {
        let mapStyle = PolygonStyleProvider.getPolygonStyle(
            risk: "HAIL",
            probability: "30",
            context: .map,
            spcFillHex: "#80112233"
        )
        let legendStyle = PolygonStyleProvider.getPolygonStyleForLegend(
            risk: "HAIL",
            probability: "30",
            spcFillHex: "#80112233"
        )

        #expect(abs(alpha(of: mapStyle.0) - 0.3) < 0.0001)
        #expect(abs(alpha(of: legendStyle.0) - 0.3) < 0.0001)
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

    private func rgba(of color: UIColor) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }

    private func alpha(of color: UIColor) -> CGFloat {
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        return alpha
    }
}
