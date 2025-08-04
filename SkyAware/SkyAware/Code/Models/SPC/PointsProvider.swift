//
//  PointsProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/20/25.
//

import Foundation
import Observation
import MapKit

import SwiftUI

@MainActor
final class PointsProvider: ObservableObject {
    @Published var errorMessage: String?
    @Published var isLoading: Bool = true
    
    @Published var tornado: MKMultiPolygon = MKMultiPolygon([])
    @Published var hail: MKMultiPolygon = MKMultiPolygon([])
    @Published var wind: MKMultiPolygon = MKMultiPolygon([])
    
    @Published var categorical = MKMultiPolygon([])
    
    @ObservationIgnored private let spcClient = SpcClient()
    
    init() {
        loadPoints()
    }
    
    func loadPoints() {
        isLoading = true
        
        Task {
            do {
                let geoJsonResult = try await spcClient.fetchGeoJson()
                
                self.categorical = getProductFeatures(from: geoJsonResult, for: .categorical)
                self.tornado = getProductFeatures(from: geoJsonResult, for: .tornado)
                self.hail = getProductFeatures(from: geoJsonResult, for: .hail)
                self.wind = getProductFeatures(from: geoJsonResult, for: .wind)
            } catch {
                self.errorMessage = error.localizedDescription
                print(self.errorMessage!)
            }
            
            self.isLoading = false
        }
    }
    
    private func getProductFeatures(from list: [GeoJsonResult],for product: Product) -> MKMultiPolygon {
        let features = list.first(where: {$0.product == product})?.featureCollection.features ?? []
        return createMultiPolygon(from: features, isSevere: product != .categorical)
    }
    
    
    /// Creates the MKMultiPolygon object from the array of GeoJSONFeatures provided
    /// - Parameter features: features from GeoJSON
    /// - Returns: MKMultiPolygon ready for rendering on a map
    private func createMultiPolygon(from features: [GeoJSONFeature], isSevere: Bool = false) -> MKMultiPolygon {
        var polygons: [MKPolygon] = []
        
        for feature in features {
            guard feature.geometry.type == "MultiPolygon" else { continue }
            
            let parsedPolys = feature.geometry.coordinates.flatMap { polygonGroup in
                polygonGroup.map { ring in
                    let coords = ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                    let poly = MKPolygon(coordinates: coords, count: coords.count)
                     poly.title = feature.properties.LABEL2
//                    poly.title = feature.properties.toString()
                    return poly
                }
            }
            
            polygons.append(contentsOf: parsedPolys)
        }
        
        let multi = MKMultiPolygon(polygons)
        multi.title = features.first?.properties.LABEL2 ?? "Risk Area"
        
#if DEBUG
        print("Parsed \(polygons.count) polygons from \(features.count) features")
#endif
        
        return multi
    }
}
