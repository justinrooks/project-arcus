import Foundation
import SwiftData

/// One accepted source document per future forecast day; never queried as local Day 1 risk.
@Model
final class SPCCategoricalForecast {
    var day: Int
    var issued: Date
    var valid: Date
    var expires: Date
    var acceptedAt: Date
    var transportSource: String
    var payload: Data

    init(day: SPCForecastDay, snapshot: SPCCategoricalForecastSnapshot, payload: Data, source: String, now: Date) {
        self.day = day.rawValue
        issued = snapshot.issued
        valid = snapshot.valid
        expires = snapshot.expires
        acceptedAt = now
        transportSource = source
        self.payload = payload
    }
}

struct SPCCategoricalForecastSnapshot: Sendable {
    let day: SPCForecastDay
    let issued: Date
    let valid: Date
    let expires: Date
    let risks: [StormRiskDTO]

    var isAcceptedEmpty: Bool { risks.isEmpty }

    /// Empty collections lack issuance identity. Only SPC's dated no-area sentinel establishes accepted empty.
    static func parse(_ data: Data, day: SPCForecastDay) throws -> Self {
        guard day == .day2 || day == .day3 else { throw SpcError.parsingError }
        let document = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
        guard document.type == "FeatureCollection", let first = document.features.first else {
            throw SpcError.parsingError
        }
        let properties = first.properties
        guard let issued = properties.ISSUE.asUTCDate(),
              let valid = properties.VALID.asUTCDate(),
              let expires = properties.EXPIRE.asUTCDate() else { throw SpcError.parsingError }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let expectedValid = utc.startOfDay(for: issued).addingTimeInterval(Double(day.rawValue - 1) * 86400 + 43200)
        guard valid == expectedValid, expires.timeIntervalSince(valid) == 86400, issued < valid else {
            throw SpcError.parsingError
        }
        var risks: [StormRiskDTO] = []
        for feature in document.features {
            let props = feature.properties
            guard feature.type == "Feature", props.ISSUE.asUTCDate() == issued,
                  props.VALID.asUTCDate() == valid, props.EXPIRE.asUTCDate() == expires else {
                throw SpcError.parsingError
            }
            if feature.geometry.type == "GeometryCollection", feature.geometry.geometries.isEmpty,
               props.DN == 0, props.LABEL == "No Areas", document.features.count == 1 {
                continue
            }
            let polygons = feature.createPolygonEntities(polyTitle: props.LABEL2)
            guard feature.geometry.type == "MultiPolygon", !polygons.isEmpty,
                  polygons.count == feature.geometry.coordinates.count,
                  ["TSTM", "MRGL", "SLGT", "ENH", "MDT", "HIGH"].contains(props.LABEL) else {
                throw SpcError.parsingError
            }
            risks.append(StormRiskDTO(
                riskLevel: StormRiskLevel(abbreviation: props.LABEL), issued: issued, expires: expires,
                valid: valid, stroke: props.stroke, fill: props.fill, polygons: polygons
            ))
        }
        return Self(day: day, issued: issued, valid: valid, expires: expires, risks: risks)
    }
}
