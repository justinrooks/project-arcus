//
//  MkGeoJSONDecoder.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import MapKit
import CoreLocation

// TODO: This is expensive potentially, we need to generate once the first time, then
//       cache the result and refer to it going forward
// TODO: Create a one time setup flow

// MARK: Used to determine which CONUS quality file to use
enum BoundaryQuality: String {
    case high,
         medium,
         low
}

// MARK: Discover CONUS boundary
func loadCONUSBoundaryPolygons(quality: BoundaryQuality = .low) -> ([MKPolygon], [CLLocationCoordinate2D]) {
    let qualityFile:String // Low by default
    
    switch quality
    {
    case .high:
        qualityFile = "CONUS_cleaned_high"
        break
    case .medium:
        qualityFile = "CONUS_cleaned_medium"
        break
    case .low:
        qualityFile = "CONUS_cleaned"
        break
    }
    
    guard let url = Bundle.main.url(forResource: qualityFile, withExtension: "geojson"),
          let data = try? Data(contentsOf: url),
          let features = try? MKGeoJSONDecoder().decode(data)
    else {
        print("Failed to load CONUS GeoJSON")
        return ([],[])
    }
    
    var polygons: [MKPolygon] = []
    
    for feature in features {
        guard let feature = feature as? MKGeoJSONFeature else { continue }
        
        for geometry in feature.geometry {
            if let polygon = geometry as? MKPolygon {
                polygons.append(polygon)
            }
            
            // Handle MultiPolygon manually
            else if let multiPolygon = geometry as? MKMultiPolygon {
                polygons.append(contentsOf: multiPolygon.polygons)
            }
        }
    }
    
    // Just flatten it and return a tuple. May not need the tuple, but useful example right now
    return (polygons, flattenCONUSBoundary(polygons))
}

private func flattenCONUSBoundary(_ polygons: [MKPolygon]) -> [CLLocationCoordinate2D] {
    var flat: [CLLocationCoordinate2D] = []
    
    for polygon in polygons {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polygon.pointCount)
        polygon.getCoordinates(&coords, range: NSRange(location: 0, length: polygon.pointCount))
        flat.append(contentsOf: coords)
    }
    
    return flat
}







struct BoundaryPoint {
    let coordinate: CLLocationCoordinate2D
    let polygonIndex: Int
    let pointIndex: Int
    let distance: CLLocationDistance
}

func findClosestFlatBoundaryIndex(
    to target: CLLocationCoordinate2D,
    in flatBoundary: [CLLocationCoordinate2D]
) -> Int? {
    guard !flatBoundary.isEmpty else { return nil }
    
    var closestIndex: Int = 0
    var closestDistance = CLLocationDistance.greatestFiniteMagnitude
    
    for (i, coord) in flatBoundary.enumerated() {
        let distance = CLLocation(latitude: target.latitude, longitude: target.longitude)
            .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        
        if distance < closestDistance {
            closestDistance = distance
            closestIndex = i
        }
    }
    
    return closestIndex
}

func findClosestBoundaryPoint(
    to target: CLLocationCoordinate2D,
    in boundaryPolygons: [MKPolygon]
) -> BoundaryPoint? {
    var closest: BoundaryPoint?
    
    for (polygonIndex, polygon) in boundaryPolygons.enumerated() {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polygon.pointCount)
        polygon.getCoordinates(&coords, range: NSRange(location: 0, length: polygon.pointCount))
        
        for (pointIndex, coord) in coords.enumerated() {
            let dist = CLLocation(latitude: target.latitude, longitude: target.longitude)
                .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
            
            if closest == nil || dist < closest!.distance {
                closest = BoundaryPoint(
                    coordinate: coord,
                    polygonIndex: polygonIndex,
                    pointIndex: pointIndex,
                    distance: dist
                )
            }
        }
    }
    
    return closest
}

func walkCONUSBoundarySegment(
    from start: BoundaryPoint,
    to end: BoundaryPoint,
    in polygons: [MKPolygon]
) -> [CLLocationCoordinate2D] {
    guard start.polygonIndex == end.polygonIndex else {
        print("Cross-polygon walking not implemented yet")
        return []
    }
    
    let polygon = polygons[start.polygonIndex]
    var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polygon.pointCount)
    polygon.getCoordinates(&coords, range: NSRange(location: 0, length: polygon.pointCount))
    
    let pointCount = coords.count
    
    // Walk from start to end index, wrapping around if needed
    var segment: [CLLocationCoordinate2D] = []
    
    var index = start.pointIndex
    repeat {
        segment.append(coords[index])
        index = (index + 1) % pointCount
    } while index != end.pointIndex
    
    // Include the final end point
    segment.append(coords[end.pointIndex])
    
    return segment
}

func walkFlatCONUSArc(
    from startIndex: Int,
    to endIndex: Int,
    in boundary: [CLLocationCoordinate2D]
) -> [CLLocationCoordinate2D] {
    var result: [CLLocationCoordinate2D] = []
    var index = startIndex
    let count = boundary.count
    
    repeat {
        result.append(boundary[index])
        index = (index + 1) % count
    } while index != endIndex
    
    result.append(boundary[endIndex])
    return result
}
