#if DEBUG
import CoreLocation
import Darwin
import Foundation

/// Temporary fixture-based WSSI geometry experiment; timings are not device benchmarks.
enum WSSIGeometryExperiment {
    struct Position: Decodable, Sendable {
        let longitude: Double
        let latitude: Double

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()
            longitude = try container.decode(Double.self)
            latitude = try container.decode(Double.self)
            guard container.isAtEnd, longitude.isFinite, latitude.isFinite,
                  (-180...180).contains(longitude), (-90...90).contains(latitude) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid position")
            }
        }
    }

    struct Polygon: Decodable, Sendable {
        let rings: [[Position]]
        let minLon: Double
        let maxLon: Double
        let minLat: Double
        let maxLat: Double

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            rings = try container.decode([[Position]].self)
            guard let outer = rings.first, rings.allSatisfy({ ring in
                guard let first = ring.first, let last = ring.last else { return false }
                return ring.count >= 4 && first.longitude == last.longitude && first.latitude == last.latitude
            }) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Incomplete polygon rings")
            }
            minLon = outer.map(\.longitude).min()!
            maxLon = outer.map(\.longitude).max()!
            minLat = outer.map(\.latitude).min()!
            maxLat = outer.map(\.latitude).max()!
        }

        func contains(_ point: CLLocationCoordinate2D) -> Bool {
            guard (minLon...maxLon).contains(point.longitude), (minLat...maxLat).contains(point.latitude),
                  Self.inRing(point, rings[0]) else { return false }
            return !rings.dropFirst().contains { Self.inRing(point, $0) }
        }

        private static func inRing(_ point: CLLocationCoordinate2D, _ ring: [Position]) -> Bool {
            var inside = false
            for i in 1..<ring.count {
                let a = ring[i - 1], b = ring[i]
                let cross = (point.longitude - a.longitude) * (b.latitude - a.latitude)
                    - (point.latitude - a.latitude) * (b.longitude - a.longitude)
                if cross == 0,
                   (min(a.longitude, b.longitude)...max(a.longitude, b.longitude)).contains(point.longitude),
                   (min(a.latitude, b.latitude)...max(a.latitude, b.latitude)).contains(point.latitude) { return true }
                if (a.latitude > point.latitude) != (b.latitude > point.latitude),
                   point.longitude < (b.longitude - a.longitude) * (point.latitude - a.latitude)
                    / (b.latitude - a.latitude) + a.longitude { inside.toggle() }
            }
            return inside
        }
    }

    struct Geometry: Decodable, Sendable {
        let coordinates: [Polygon]
        private enum CodingKeys: String, CodingKey { case type, coordinates }
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard try container.decode(String.self, forKey: .type) == "MultiPolygon" else {
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Expected MultiPolygon")
            }
            coordinates = try container.decode([Polygon].self, forKey: .coordinates)
            guard !coordinates.isEmpty else {
                throw DecodingError.dataCorruptedError(forKey: .coordinates, in: container, debugDescription: "Empty geometry")
            }
        }
    }
    struct Properties: Decodable, Sendable { let sourceObjectId: Int; let severity: String }
    struct Feature: Decodable, Sendable { let type: String; let properties: Properties; let geometry: Geometry }
    struct Metadata: Decodable, Sendable { let product: String; let day: Int; let revision: UUID }
    struct Collection: Decodable, Sendable { let type: String; let metadata: Metadata; let features: [Feature] }

    struct Report: Sendable {
        let fixtureIdentity: String
        let metadata: Metadata
        let featureCount: Int
        let polygonCount: Int
        let ringCount: Int
        let vertexCount: Int
        let bodyBytes: Int
        let decodeSeconds: Double
        let containmentSeconds: Double
        let matchingSeverities: [[String]]
        let footprintBeforeDecode: UInt64?
        let footprintWithGeometry: UInt64?
        let footprintAfterGeometryRelease: UInt64?
    }

    static func measure(_ data: Data, fixtureIdentity: String, points: [CLLocationCoordinate2D]) throws -> Report {
        let before = footprint()
        let result = try decodeAndMeasure(data, points: points)
        return Report(fixtureIdentity: fixtureIdentity, metadata: result.metadata, featureCount: result.featureCount,
                      polygonCount: result.polygonCount, ringCount: result.ringCount, vertexCount: result.vertexCount,
                      bodyBytes: data.count, decodeSeconds: result.decodeSeconds, containmentSeconds: result.containmentSeconds,
                      matchingSeverities: result.matches, footprintBeforeDecode: before,
                      footprintWithGeometry: result.footprint, footprintAfterGeometryRelease: footprint())
    }

    private static func decodeAndMeasure(_ data: Data, points: [CLLocationCoordinate2D]) throws ->
        (metadata: Metadata, featureCount: Int, polygonCount: Int, ringCount: Int, vertexCount: Int,
         decodeSeconds: Double, containmentSeconds: Double, matches: [[String]], footprint: UInt64?) {
        let clock = ContinuousClock()
        let start = clock.now
        let decoded = try JSONDecoder().decode(Collection.self, from: data)
        guard decoded.type == "FeatureCollection", !decoded.features.isEmpty, !decoded.metadata.product.isEmpty,
              (1...3).contains(decoded.metadata.day), decoded.features.allSatisfy({
                  $0.type == "Feature" && !$0.properties.severity.isEmpty
              }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid feature collection"))
        }
        let decodeSeconds = seconds(start.duration(to: clock.now))
        let featureCount = decoded.features.count
        var polygons = 0, rings = 0, vertices = 0
        for feature in decoded.features {
            polygons += feature.geometry.coordinates.count
            for polygon in feature.geometry.coordinates {
                rings += polygon.rings.count
                vertices += polygon.rings.reduce(0) { $0 + $1.count }
            }
        }
        let metadata = decoded.metadata
        let withGeometry = footprint()
        let containmentStart = clock.now
        let matches = points.map { point in
            decoded.features.filter { $0.geometry.coordinates.contains { $0.contains(point) } }.map(\.properties.severity)
        }
        let containmentSeconds = seconds(containmentStart.duration(to: clock.now))
        return (metadata, featureCount, polygons, rings, vertices, decodeSeconds, containmentSeconds, matches, withGeometry)
    }

    private static func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    private static func footprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : nil
    }
}
#endif
