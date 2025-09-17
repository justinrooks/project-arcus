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
    
    // Domain Models
    var alertCount: Int = 0
    
    var categorical = [CategoricalStormRisk]()
    var wind = [SevereThreat]()
    var hail = [SevereThreat]()
    var tornado = [SevereThreat]()
    
    init(client: SpcClient, container: ModelContainer, autoLoad: Bool = true) {
        self.client = client
        self.dba = DatabaseActor(modelContainer: container)
        
        if autoLoad { loadFeed() }
    }

    func loadFeed() {
        isLoading = true
        
        Task {
            await loadFeedAsync()
            await MainActor.run {
                ToastManager.shared.showSuccess(title: "SPC data loaded")
            }
                    isLoading = false
        }
    }
    
    /// Loads all the SPC products including RSS and GeoJSON
    /// - Returns: bool indicating changed
    func loadFeedAsync() async {
        do {
            try await fetchOutlooks()
            try await fetchMesoDiscussions()
            try await fetchWatches()
            
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
    
    /// Fetches an array of convective outlooks from SPC
    /// - Returns: array of convective outlooks
    func fetchOutlooks() async throws {
        let items = try await client.fetchOutlookItems()
  
        //TODO: Clean up old outlooks based on valid date
        
        let outlooks = items
            .filter { ($0.title ?? "").contains(" Convective Outlook") }
        
        try await dba.insertConvectiveOutlooks(outlooks)
        logger.debug("Parsed \(outlooks.count) outlooks from SPC")
    }
    
    /// Fetches an array of meso discussions from SPC
    /// - Returns: array of meso discussions
    func fetchMesoDiscussions() async throws {
        let items = try await client.fetchMesoItems()
        
        let mesos = items
            .filter { ($0.title ?? "").contains("SPC MD ") }
        
        try await dba.insertMesos(mesos)
        logger.debug("Parsed \(mesos.count) mesos from SPC")
    }
    
    /// Fetches an array of Watches from SPC
    /// - Returns: Array of Watches
    func fetchWatches() async throws {
        let items = try await client.fetchWatchItems()
        
        let watches = items
            .filter {
                guard let t = $0.title else { return false }
                return t.contains("Watch") && !t.contains("Status Reports")
            }
        try await dba.insertWatches(watches)
        logger.debug("Parsed \(watches.count) watches from SPC")
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
