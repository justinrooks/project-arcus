//
//  SpcClient.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation

enum Product: String {
    case categorical = "cat" // this corresponds to the url builder, see buildUrl func below
    case tornado = "torn"
    case hail = "hail"
    case wind = "wind"
}

final class SpcClient {
    private let feedURL = URL(string: "https://www.spc.noaa.gov/products/spcrss.xml")!
        
    private let parser = RSSFeedParser()
    private let downloader: HTTPDataDownloader = URLSession.shared
    
    func fetchGeoJson() async throws -> [GeoJsonResult] {
        async let categoricalJson = fetchGeoJsonFile(for: .categorical)
        async let tornadoJson = fetchGeoJsonFile(for: .tornado)
        async let hailJson = fetchGeoJsonFile(for: .hail)
        async let windJson = fetchGeoJsonFile(for: .wind)
        
        do {
            let (categoricalData, tornadoData, hailData, windData) = try await (categoricalJson, tornadoJson, hailJson, windJson)
            
            async let categoricalJob = try decodeGeoJSON(from: categoricalData)
            async let tornadoJob = try decodeGeoJSON(from: tornadoData)
            async let windJob = try decodeGeoJSON(from: windData)
            async let hailJob = try decodeGeoJSON(from: hailData)
            
            let (categorical, tornado, hail, wind) = try await (categoricalJob, tornadoJob, hailJob, windJob)
            
            return [
                GeoJsonResult(product: .categorical, featureCollection: categorical),
                GeoJsonResult(product: .tornado, featureCollection: tornado),
                GeoJsonResult(product: .hail, featureCollection: hail),
                GeoJsonResult(product: .wind, featureCollection: wind)
            ]
            
        } catch {
            throw SpcError.missingData
        }
    }

    
    /// Fetches RSS from the SPC site
    /// - Returns: a RSS object for processing
    func fetchRss() async throws -> RSS {
        async let rssData = fetchRSSFeed()
        
        do {
            let rss = try await rssData
            
            // Parse RSS into feed result
            let feedResult = try self.parser.parse(data:rss)

            return feedResult!
        } catch {
            throw SpcError.parsingError
        }
    }
        
    private func fetchGeoJsonFile(for product: Product) async throws -> Data {
        let productUrl = try buildUrl(for: product)
        let request = URLRequest(url: productUrl)
        let data = try await downloader.httpData(from: request)
        
        return data
    }
    
    private func fetchRSSFeed() async throws -> Data {
        let request = URLRequest(url: feedURL)
        let data = try await downloader.httpData(from: request)
        
        return data
    }
    
    private func buildUrl(for product: Product) throws -> URL {
        let url = URL(string:"https://www.spc.noaa.gov/products/outlook/day1otlk_\(product.rawValue).lyr.geojson")
        
        guard let finalUrl = url else {
            throw SpcError.invalidUrl
        }
        
        return finalUrl
    }
    
    private func decodeGeoJSON(from data: Data) async throws -> GeoJSONFeatureCollection {
        let decoder = JSONDecoder()
        return try decoder.decode(GeoJSONFeatureCollection.self, from: data)
    }
}
