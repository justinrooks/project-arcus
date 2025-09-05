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
    var errorMessage: String?
    var isLoading: Bool = true
    
    @ObservationIgnored private let logger = Logger.spcProvider
    @ObservationIgnored private let client: SpcClient
    @ObservationIgnored private let parser: RSSFeedParser
    
    // Domain Models
    var outlooks: [ConvectiveOutlook] = []
    var meso: [MesoscaleDiscussion] = []
    var watches: [Watch] = []
    var alertCount: Int = 0
    
    var categorical = [CategoricalStormRisk]()
    var wind = [SevereThreat]()
    var hail = [SevereThreat]()
    var tornado = [SevereThreat]()
    
    init(client: SpcClient, parser: RSSFeedParser = RSSFeedParser(), autoLoad: Bool = true) {
        self.client = client
        self.parser = parser
        
        if autoLoad { loadFeed() }
    }

    func loadFeed() {
        isLoading = true
        
        Task {
            _ = await loadFeedAsync()
            isLoading = false
        }
    }
    
    /// Loads all the SPC products including RSS and GeoJSON
    /// - Returns: bool indicating changed
    func loadFeedAsync() async -> Bool {
        do {
            self.outlooks = try await fetchOutlooks()
            self.meso = try await fetchMesoDiscussions()
            self.watches = try await fetchWatches()
            
            logger.debug("Parsed \(self.outlooks.count) outlooks, \(self.meso.count) mesoscale discussions, \(self.watches.count) watches from SPC")
            
            let points = try await refreshPoints()
            
            self.categorical = getTypedFeature(from: points.geo, for: .categorical, transform: CategoricalStormRisk.from)
            self.wind        = getTypedFeature(from: points.geo, for: .wind,        transform: SevereThreat.from)
            self.hail        = getTypedFeature(from: points.geo, for: .hail,        transform: SevereThreat.from)
            self.tornado     = getTypedFeature(from: points.geo, for: .tornado,     transform: SevereThreat.from)
            
            logger.debug("Parsed \(self.wind.count) wind features, \(self.hail.count) hail features, \(self.tornado.count) tornado features from SPC")
            
            return true//res.rssChanged || res.pointsChanged
        } catch {
            self.errorMessage = error.localizedDescription
            logger.error("Error loading Spc feed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Fetches an array of convective outlooks from SPC
    /// - Returns: array of convective outlooks
    func fetchOutlooks() async throws -> [ConvectiveOutlook] {
        logger.info("Refreshing convective outlooks")
        let data = try await client.fetchRssData(for: .convective)
        let items = try getRssItems(data: data)
        
        let outlooks = items
            .filter { ($0.title ?? "").contains(" Convective Outlook") }
            .compactMap { ConvectiveOutlook.from(rssItem: $0) }
        
        return outlooks
    }
    
    /// Fetches an array of meso discussions from SPC
    /// - Returns: array of meso discussions
    func fetchMesoDiscussions() async throws -> [MesoscaleDiscussion] {
        logger.info("Refreshing SPC Meso discussions")
        let data = try await client.fetchRssData(for: .meso)
        let items = try getRssItems(data: data)
        
        let mesos = items
            .filter { ($0.title ?? "").contains("SPC MD ") }
            .compactMap { MesoscaleDiscussion.from(rssItem: $0) }
        
        return mesos
    }
    
    /// Fetches an array of Watches from SPC
    /// - Returns: Array of Watches
    func fetchWatches() async throws -> [Watch] {
        logger.info("Refreshing SPC Watches")
        let data = try await client.fetchRssData(for: .watch)
        let items = try getRssItems(data: data)
        
        let result = items
            .filter {
                guard let t = $0.title else { return false }
                return t.contains("Watch") && !t.contains("Status Reports")
            }
            .compactMap { Watch.from(rssItem: $0) }
        
        return result
    }
    
    /// Processes the provided data object into an array of RSS Items
    /// - Parameter data: optional data to process
    /// - Returns: Array of RSS Items, or empty array
    private func getRssItems(data: Data?) throws -> [Item] {
        guard let data else {
            return []
        }
        
        let rss = try parseRSS(data)
        return rss.channel?.items ?? []
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
    
    /// Fetches the points data for severe weather
    /// - Returns: array of GeoJsonResult and a bool indicating if any of the products changed
    private func refreshPoints() async throws -> (geo: [GeoJsonResult], changed: Bool) {
        logger.debug("Refreshing SPC Points data")
        
        let (cat, cCh)  = try await getGeoJSONData(for: .categorical)
        let (torn, tCh) = try await getGeoJSONData(for: .tornado)
        let (hail, hCh) = try await getGeoJSONData(for: .hail)
        let (wind, wCh) = try await getGeoJSONData(for: .wind)
        
        let changed = cCh || tCh || hCh || wCh
        return ([cat, torn, hail, wind].compactMap{ $0 }, changed)
    }

    /// Tries to get GeoJSON data for the provided product
    /// - Parameter product: the product to query (cat, torn, hail, wind)
    /// - Returns: the GeoJSON result and bool indicating changed or not
    private func getGeoJSONData(for product: GeoJSONProduct) async throws -> (GeoJsonResult?, Bool) {
        logger.debug("Getting GeoJSON for \(product.rawValue)")
        let data = try await client.fetchGeoJsonData(for: product)

        guard let data else {
            return (GeoJsonResult(product: product, featureCollection: .empty), false)
        }
        
        let decoded = decodeGeoJSON(from: data)
        
        return (GeoJsonResult(product: product, featureCollection: decoded), true)
    }
    
    /// Parse RSS data or throw a standard parsing error.
    private func parseRSS(_ data: Data) throws -> RSS {
        guard let rss = try parser.parse(data: data) else {
            throw SpcError.parsingError
        }
        return rss
    }
    
    /// Decodes the provided Data into a GeoJSONFeatureCollection DTO
    /// - Parameter data: data stream to decode
    /// - Returns: a populated GeoJSONFeatureCollection DTO, or empty if there's a decoding error
    private func decodeGeoJSON(from data: Data) -> GeoJSONFeatureCollection {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(GeoJSONFeatureCollection.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            logger.error("GeoJSON decoding failed: Data corrupted – \(context.debugDescription)")
            return .empty
        } catch let DecodingError.keyNotFound(key, context) {
            logger.error("GeoJSON decoding failed: Missing key '\(key.stringValue)' – \(context.debugDescription)")
            return .empty
        } catch let DecodingError.typeMismatch(type, context) {
            logger.error("GeoJSON decoding failed: Type mismatch for type '\(type)' – \(context.debugDescription)")
            return .empty
        } catch let DecodingError.valueNotFound(value, context) {
            logger.error("GeoJSON decoding failed: Missing value '\(value)' – \(context.debugDescription)")
            return .empty
        } catch {
            logger.error("Unexpected GeoJSON decode error: \(error.localizedDescription)")
            return .empty
        }
    }
}
