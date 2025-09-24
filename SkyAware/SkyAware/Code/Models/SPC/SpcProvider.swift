//
//  SpcProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import Observation
import OSLog

@Observable
final class SpcProvider: Sendable {
    //var errorMessage: String?
    var isLoading: Bool = false
    var statusMessage: String? = "Data Loaded"
    
    @ObservationIgnored private let logger = Logger.spcProvider
    @ObservationIgnored private let client: SpcClient
        
    // Domain Models
    var alertCount: Int = 0
    
    var categorical = [CategoricalStormRisk]() // ready to deprecate
    var wind = [SevereThreat]() // ready to deprecate
    var hail = [SevereThreat]() // ready to deprecate
    var tornado = [SevereThreat]() // ready to deprecate
    
    init(client: SpcClient,
         autoLoad: Bool = true) {
        self.client = client

        if autoLoad { loadFeed() }
    }
    
    func loadFeed() {
//        isLoading = true
        
        Task {
            await loadFeedAsync()
            //            await MainActor.run {
            //                ToastManager.shared.showSuccess(title: "SPC data loaded")
            //            }
//            isLoading = false
            statusMessage = "Spc Data Loaded"
        }
    }
    
    /// Loads all the SPC products including RSS and GeoJSON
    func loadFeedAsync() async {
        do {
            // ready to deprecate below
            let points = try await client.refreshPoints()
            
            self.categorical = getTypedFeature(from: points.geo, for: .categorical, transform: CategoricalStormRisk.from)
            self.wind        = getTypedFeature(from: points.geo, for: .wind,        transform: SevereThreat.from)
            self.hail        = getTypedFeature(from: points.geo, for: .hail,        transform: SevereThreat.from)
            self.tornado     = getTypedFeature(from: points.geo, for: .tornado,     transform: SevereThreat.from)
        } catch {
            //self.errorMessage = error.localizedDescription
            logger.error("Error loading Spc feed: \(error.localizedDescription)")
        }
    }

    /// Transforms the GeoJSON into usable features for the map
    /// - Parameters:
    ///   - list: list of GeoJSON result objects to process
    ///   - product: product to classify as
    ///   - transform: the transform description
    /// - Returns: the typed object
    @available(*, deprecated, message: "Replaced in repos")
    private func getTypedFeature<T>(from list: [GeoJsonResult], for product: GeoJSONProduct, transform: (GeoJSONFeature) -> T?) -> [T] {
        guard let features = list.first(where: { $0.product == product })?.featureCollection.features else { return [] }
        return features.compactMap(transform)
    }
}
