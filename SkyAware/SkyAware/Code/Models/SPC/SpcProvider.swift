//
//  SpcProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import Observation

@MainActor
@Observable
final class SpcProvider {
    var errorMessage: String?
    var isLoading: Bool = true
    
    @ObservationIgnored private let spcClient = SpcClient()
    
    // Domain Models
    var outlooks: [ConvectiveOutlook] = []
    var meso: [MesoscaleDiscussion] = []
    var watches: [Watch] = []
    var alertCount: Int = 0
    
    var categorical = [CategoricalStormRisk]()
    var wind = [SevereThreat]()
    var hail = [SevereThreat]()
    var tornado = [SevereThreat]()
    
    init() {
        loadFeed()
    }
    
    func loadFeed() {
//        let freshness = SharedPrefs.freshness(thresholdMinutes: 15)
//
//        switch freshness {
//        case .fresh:
//            print("✅ Recent enough, skip auto-refresh")
//            isLoading = false
//            return
//        case .stale:
//            print("⚠️ Refresh recommended")
//        case .neverUpdated:
//            print("🚫 No data yet — must refresh")
//        }
        
        isLoading = true
        
        Task {
            //try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds delay
            async let rssResult = spcClient.fetchRss()
            async let geoJsonResult = spcClient.fetchGeoJson()
            
            do {
                let result = try await rssResult
                self.outlooks = result.channel!.items
                    .filter { $0.title?.contains(" Convective Outlook") == true }
                    .compactMap { ConvectiveOutlook.from(rssItem: $0) }
                
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
                
                self.categorical = getTypedFeature(from: geoResult, for: .categorical, transform: CategoricalStormRisk.from)
                
                self.wind = getTypedFeature(from: geoResult, for: .wind, transform: SevereThreat.from)
                self.hail = getTypedFeature(from: geoResult, for: .hail, transform: SevereThreat.from)
                self.tornado = getTypedFeature(from: geoResult, for: .tornado, transform: SevereThreat.from)
#if DEBUG
                print("Parsed \(self.wind.count) wind features, \(self.hail.count) hail features, \(self.tornado.count) tornado features from SPC")
#endif
            } catch {
                self.errorMessage = error.localizedDescription
                print(error.localizedDescription)
            }
            
            SharedPrefs.recordGlobalSuccess()
            isLoading = false
        }
    }
    
    private func getTypedFeature<T>(from list: [GeoJsonResult], for product: Product, transform: (GeoJSONFeature) -> T?) -> [T] {
        guard let features = list.first(where: { $0.product == product })?.featureCollection.features else { return [] }
        return features.compactMap(transform)
    }
}
