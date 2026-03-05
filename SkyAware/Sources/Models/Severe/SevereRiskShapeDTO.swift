//
//  SevereRiskMapDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/25/25.
//

import Foundation

struct SevereRiskShapeDTO: Sendable {
    let type: ThreatType
    let probabilities: ThreatProbability
    let stroke: String?
    let fill: String?
    let polygons: [GeoPolygonEntity]
    let label: String

    var title: String {
        polygons.first?.title ?? probabilities.description
    }

    var intensityLevel: Int? {
        Self.intensityLevel(from: label)
    }

    init(
        type: ThreatType,
        probabilities: ThreatProbability,
        stroke: String?,
        fill: String?,
        polygons: [GeoPolygonEntity],
        label: String = ""
    ) {
        self.type = type
        self.probabilities = probabilities
        self.stroke = stroke
        self.fill = fill
        self.polygons = polygons
        self.label = label
    }

    static func intensityLevel(from label: String) -> Int? {
        let normalized = label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard normalized.hasPrefix("CIG") else { return nil }
        guard let level = Int(normalized.dropFirst(3)), (1...3).contains(level) else {
            return nil
        }
        return level
    }
}
