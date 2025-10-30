//
//  MesoGeometry.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/8/25.
//

import Foundation
import MapKit

// MARK: - Meso polygon (single-ring) extraction

enum MesoGeometry {
    /// Parse a single polygon from the MD text using all 8-digit LAT/LON points after `LAT...LON`.
    /// Assumes the sequence represents one closed ring (final point may repeat the first).
    static func coordinates(from rawText: String) -> [CLLocationCoordinate2D]? {
        // Regex that starts after "LAT...LON" and collects all 8-digit tokens (across lines)
        let reLatLonBlock = try! Regex(#"(?is)LAT\.\.\.LON\s+([0-9\s]+)"#)
        let rePoint = try! Regex(#"\b\d{8}\b"#)
        // Treat any all-9 token of length 5..8 as a break (e.g., 99999, 999999, 99999999)
        let reBreak = try! Regex(#"^9{5,8}$"#)
        
        // Find the numeric block after LAT...LON
        guard let blockMatch = rawText.firstMatch(of: reLatLonBlock),
              let r = blockMatch.output[1].range else { return nil }
        let block = String(rawText[r])

        // Collect all 8-digit tokens in order
        var tokens: [String] = block.matches(of: rePoint).map { String(block[$0.range]) }
        guard tokens.count >= 3 else { return nil }

        // Drop any break markers (all 9s of length 5-8)
        tokens.removeAll { $0.wholeMatch(of: reBreak) != nil }
        guard tokens.count >= 3 else { return nil }

        // Ensure closed ring: last equals first
        if let first = tokens.first, tokens.last != first { tokens.append(first) }

        // Map to coordinates and validate (triangle + repeat)
        let coords: [CLLocationCoordinate2D] = tokens.compactMap { parseForecastCoordinate($0) }
        guard coords.count >= 4 else { return nil }

        return coords
    }

    // MARK: - Helpers

    private static func parseForecastCoordinate(_ raw: String) -> CLLocationCoordinate2D? {
        guard raw.count == 8,
              let latHundo = Double(raw.prefix(4)),
              let lonHundo = Double(raw.suffix(4)) else {
            return nil
        }
        
        let lat = latHundo / 100.0
        let lonRaw = lonHundo / 100.0
        
        // If longitude is less than 60, it's likely missing a digit (e.g., 0288 → 102.88)
        let lon = (lonRaw < 60.0) ? -(100.0 + lonRaw) : -lonRaw
        
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    
    
    // MARK: Ray-casting
    /// Even–odd ray-cast test. Treats “on edge” as inside.
    static func contains(_ p: CLLocationCoordinate2D, inRing ring: [CLLocationCoordinate2D]) -> Bool {
        guard ring.count > 2 else { return false }
        
        let x = p.longitude, y = p.latitude
        var inside = false
        var j = ring.count - 1
        
        for i in 0..<ring.count {
            let xi = ring[i].longitude, yi = ring[i].latitude
            let xj = ring[j].longitude, yj = ring[j].latitude
            
            let intersects = ((yi > y) != (yj > y)) &&
            (x < (xj - xi) * (y - yi) / ((yj - yi) != 0 ? (yj - yi) : 1e-15) + xi)
            if intersects { inside.toggle() }
            j = i
        }
        return inside || onEdge(p, ring: ring)
    }
    
    private static func onEdge(_ p: CLLocationCoordinate2D, ring: [CLLocationCoordinate2D]) -> Bool {
        guard ring.count > 1 else { return false }
        let px = p.longitude, py = p.latitude
        for i in 0..<ring.count {
            let a = ring[i], b = ring[(i + 1) % ring.count]
            if colinearAndBetween(px, py, a.longitude, a.latitude, b.longitude, b.latitude) { return true }
        }
        return false
    }
    
    private static func colinearAndBetween(_ px: Double, _ py: Double,
                                           _ ax: Double, _ ay: Double,
                                           _ bx: Double, _ by: Double) -> Bool {
        let area = (bx - ax) * (py - ay) - (by - ay) * (px - ax)
        if abs(area) > 1e-12 { return false }
        let minx = min(ax, bx) - 1e-12, maxx = max(ax, bx) + 1e-12
        let miny = min(ay, by) - 1e-12, maxy = max(ay, by) + 1e-12
        return (px >= minx && px <= maxx && py >= miny && py <= maxy)
    }
    
}
