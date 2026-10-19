import Foundation
import SwiftData

/// A coherent Day 2 hazard bundle, isolated from current-day SevereRisk rows.
@Model
final class SPCHazardForecast {
    var issued: Date
    var valid: Date
    var expires: Date
    var acceptedAt: Date
    var tornado: Data
    var hail: Data
    var wind: Data

    init(snapshot: SPCHazardForecastSnapshot, tornado: Data, hail: Data, wind: Data, now: Date) {
        issued = snapshot.issued
        valid = snapshot.valid
        expires = snapshot.expires
        acceptedAt = now
        self.tornado = tornado
        self.hail = hail
        self.wind = wind
    }
}

struct SPCHazardForecastSnapshot: Sendable {
    let day: SPCForecastDay
    let issued: Date
    let valid: Date
    let expires: Date
    let shapes: [SevereRiskShapeDTO]

    /// Empty is an accepted, dated no-area bundle; nil at the repository seam means never loaded.
    var isAcceptedEmpty: Bool { shapes.isEmpty }

    static func parse(tornado: Data, hail: Data, wind: Data, day: SPCForecastDay) throws -> Self {
        guard day == .day2 else { throw SpcError.parsingError }
        let documents = try [tornado, hail, wind].map {
            try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: $0)
        }
        guard let first = documents.first?.features.first,
              let issued = first.properties.ISSUE.asUTCDate(),
              let valid = first.properties.VALID.asUTCDate(),
              let expires = first.properties.EXPIRE.asUTCDate() else { throw SpcError.parsingError }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        guard valid == utc.startOfDay(for: issued).addingTimeInterval(129600),
              expires.timeIntervalSince(valid) == 86400, issued < valid else { throw SpcError.parsingError }
        var shapes: [SevereRiskShapeDTO] = []
        for (document, threat) in zip(documents, [ThreatType.tornado, .hail, .wind]) {
            guard document.type == "FeatureCollection", !document.features.isEmpty else {
                throw SpcError.parsingError
            }
            for feature in document.features {
                let props = feature.properties
                guard feature.type == "Feature", props.ISSUE.asUTCDate() == issued,
                      props.VALID.asUTCDate() == valid, props.EXPIRE.asUTCDate() == expires else {
                    throw SpcError.parsingError
                }
                if feature.geometry.type == "GeometryCollection", feature.geometry.geometries.isEmpty,
                   props.DN == 0, document.features.count == 1,
                   props.LABEL == "No Areas" || props.LABEL == (threat == .tornado
                    ? "Less Than 2% All Areas" : "Less Than 5% All Areas") { continue }
                let polygons = feature.createPolygonEntities(polyTitle: props.LABEL2)
                guard feature.geometry.type == "MultiPolygon", !polygons.isEmpty,
                      polygons.count == feature.geometry.coordinates.count else { throw SpcError.parsingError }
                let probability: ThreatProbability
                if let value = Double(props.LABEL), value > 0, value <= 1, value.isFinite {
                    probability = .percent(value)
                } else if props.LABEL == "SIGN",
                          let value = Int(props.LABEL2.split(separator: "%").first?
                            .trimmingCharacters(in: .whitespaces) ?? ""), (1...100).contains(value) {
                    probability = .significant(value)
                } else if SevereRiskShapeDTO.intensityLevel(from: props.LABEL) != nil {
                    // CIG is conditional intensity, never an unconditional probability.
                    probability = .percent(0)
                } else { throw SpcError.parsingError }
                shapes.append(SevereRiskShapeDTO(type: threat, probabilities: probability,
                    stroke: props.stroke, fill: props.fill, polygons: polygons, label: props.LABEL))
            }
        }
        return Self(day: day, issued: issued, valid: valid, expires: expires, shapes: shapes)
    }
}
