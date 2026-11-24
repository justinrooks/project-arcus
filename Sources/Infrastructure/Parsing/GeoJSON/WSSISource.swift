import Foundation

/// Forge's source identities; combined-day products are deliberately absent.
enum WSSIProduct: String, Decodable, Sendable, CaseIterable {
    case overallImpact = "Overall_Impact", snowAmount = "Snow_Amount", snowLoad = "Snow_Load"
    case iceAccumulation = "Ice_Accumulation", blowingSnow = "Blowing_Snow"
}

enum WSSISeverity: String, Decodable, Sendable, CaseIterable {
    case winterWeatherArea = "WinterWeatherArea", minor = "Minor", moderate = "Moderate"
    case major = "Major", extreme = "Extreme"
}

enum WSSIValidity: String, Decodable, Sendable { case neverAccepted = "NeverAccepted", notYetValid = "NotYetValid", valid = "Valid", expired = "Expired" }
enum WSSISourceStatus: String, Decodable, Sendable { case unknown = "Unknown", available = "Available", unavailable = "Unavailable" }
enum WSSIPollHealth: String, Decodable, Sendable { case unknown = "Unknown", successful = "Successful", failed = "Failed" }
enum WSSIPollFreshness: String, Decodable, Sendable { case unknown = "Unknown", scheduled = "Scheduled", incomplete = "Incomplete", overdue = "Overdue" }
enum WSSICoverage: String, Decodable, Sendable { case unknown }

struct WSSIAcceptedRevision: Decodable, Sendable, Equatable {
    let revision: UUID
    let issuedAt: Date
    let validFrom: Date
    let validTo: Date
    let gisFileDate: Date?
    let gisIngestDate: Date?
    let retrievedAt: Date
    let geometryPath: String
}

struct WSSIManifestEntry: Decodable, Sendable {
    let product: WSSIProduct
    let day: Int
    let validity: WSSIValidity
    let sourceStatus: WSSISourceStatus
    let pollHealth: WSSIPollHealth
    let coverage: WSSICoverage
    let accepted: WSSIAcceptedRevision?
}

struct WSSIManifest: Decodable, Sendable {
    let datasets: [WSSIManifestEntry]
    let pollFreshness: WSSIPollFreshness
}

struct WSSIGeometryMetadata: Decodable, Sendable {
    let product: WSSIProduct
    let day: Int
    let revision: UUID
    let issuedAt: Date
    let validFrom: Date
    let validTo: Date
    let gisFileDate: Date?
    let gisIngestDate: Date?
    let retrievedAt: Date
    let coverage: WSSICoverage
}

struct WSSIPosition: Decodable, Sendable, Hashable {
    let longitude: Double
    let latitude: Double

    init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        longitude = try values.decode(Double.self)
        latitude = try values.decode(Double.self)
        guard values.isAtEnd, longitude.isFinite, latitude.isFinite,
              (-180...180).contains(longitude), (-90...90).contains(latitude) else {
            throw DecodingError.dataCorruptedError(in: values, debugDescription: "Invalid WSSI position")
        }
    }
}

struct WSSIPolygon: Decodable, Sendable {
    let rings: [[WSSIPosition]]

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        rings = try container.decode([[WSSIPosition]].self)
        guard !rings.isEmpty, rings.allSatisfy({ ring in
            guard ring.count >= 4, let origin = ring.first, origin == ring.last,
                  Set(ring.dropLast()).count >= 3 else { return false }
            let area = zip(ring, ring.dropFirst()).reduce(0.0) { total, pair in
                total + (pair.0.longitude - origin.longitude) * (pair.1.latitude - origin.latitude)
                    - (pair.1.longitude - origin.longitude) * (pair.0.latitude - origin.latitude)
            }
            return area.isFinite && area != 0
        }) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Incomplete WSSI polygon rings")
        }
    }
}

struct WSSIGeometry: Decodable, Sendable {
    let type: String
    let coordinates: [WSSIPolygon]
}

struct WSSIFeatureProperties: Decodable, Sendable {
    let sourceObjectId: Int64
    let severity: WSSISeverity
}

struct WSSIFeature: Decodable, Sendable {
    let type: String
    let id: Int64
    let properties: WSSIFeatureProperties
    let geometry: WSSIGeometry
}

struct WSSIFeatureCollection: Decodable, Sendable {
    let type: String
    let metadata: WSSIGeometryMetadata
    let features: [WSSIFeature]
}

enum WSSISourceDecoder {
    enum Error: Swift.Error { case invalidManifest, invalidGeometry }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let pattern = #"^(\d{4})-(\d{2})-(\d{2})T([01]\d|2[0-3]):([0-5]\d):([0-5]\d)(?:\.[0-9]{1,6})?(Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)$"#
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(value.startIndex..., in: value)
            guard let match = regex.firstMatch(in: value, range: range), match.range == range,
                  let yearRange = Range(match.range(at: 1), in: value),
                  let monthRange = Range(match.range(at: 2), in: value),
                  let dayRange = Range(match.range(at: 3), in: value),
                  let year = Int(value[yearRange]), let month = Int(value[monthRange]), let day = Int(value[dayRange]) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid WSSI timestamp")
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let components = DateComponents(year: year, month: month, day: day)
            guard let calendarDate = calendar.date(from: components),
                  calendar.dateComponents([.year, .month, .day], from: calendarDate) == components,
                  let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: value.contains(".")).parse(value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid WSSI timestamp")
            }
            return date
        }
        return decoder
    }

    static func manifest(from data: Data) throws -> WSSIManifest {
        let manifest = try decoder().decode(WSSIManifest.self, from: data)
        let identities = Set(manifest.datasets.map { "\($0.product.rawValue):\($0.day)" })
        guard manifest.datasets.count == 15, identities.count == 15,
              manifest.datasets.allSatisfy({ entry in
                  guard (1...3).contains(entry.day) else { return false }
                  guard let accepted = entry.accepted else { return entry.validity == .neverAccepted }
                  return entry.validity != .neverAccepted && accepted.validFrom < accepted.validTo && accepted.issuedAt < accepted.validTo
                      && !accepted.geometryPath.isEmpty
              }) else { throw Error.invalidManifest }
        return manifest
    }

    static func geometry(from data: Data, for entry: WSSIManifestEntry) throws -> WSSIFeatureCollection {
        let result = try decoder().decode(WSSIFeatureCollection.self, from: data)
        let m = result.metadata
        guard let accepted = entry.accepted, (1...3).contains(entry.day),
              accepted.validFrom < accepted.validTo, accepted.issuedAt < accepted.validTo, !accepted.geometryPath.isEmpty,
              result.type == "FeatureCollection", !result.features.isEmpty,
              m.product == entry.product, m.day == entry.day, m.revision == accepted.revision,
              m.issuedAt == accepted.issuedAt, m.validFrom == accepted.validFrom, m.validTo == accepted.validTo,
              m.gisFileDate == accepted.gisFileDate, m.gisIngestDate == accepted.gisIngestDate,
              m.retrievedAt == accepted.retrievedAt, m.coverage == entry.coverage,
              result.features.enumerated().allSatisfy({ index, feature in
                  feature.id == Int64(index + 1) && feature.properties.sourceObjectId > 0
                      && feature.type == "Feature" && feature.geometry.type == "MultiPolygon" && !feature.geometry.coordinates.isEmpty
              }), Set(result.features.map(\.properties.sourceObjectId)).count == result.features.count else {
            throw Error.invalidGeometry
        }
        return result
    }
}
