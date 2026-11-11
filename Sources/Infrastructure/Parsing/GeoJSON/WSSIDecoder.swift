import Foundation

enum WSSIProduct: String, CaseIterable, Sendable {
    case overall = "WSSI_OVERALL"
    case snowAmount = "SNOW_AMOUNT"
    case snowLoad = "SNOW_LOAD"
    case iceAccumulation = "ICE_ACCUMULATION"
    case blowingSnow = "BLOWING_SNOW"
}

enum WSSIPeriod: String, CaseIterable, Sendable {
    case day1 = "Day_1"
    case day2 = "Day_2"
    case day3 = "Day_3"
    case days1To3 = "Days_1_3"
}

enum WSSIImpact: String, CaseIterable, Sendable {
    case winterWeatherArea = "WINTER WEATHER AREA"
    case minor = "MINOR"
    case moderate = "MODERATE"
    case major = "MAJOR"
    case extreme = "EXTREME"
}

struct WSSIScope: Sendable, Equatable {
    let south: Double
    let west: Double
    let north: Double
    let east: Double

    init(south: Double, west: Double, north: Double, east: Double) throws {
        guard south.isFinite, west.isFinite, north.isFinite, east.isFinite,
              (-90...90).contains(south), (-90...90).contains(north),
              (-180...180).contains(west), (-180...180).contains(east),
              south < north, west < east else { throw WSSIDecodingError.invalidScope }
        self.south = south
        self.west = west
        self.north = north
        self.east = east
    }
}

struct WSSIPolygon: Sendable, Equatable {
    let rings: [[Coordinate2D]]
}

struct WSSIFeature: Sendable, Equatable {
    let product: WSSIProduct
    let period: WSSIPeriod
    let impact: WSSIImpact
    let issuedAt: Date
    let validFrom: Date
    let validTo: Date
    let polygons: [WSSIPolygon]
}

struct WSSIFeatureCollection: Sendable, Equatable {
    /// An empty response has no publication identity.
    let features: [WSSIFeature]
}

enum WSSIDecodingError: Error, Equatable {
    case invalidScope
    case invalidResponse(String)
    case invalidFeature(String)
    case invalidGeometry(String)
}

enum WSSIDecoder {
    static func decode(_ data: Data) throws -> WSSIFeatureCollection {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["error"] == nil, let features = root["features"] as? [[String: Any]] else {
            throw WSSIDecodingError.invalidResponse("Expected a feature collection")
        }
        let geoJSON = root["type"] as? String == "FeatureCollection"
        if !geoJSON {
            guard root["geometryType"] as? String == "esriGeometryPolygon",
                  let reference = root["spatialReference"] as? [String: Any],
                  ((reference["latestWkid"] as? Int) ?? (reference["wkid"] as? Int)) == 4326 else {
                throw WSSIDecodingError.invalidResponse("Expected WGS84 polygon feature set")
            }
        } else if root["crs"] != nil {
            throw WSSIDecodingError.invalidResponse("Unexpected GeoJSON coordinate reference")
        }
        return WSSIFeatureCollection(features: try features.enumerated().map {
            try decodeFeature($0.element, index: $0.offset, geoJSON: geoJSON)
        })
    }

    private static func decodeFeature(_ object: [String: Any], index: Int, geoJSON: Bool) throws -> WSSIFeature {
        func invalid(_ field: String) -> WSSIDecodingError { .invalidFeature("Feature \(index): invalid \(field)") }
        guard let attributes = object[geoJSON ? "properties" : "attributes"] as? [String: Any],
              let source = attributes["idp_source"] as? String,
              let product = WSSIProduct.allCases.first(where: { product in
                  WSSIPeriod.allCases.contains { source == "\(product.rawValue)_\($0.rawValue)" }
              }),
              let period = WSSIPeriod.allCases.first(where: { source == "\(product.rawValue)_\($0.rawValue)" }),
              attributes["component"] as? String == product.rawValue,
              let impactName = attributes["impact"] as? String, let impact = WSSIImpact(rawValue: impactName) else {
            throw invalid("source or impact")
        }
        guard let issuedText = attributes["issue_time"] as? String,
              let issued = date(issuedText, format: "yyyy-MM-dd HHmm'Z'"),
              let fromText = attributes["start_time"] as? String,
              let from = date(fromText, format: "HH'Z' MM/dd/yy"),
              let toText = attributes["end_time"] as? String,
              let to = date(toText, format: "HH'Z' MM/dd/yy"), from < to, issued < to else {
            throw invalid("validity metadata")
        }
        guard let geometry = object["geometry"] as? [String: Any] else {
            throw WSSIDecodingError.invalidGeometry("Feature \(index): missing geometry")
        }
        let rawPolygons: [[[[Double]]]]
        if geoJSON {
            switch geometry["type"] as? String {
            case "Polygon":
                guard let rings = geometry["coordinates"] as? [[[Double]]] else { throw invalid("polygon") }
                rawPolygons = [rings]
            case "MultiPolygon":
                guard let polygons = geometry["coordinates"] as? [[[[Double]]]] else { throw invalid("multipolygon") }
                rawPolygons = polygons
            default: throw WSSIDecodingError.invalidGeometry("Feature \(index): unsupported geometry")
            }
        } else {
            guard let rings = geometry["rings"] as? [[[Double]]] else { throw invalid("rings") }
            rawPolygons = try groupArcGISRings(rings, index: index)
        }
        guard !rawPolygons.isEmpty else { throw WSSIDecodingError.invalidGeometry("Feature \(index): empty geometry") }
        let polygons = try rawPolygons.map { rings -> WSSIPolygon in
            guard !rings.isEmpty else { throw WSSIDecodingError.invalidGeometry("Feature \(index): empty polygon") }
            let points = try rings.map { try coordinates($0, index: index) }
            try validateTopology(rings, index: index)
            return WSSIPolygon(rings: points)
        }
        return WSSIFeature(product: product, period: period, impact: impact, issuedAt: issued,
                           validFrom: from, validTo: to, polygons: polygons)
    }

    private static func date(_ text: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format
        formatter.isLenient = false
        guard let result = formatter.date(from: text), formatter.string(from: result) == text else { return nil }
        return result
    }

    private static func coordinates(_ ring: [[Double]], index: Int) throws -> [Coordinate2D] {
        guard ring.count >= 4, ring.first == ring.last else {
            throw WSSIDecodingError.invalidGeometry("Feature \(index): unclosed or short ring")
        }
        let points = try ring.map { pair -> Coordinate2D in
            guard pair.count == 2, pair[0].isFinite, pair[1].isFinite,
                  (-180...180).contains(pair[0]), (-90...90).contains(pair[1]) else {
                throw WSSIDecodingError.invalidGeometry("Feature \(index): invalid coordinate")
            }
            return Coordinate2D(latitude: pair[1], longitude: pair[0])
        }
        guard abs(signedArea(ring)) > 0 else {
            throw WSSIDecodingError.invalidGeometry("Feature \(index): degenerate ring")
        }
        return points
    }

    private static func signedArea(_ ring: [[Double]]) -> Double {
        zip(ring, ring.dropFirst()).reduce(0) { $0 + ($1.1[0] - $1.0[0]) * ($1.1[1] + $1.0[1]) }
    }

    private struct Segment {
        let ring: Int
        let index: Int
        let a: [Double]
        let b: [Double]
        var minX: Double { min(a[0], b[0]) }
        var maxX: Double { max(a[0], b[0]) }
        var minY: Double { min(a[1], b[1]) }
        var maxY: Double { max(a[1], b[1]) }
    }

    private static func validateTopology(_ rings: [[[Double]]], index: Int) throws {
        for hole in rings.dropFirst() {
            guard hole.dropLast().contains(where: { contains($0, ring: rings[0], includeBoundary: false) }),
                  zip(hole, hole.dropFirst()).allSatisfy({ a, b in
                      segmentInside(a, b, ring: rings[0])
                  }) else {
                throw WSSIDecodingError.invalidGeometry("Feature \(index): hole outside exterior")
            }
        }
        let segments = rings.enumerated().flatMap { ringIndex, ring in
            zip(ring, ring.dropFirst()).enumerated().map { offset, pair in
                Segment(ring: ringIndex, index: offset, a: pair.0, b: pair.1)
            }
        }.sorted { $0.minX < $1.minX }
        for i in segments.indices {
            let a = segments[i]
            var j = i + 1
            while j < segments.count, segments[j].minX <= a.maxX {
                let b = segments[j]
                defer { j += 1 }
                guard a.minY <= b.maxY, b.minY <= a.maxY else { continue }
                if a.ring == b.ring {
                    let distance = abs(a.index - b.index)
                    if distance == 1 || distance == rings[a.ring].count - 2 { continue }
                }
                if intersects(a, b) {
                    throw WSSIDecodingError.invalidGeometry("Feature \(index): crossing polygon rings")
                }
            }
        }
    }

    private static func segmentInside(_ a: [Double], _ b: [Double], ring: [[Double]]) -> Bool {
        guard contains(a, ring: ring), contains(b, ring: ring) else { return false }
        let dx = b[0] - a[0], dy = b[1] - a[1]
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return true }
        var cuts = [0.0, 1.0]
        for point in ring.dropLast() {
            let cross = (point[0] - a[0]) * dy - (point[1] - a[1]) * dx
            guard abs(cross) < 1e-12 else { continue }
            let t = ((point[0] - a[0]) * dx + (point[1] - a[1]) * dy) / lengthSquared
            if t > 0 && t < 1 { cuts.append(t) }
        }
        cuts.sort()
        return zip(cuts, cuts.dropFirst()).allSatisfy { start, end in
            let t = (start + end) / 2
            return contains([a[0] + t * dx, a[1] + t * dy], ring: ring)
        }
    }

    private static func intersects(_ first: Segment, _ second: Segment) -> Bool {
        func orientation(_ a: [Double], _ b: [Double], _ c: [Double]) -> Double {
            (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
        }
        let a = orientation(first.a, first.b, second.a)
        let b = orientation(first.a, first.b, second.b)
        let c = orientation(second.a, second.b, first.a)
        let d = orientation(second.a, second.b, first.b)
        if ((a > 0 && b < 0) || (a < 0 && b > 0)) &&
           ((c > 0 && d < 0) || (c < 0 && d > 0)) { return true }
        // Source rings can touch at a point; overlapping collinear edges are invalid.
        if a == 0 && b == 0 && c == 0 && d == 0 {
            let xOverlap = min(first.maxX, second.maxX) - max(first.minX, second.minX)
            let yOverlap = min(first.maxY, second.maxY) - max(first.minY, second.minY)
            return xOverlap > 0 || yOverlap > 0
        }
        return false
    }

    private static func groupArcGISRings(_ rings: [[[Double]]], index: Int) throws -> [[[[Double]]]] {
        for ring in rings { _ = try coordinates(ring, index: index) }
        var polygons = rings.filter { signedArea($0) > 0 }.map { [$0] }
        for hole in rings where signedArea(hole) < 0 {
            guard let point = hole.first,
                  let owner = polygons.indices.filter({ contains(point, ring: polygons[$0][0]) })
                    .min(by: { abs(signedArea(polygons[$0][0])) < abs(signedArea(polygons[$1][0])) }) else {
                throw WSSIDecodingError.invalidGeometry("Feature \(index): orphan interior ring")
            }
            polygons[owner].append(hole)
        }
        return polygons
    }

    private static func contains(_ point: [Double], ring: [[Double]], includeBoundary: Bool = true) -> Bool {
        var inside = false
        for (a, b) in zip(ring, ring.dropFirst()) {
            let cross = (point[0] - a[0]) * (b[1] - a[1]) - (point[1] - a[1]) * (b[0] - a[0])
            if abs(cross) < 1e-12,
               (min(a[0], b[0])...max(a[0], b[0])).contains(point[0]),
               (min(a[1], b[1])...max(a[1], b[1])).contains(point[1]) { return includeBoundary }
            if (a[1] > point[1]) != (b[1] > point[1]),
               point[0] < (b[0] - a[0]) * (point[1] - a[1]) / (b[1] - a[1]) + a[0] { inside.toggle() }
        }
        return inside
    }
}
