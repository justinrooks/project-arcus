//
//  SpcProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import Observation
import MapKit

@MainActor
//@Observable
final class SpcProvider: ObservableObject {
    var errorMessage: String?
    @Published var isLoading: Bool = true
    
    var outlooks: [SPCConvectiveOutlook] = []
    var meso: [MesoscaleDiscussion] = []
    var watches: [Watch] = []
    var alertCount: Int = 0
    
    @Published var tornado: MKMultiPolygon = MKMultiPolygon([])
    @Published var hail: MKMultiPolygon = MKMultiPolygon([])
    @Published var wind: MKMultiPolygon = MKMultiPolygon([])
    
    @Published var categorical = MKMultiPolygon([])
    
    @ObservationIgnored private let spcClient = SpcClient()
    
    init() {
        loadFeed()
    }
    
    func loadFeed() {
        isLoading = true
        
        Task {
            //try? await Task.sleep(nanoseconds: 3_000_000_000) // 2 seconds delay
            async let rssResult = spcClient.fetchRss()
            async let geoJsonResult = spcClient.fetchGeoJson()

            do {
                let result = try await rssResult
                self.outlooks = result.channel!.items
                    .filter { $0.title?.contains(" Convective Outlook") == true }
                    .compactMap { SPCConvectiveOutlook.from(rssItem: $0) }
                
                self.meso = result.channel!.items
                    .filter { $0.title?.contains("SPC MD ") == true }
                    .compactMap { MesoscaleDiscussion.from(rssItem: $0) }
                
                self.watches = result.channel!.items
                    .filter { $0.title?.contains("Watch") == true && $0.title?.contains("Status Reports") == false }
                    .compactMap { Watch.from(rssItem: $0) }
                
                self.alertCount = self.meso.count + self.watches.count

#if DEBUG
                print("Parsed \(self.outlooks.count) outlooks, \(self.meso.count) mesoscale discussions, \(self.watches.count) watches from SPC")
#endif
                
                let geoResult = try await geoJsonResult
                
                self.categorical = getProductFeatures(from: geoResult, for: .categorical)
                self.tornado = getProductFeatures(from: geoResult, for: .tornado)
                self.hail = getProductFeatures(from: geoResult, for: .hail)
                self.wind = getProductFeatures(from: geoResult, for: .wind)
            } catch {
                self.errorMessage = error.localizedDescription
                print(self.errorMessage)
            }

            isLoading = false
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
