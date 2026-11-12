import CoreLocation
import Foundation
import OSLog

/// Applicability for the CONUS WSSI adapter, independent of any requested/accepted query envelope.
/// WPC's product domain: https://www.wpc.ncep.noaa.gov/wwd/wssi/PDD_WSSI%202020-2021.pdf
/// The versioned resource contains NOAA NWS state boundaries for the contiguous 48 states and DC.
/// Its source URL reproduces the query; polygons/rings are preserved without local simplification.
/// NOAA generalizes at 0.001 degrees (~110 m): this is an applicability mask, not a survey boundary.
/// Exterior edges are included, holes excluded; no buffer expands coverage into neighboring countries/ocean.
enum WSSISourceApplicability {
    static func scope(at point: Coordinate2D) -> WSSIScope? {
        guard contains(point) else { return nil }
        // Stable regional cells avoid a new acquisition for every small location movement.
        let south = floor(point.latitude / 5) * 5
        let west = floor(point.longitude / 5) * 5
        return try? WSSIScope(south: south, west: west, north: south + 5, east: west + 5)
    }

    static func contains(_ point: Coordinate2D) -> Bool {
        guard point.latitude.isFinite, point.longitude.isFinite,
              (24...50).contains(point.latitude), (-125 ... -66).contains(point.longitude) else { return false }
        return polygons.contains { polygon in
            guard (polygon.south...polygon.north).contains(point.latitude),
                  (polygon.west...polygon.east).contains(point.longitude),
                  let exterior = polygon.rings.first,
                  MesoGeometry.contains(point.location, inRing: exterior) else { return false }
            return polygon.rings.dropFirst().allSatisfy {
                !MesoGeometry.contains(point.location, inRing: $0)
            }
        }
    }

    private struct Boundary: Decodable {
        let states: [String]
        let polygons: [[[[Double]]]]
    }

    private struct Polygon: Sendable {
        let rings: [[CLLocationCoordinate2D]]
        let south: Double
        let west: Double
        let north: Double
        let east: Double

        init(_ coordinates: [[[Double]]]) {
            rings = coordinates.map { $0.map { .init(latitude: $0[1], longitude: $0[0]) } }
            let exterior = coordinates[0]
            south = exterior.map { $0[1] }.min() ?? 90
            north = exterior.map { $0[1] }.max() ?? -90
            west = exterior.map { $0[0] }.min() ?? 180
            east = exterior.map { $0[0] }.max() ?? -180
        }
    }

    private static let polygons: [Polygon] = {
        do {
            guard let url = Bundle.main.url(forResource: "WSSICONUSDomain", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let boundary = try JSONDecoder().decode(Boundary.self, from: Data(contentsOf: url))
            guard Set(boundary.states).count == 49, !boundary.polygons.isEmpty,
                  boundary.polygons.allSatisfy({ polygon in
                      !polygon.isEmpty && polygon.allSatisfy { ring in
                          ring.count >= 4 && ring.first == ring.last && ring.allSatisfy {
                              $0.count == 2 && $0.allSatisfy(\.isFinite)
                          }
                      }
                  }) else { throw CocoaError(.fileReadCorruptFile) }
            return boundary.polygons.map(Polygon.init)
        } catch {
            // Missing/corrupt applicability evidence must never promote a query box into product coverage.
            Logger.appHomeRefresh.error("WSSI CONUS applicability boundary unavailable")
            return []
        }
    }()
}
