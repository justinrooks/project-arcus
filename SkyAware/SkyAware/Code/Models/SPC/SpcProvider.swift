//
//  SpcProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import Observation
import OSLog
import SwiftData

@Observable
final class SpcProvider: Sendable {
    //var errorMessage: String?
    var isLoading: Bool = false
    
    @ObservationIgnored private let logger = Logger.spcProvider
    @ObservationIgnored private let client: SpcClient
    @ObservationIgnored private let dba: DatabaseActor
    @ObservationIgnored private let repository: SpcRepo
    
    // Domain Models
    var alertCount: Int = 0
    
    var categorical = [CategoricalStormRisk]() // ready to deprecate
    var wind = [SevereThreat]() // ready to deprecate
    var hail = [SevereThreat]() // ready to deprecate
    var tornado = [SevereThreat]() // ready to deprecate
    
    init(client: SpcClient, container: ModelContainer, autoLoad: Bool = true) {
        self.client = client
        let d = DatabaseActor(modelContainer: container)
        self.dba = d
        self.repository = SpcRepo(client: client, dba: d)
        
        if autoLoad { loadFeed() }
    }
    
    func loadFeed() {
        isLoading = true
        
        Task {
            await loadFeedAsync()
            //            await MainActor.run {
            //                ToastManager.shared.showSuccess(title: "SPC data loaded")
            //            }
            isLoading = false
        }
    }
    
    /// Loads all the SPC products including RSS and GeoJSON
    func loadFeedAsync() async {
        do {
            try await repository.refreshConvectiveOutlooks()
            try await repository.refreshMesoscaleDiscussions()
            try await repository.refreshWatches()
            
            try await repository.refreshStormRisk()
            try await repository.refreshHailRisk()
            try await repository.refreshWindRisk()
            try await repository.refreshTornadoRisk()
            
            // ready to deprecate below
            let points = try await client.refreshPoints()
            
            self.categorical = getTypedFeature(from: points.geo, for: .categorical, transform: CategoricalStormRisk.from)
            self.wind        = getTypedFeature(from: points.geo, for: .wind,        transform: SevereThreat.from)
            self.hail        = getTypedFeature(from: points.geo, for: .hail,        transform: SevereThreat.from)
            self.tornado     = getTypedFeature(from: points.geo, for: .tornado,     transform: SevereThreat.from)
            
            logger.debug("Parsed \(self.wind.count) wind features, \(self.hail.count) hail features, \(self.tornado.count) tornado features from SPC")
        } catch {
            //self.errorMessage = error.localizedDescription
            logger.error("Error loading Spc feed: \(error.localizedDescription)")
        }
    }
    
    func fetchStormRisk() async throws {
        try await repository.refreshStormRisk()
    }
    
    func fetchHailRisk() async throws {
        try await repository.refreshHailRisk()
    }
    
    func fetchWindRisk() async throws {
        try await repository.refreshWindRisk()
    }
    
    func fetchTornadoRisk() async throws {
        try await repository.refreshTornadoRisk()
    }
    
    /// Fetches an array of convective outlooks from SPC
    func fetchOutlooks() async throws {
        try await repository.refreshConvectiveOutlooks()
    }
    
    func fetchMesoDiscussions() async throws {
        try await repository.refreshMesoscaleDiscussions()
    }
    
    /// Fetches an array of Watches from SPC
    func fetchWatches() async throws {
        try await repository.refreshWatches()
    }
    
    /// Transforms the GeoJSON into usable features for the map
    /// - Parameters:
    ///   - list: list of GeoJSON result objects to process
    ///   - product: product to classify as
    ///   - transform: the transform description
    /// - Returns: the typed object
    private func getTypedFeature<T>(from list: [GeoJsonResult], for product: GeoJSONProduct, transform: (GeoJSONFeature) -> T?) -> [T] {
        guard let features = list.first(where: { $0.product == product })?.featureCollection.features else { return [] }
        return features.compactMap(transform)
    }
    
    
    struct OutlookHeader {
        let issued: String
        let valid: String
        let body: String
    }
    
    func parseOutlookHeader(_ text: String) -> OutlookHeader? {
        // Regex for issued (time/date) and valid line
        let issuedPattern = #"(?m)^\d{3,4} [AP]M [A-Z]{2,4} .+$"#
        let validPattern  = #"(?m)^Valid \d{6}Z - \d{6}Z$"#
        
        guard
            let issuedMatch = try? NSRegularExpression(pattern: issuedPattern)
                .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let validMatch = try? NSRegularExpression(pattern: validPattern)
                .firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else {
            return nil
        }
        
        // Extract issued
        let issuedRange = Range(issuedMatch.range, in: text)!
        let issued = String(text[issuedRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract valid
        let validRange = Range(validMatch.range, in: text)!
        let valid = String(text[validRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Body = everything after the valid line
        let bodyStart = validRange.upperBound
        let body = text[bodyStart...].trimmingCharacters(in: .whitespacesAndNewlines)
        
        return OutlookHeader(issued: issued, valid: valid, body: body)
    }
    
}
