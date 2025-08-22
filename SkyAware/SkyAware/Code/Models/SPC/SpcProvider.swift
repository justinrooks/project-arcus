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
final class SpcProvider {
    var errorMessage: String?
    var isLoading: Bool = true
    @ObservationIgnored let logger = Logger.spcProvider
    
    @ObservationIgnored private let service: SpcService
    
    // Domain Models
    var outlooks: [ConvectiveOutlook] = []
    var meso: [MesoscaleDiscussion] = []
    var watches: [Watch] = []
    var alertCount: Int = 0
    
    var categorical = [CategoricalStormRisk]()
    var wind = [SevereThreat]()
    var hail = [SevereThreat]()
    var tornado = [SevereThreat]()
    
    init(service: SpcService, autoLoad: Bool = true) {
        self.service = service
        if autoLoad { loadFeed() }
    }
    
    func loadFeed() {
        isLoading = true
        
        Task {
            do {
                let res = try await service.refreshAll()
                if res.rssChanged {
                    self.outlooks = res.outlooks
                    self.meso = res.mesos
                    self.watches = res.watches

                    logger.debug("Parsed \(self.outlooks.count) outlooks, \(self.meso.count) mesoscale discussions, \(self.watches.count) watches from SPC")
                }
                if res.pointsChanged {
                    // derive your typed features for the map
                    self.categorical = getTypedFeature(from: res.geo, for: .categorical, transform: CategoricalStormRisk.from)
                    self.wind        = getTypedFeature(from: res.geo, for: .wind,        transform: SevereThreat.from)
                    self.hail        = getTypedFeature(from: res.geo, for: .hail,        transform: SevereThreat.from)
                    self.tornado     = getTypedFeature(from: res.geo, for: .tornado,     transform: SevereThreat.from)

                    logger.debug("Parsed \(self.wind.count) wind features, \(self.hail.count) hail features, \(self.tornado.count) tornado features from SPC")
                }
            } catch {
                self.errorMessage = error.localizedDescription
                logger.error("Error loading Spc feed: \(error.localizedDescription)")
            }
            
            SharedPrefs.recordGlobalSuccess()
            isLoading = false
        }
    }
    
    private func getTypedFeature<T>(from list: [GeoJsonResult], for product: GeoJSONProduct, transform: (GeoJSONFeature) -> T?) -> [T] {
        guard let features = list.first(where: { $0.product == product })?.featureCollection.features else { return [] }
        return features.compactMap(transform)
    }
}
