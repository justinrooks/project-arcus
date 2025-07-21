//
//  PointsProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/20/25.
//

import Foundation
import Observation
import MapKit

@MainActor
final class PointsProvider: ObservableObject {
    @Published var errorMessage: String?
    @Published var isLoading: Bool = true
    
    @Published var marginal: MKMultiPolygon = MKMultiPolygon([])
    @Published var slight: MKMultiPolygon = MKMultiPolygon([])
    @Published var enhanced: MKMultiPolygon = MKMultiPolygon([])
    @Published var moderate: MKMultiPolygon = MKMultiPolygon([])
    @Published var high: MKMultiPolygon = MKMultiPolygon([])
    
    @Published var tornado: MKMultiPolygon = MKMultiPolygon([])
    @Published var hail: MKMultiPolygon = MKMultiPolygon([])
    @Published var wind: MKMultiPolygon = MKMultiPolygon([])
    
    private let spcClient = SpcClient()
    private var flatPoly: [CLLocationCoordinate2D] = []
    
    init() {
        // MARK: Fetch the US Polygon
        let (_, flat) = loadCONUSBoundaryPolygons(quality: .low)
        flatPoly = flat
    }
    
    func loadPoints() {
        isLoading = true
        
        Task {
            do {
                let result = try await spcClient.fetchPoints()
                
                self.slight = extractCategoricalPolygon(risk: .slgt, points: result.categorical)
                self.marginal = extractCategoricalPolygon(risk: .mrgl, points: result.categorical)
                self.enhanced = extractCategoricalPolygon(risk: .enh, points: result.categorical)
                self.moderate = extractCategoricalPolygon(risk: .mdt, points: result.categorical)
                self.high = extractCategoricalPolygon(risk: .high, points: result.categorical)
                
                self.tornado = result.severe.first(where: { $0.type == .tornado }).map { extractSeverePolygon(risk: $0) } ?? MKMultiPolygon([])
                self.wind = result.severe.first(where: { $0.type == .wind }).map { extractSeverePolygon(risk: $0) } ?? MKMultiPolygon([])
                self.hail = result.severe.first(where: { $0.type == .hail }).map { extractSeverePolygon(risk: $0) } ?? MKMultiPolygon([])
            } catch {
                self.errorMessage = error.localizedDescription
                print(self.errorMessage!)
            }
            
            self.isLoading = false
        }
    }
    
    func extractCategoricalPolygon(risk: ConvectiveRisk, points: [OutlookPolygon]) -> MKMultiPolygon {
        // TODO: Maybe Return an array of the CLLocatoinCoords2d so we can check if location is in each polygon
        // -> (MKMultiPolygon, [CLLocationCoords2d])
        var readyPoints: [MKPolygon] = []
        let riskStr = risk.rawValue.lowercased()
        
        for p in points {
            var pts:[CLLocationCoordinate2D] = p.points
            let category = p.convectiveOutlook.lowercased()
            if category == "tstm" {
#if DEBUG
                print("⚠️ Thunderstorm points not yet supported.")
#endif
                continue
            }
            if category != riskStr { continue }
            
            if(!p.isEnclosed) {
                // We need to find the segment of the US boarder to close the polygon
                // Update the points for the item we are processing
                // Add the updated polygon to the array for rendering
                
                if let closestStartIdx = findClosestFlatBoundaryIndex(to: p.points.first!, in: flatPoly),
                   let closestEndIdx = findClosestFlatBoundaryIndex(to: p.points.last!, in: flatPoly)
                {
#if DEBUG
                    print("Found in polygon, index \(closestStartIdx)")
                    print("Found in polygon, index \(closestEndIdx)")
#endif
                    let arc = walkFlatCONUSArc(from: closestEndIdx, to: closestStartIdx, in: flatPoly)
                    
                    pts[0] = flatPoly[closestStartIdx]
                    pts[pts.count - 1] = flatPoly[closestEndIdx]
#if DEBUG
                    print("Closing arc contains \(arc.count) points")
#endif
                    pts.append(contentsOf: arc)
                }
            }
            
            // MARK: Add to the Array
            let closedPoly = MKPolygon(coordinates: pts, count: pts.count)
            closedPoly.title = p.convectiveOutlook
            
            readyPoints.append(closedPoly)
        }
        
        return MKMultiPolygon(readyPoints)
    }
    
    // MARK: Method to extract a specific type of severe weather polygon, closed or not
    func extractSeverePolygon(risk: SeverePolygon, minimumRisk: Double = 0.01) -> MKMultiPolygon {
        var readyPoints: [MKPolygon] = []
        
        for p in risk.points {
            var pts:[CLLocationCoordinate2D] = p.points
            if(p.probability < minimumRisk) { continue } // MARK: This should be configurable via risk or warning level
            
            if(!p.isEnclosed) {
                // We need to find the segment of the US boarder to close the polygon
                // Update the points for the item we are processing
                // Add the updated polygon to the array for rendering
                
                if let closestStartIdx = findClosestFlatBoundaryIndex(to: p.points.first!, in: flatPoly),
                   let closestEndIdx = findClosestFlatBoundaryIndex(to: p.points.last!, in: flatPoly)
                {
#if DEBUG
                    print("Found in polygon, index \(closestStartIdx)")
                    print("Found in polygon, index \(closestEndIdx)")
#endif
                    let arc = walkFlatCONUSArc(from: closestEndIdx, to: closestStartIdx, in: flatPoly)
                    
                    pts[0] = flatPoly[closestStartIdx]
                    pts[pts.count - 1] = flatPoly[closestEndIdx]
#if DEBUG
                    print("Closing arc contains \(arc.count) points")
#endif
                    pts.append(contentsOf: arc)
                }
            }
            
            // MARK: Add to the Array
            let closedPoly = MKPolygon(coordinates: pts, count: pts.count)
            closedPoly.title = "\(risk.type.rawValue): \(p.probability)"
            
            readyPoints.append(closedPoly)
        }
        
        return MKMultiPolygon(readyPoints)
    }
}
