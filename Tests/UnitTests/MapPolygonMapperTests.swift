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

    @Test("Categorical polygon keys are deterministic and unique")
    func categoricalKeys_areDeterministicAndUnique() {
        let stormRisk: [StormRiskDTO] = [
            makeStormRisk(level: .enhanced, title: "ENH"),
            makeStormRisk(level: .slight, title: "SLGT")
        ]

        let first = mapper.polygons(
            for: .categorical,
            stormRisk: stormRisk,
            severeRisks: [],
            mesos: [],
            fires: []
        )
        let second = mapper.polygons(
            for: .categorical,
            stormRisk: stormRisk,
            severeRisks: [],
            mesos: [],
            fires: []
        )

        let firstKeys = first.keyedPolygons.map(\.key)
        let secondKeys = second.keyedPolygons.map(\.key)
        #expect(firstKeys == secondKeys)
        #expect(Set(firstKeys).count == firstKeys.count)
    }

    @Test("Meso polygon keys remain stable when source order changes")
    func mesoKeys_areStableAcrossInputReordering() throws {
        let firstMeso = try makeMeso(
            number: 1001,
            coordinates: [
                Coordinate2D(latitude: 35.0, longitude: -97.0),
                Coordinate2D(latitude: 35.1, longitude: -96.9),
                Coordinate2D(latitude: 35.2, longitude: -97.1)
            ]
        )
        let secondMeso = try makeMeso(
            number: 1002,
            coordinates: [
                Coordinate2D(latitude: 36.0, longitude: -98.0),
                Coordinate2D(latitude: 36.1, longitude: -97.9),
                Coordinate2D(latitude: 36.2, longitude: -98.1)
            ]
        )

        let forward = mapper.polygons(
            for: .meso,
            stormRisk: [],
            severeRisks: [],
            mesos: [firstMeso, secondMeso],
            fires: []
        )
        let reversed = mapper.polygons(
            for: .meso,
            stormRisk: [],
            severeRisks: [],
            mesos: [secondMeso, firstMeso],
            fires: []
        )

        #expect(Set(forward.keyedPolygons.map(\.key)) == Set(reversed.keyedPolygons.map(\.key)))
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

    @Test("Severe CIG polygons include encoded intensity metadata")
    func severePolygons_includeCigMetadata() {
        let severeRisks: [SevereRiskShapeDTO] = [
            SevereRiskShapeDTO(
                type: .tornado,
                probabilities: .percent(0),
                stroke: "#654321",
                fill: "#FEDCBA",
                polygons: [makeGeoPolygon(title: "15% Tornado Risk")],
                label: "CIG1"
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
        #expect(metadata?.cigLevel == 1)
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

    @Test("Warning polygon mapping uses only exterior ring for v1")
    func warningPolygonMapping_usesExteriorRingOnly() throws {
        let warning = makeActiveWarningGeometry(
            id: "warning-1",
            event: "Tornado Warning",
            messageId: "urn:test:rev:1",
            geometry: .polygon(
                rings: [
                    [
                        DeviceAlertCoordinate(longitude: -97.00, latitude: 35.00),
                        DeviceAlertCoordinate(longitude: -96.90, latitude: 35.10),
                        DeviceAlertCoordinate(longitude: -97.10, latitude: 35.20)
                    ],
                    [
                        DeviceAlertCoordinate(longitude: -97.02, latitude: 35.02),
                        DeviceAlertCoordinate(longitude: -97.01, latitude: 35.03),
                        DeviceAlertCoordinate(longitude: -97.03, latitude: 35.01)
                    ]
                ]
            )
        )

        let result = mapper.warningPolygons(from: [warning])
        #expect(result.keyedPolygons.count == 1)

        let entry = try #require(result.keyedPolygons.first)
        #expect(entry.title == "Tornado Warning")
        #expect(entry.coordinates.count == 3)
        #expect(entry.coordinates[0] == Coordinate2D(latitude: 35.00, longitude: -97.00))
        #expect(entry.coordinates[1] == Coordinate2D(latitude: 35.10, longitude: -96.90))
        #expect(entry.coordinates[2] == Coordinate2D(latitude: 35.20, longitude: -97.10))
    }

    @Test("Warning multipolygon mapping creates one stable entry per polygon exterior ring")
    func warningMultipolygonMapping_createsStableEntries() {
        let warning = makeActiveWarningGeometry(
            id: "warning-2",
            event: "Severe Thunderstorm Warning",
            messageId: "urn:test:rev:2",
            geometry: .multiPolygon(
                polygons: [
                    [
                        [
                            DeviceAlertCoordinate(longitude: -98.00, latitude: 36.00),
                            DeviceAlertCoordinate(longitude: -97.90, latitude: 36.10),
                            DeviceAlertCoordinate(longitude: -98.10, latitude: 36.20)
                        ]
                    ],
                    [
                        [
                            DeviceAlertCoordinate(longitude: -99.00, latitude: 37.00),
                            DeviceAlertCoordinate(longitude: -98.90, latitude: 37.10),
                            DeviceAlertCoordinate(longitude: -99.10, latitude: 37.20)
                        ],
                        [
                            DeviceAlertCoordinate(longitude: -99.01, latitude: 37.01),
                            DeviceAlertCoordinate(longitude: -99.02, latitude: 37.02),
                            DeviceAlertCoordinate(longitude: -99.03, latitude: 37.03)
                        ]
                    ]
                ]
            )
        )

        let result = mapper.warningPolygons(from: [warning])
        #expect(result.keyedPolygons.count == 2)
        #expect(result.keyedPolygons[0].key.contains("|0|"))
        #expect(result.keyedPolygons[1].key.contains("|1|"))
        #expect(result.keyedPolygons[0].coordinates[0] == Coordinate2D(latitude: 36.00, longitude: -98.00))
        #expect(result.keyedPolygons[1].coordinates[0] == Coordinate2D(latitude: 37.00, longitude: -99.00))
    }

    @Test("Warning overlay keys are deterministic across repeated mapping")
    func warningOverlayKeys_areDeterministic() {
        let warning = makeActiveWarningGeometry(
            id: "warning-3",
            event: "Flash Flood Warning",
            messageId: "urn:test:rev:3",
            geometry: .polygon(
                rings: [[
                    DeviceAlertCoordinate(longitude: -95.00, latitude: 33.00),
                    DeviceAlertCoordinate(longitude: -94.90, latitude: 33.10),
                    DeviceAlertCoordinate(longitude: -95.10, latitude: 33.20)
                ]]
            )
        )

        let first = mapper.warningPolygons(from: [warning]).keyedPolygons.map(\.key)
        let second = mapper.warningPolygons(from: [warning]).keyedPolygons.map(\.key)
        #expect(first == second)
    }

    @Test("Warning overlay entries have stable ordering regardless of input order")
    func warningOverlayEntries_haveStableOrdering() {
        let warningA = makeActiveWarningGeometry(
            id: "warning-a",
            event: "Tornado Warning",
            messageId: "urn:test:rev:a",
            geometry: .polygon(
                rings: [[
                    DeviceAlertCoordinate(longitude: -100.0, latitude: 30.0),
                    DeviceAlertCoordinate(longitude: -99.9, latitude: 30.1),
                    DeviceAlertCoordinate(longitude: -100.1, latitude: 30.2)
                ]]
            )
        )
        let warningB = makeActiveWarningGeometry(
            id: "warning-b",
            event: "Flash Flood Warning",
            messageId: "urn:test:rev:b",
            geometry: .polygon(
                rings: [[
                    DeviceAlertCoordinate(longitude: -101.0, latitude: 31.0),
                    DeviceAlertCoordinate(longitude: -100.9, latitude: 31.1),
                    DeviceAlertCoordinate(longitude: -101.1, latitude: 31.2)
                ]]
            )
        )

        let forward = mapper.warningPolygons(from: [warningA, warningB]).keyedPolygons.map(\.key)
        let reversed = mapper.warningPolygons(from: [warningB, warningA]).keyedPolygons.map(\.key)
        #expect(forward == reversed)
    }

    @Test("Warning geometry changes produce a new overlay identity fingerprint")
    func warningGeometryChanges_updateOverlayIdentityFingerprint() throws {
        let baseline = makeActiveWarningGeometry(
            id: "warning-4",
            event: "Tornado Warning",
            messageId: "urn:test:rev:4",
            geometry: .polygon(
                rings: [[
                    DeviceAlertCoordinate(longitude: -102.00, latitude: 32.00),
                    DeviceAlertCoordinate(longitude: -101.90, latitude: 32.10),
                    DeviceAlertCoordinate(longitude: -102.10, latitude: 32.20)
                ]]
            )
        )
        let revisedGeometry = makeActiveWarningGeometry(
            id: "warning-4",
            event: "Tornado Warning",
            messageId: "urn:test:rev:4",
            geometry: .polygon(
                rings: [[
                    DeviceAlertCoordinate(longitude: -102.00, latitude: 32.00),
                    DeviceAlertCoordinate(longitude: -101.85, latitude: 32.15),
                    DeviceAlertCoordinate(longitude: -102.15, latitude: 32.25)
                ]]
            )
        )

        let baselineKey = try #require(mapper.warningPolygons(from: [baseline]).keyedPolygons.first?.key)
        let revisedKey = try #require(mapper.warningPolygons(from: [revisedGeometry]).keyedPolygons.first?.key)

        #expect(baselineKey != revisedKey)
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

    private func makeActiveWarningGeometry(
        id: String,
        event: String,
        messageId: String?,
        geometry: DeviceAlertGeometry
    ) -> ActiveWarningGeometry {
        ActiveWarningGeometry(
            id: id,
            messageId: messageId,
            currentRevisionSent: now,
            event: event,
            issued: now,
            effective: now,
            expires: now.addingTimeInterval(3600),
            ends: now.addingTimeInterval(3600),
            messageType: "Alert",
            geometry: geometry
        )
    }
}
