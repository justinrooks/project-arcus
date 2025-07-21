//
//  SpcClient.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation

struct SpcResult {
    let feedData: RSS
    let pointsData: Points
}

final class SpcClient {
    private let feedURL = URL(string: "https://www.spc.noaa.gov/products/spcrss.xml")!
    private let pointsURL = URL(string: "https://tgftp.nws.noaa.gov/data/raw/wu/wuus01.kwns.pts.dy1.txt")!
    private let parser = RSSFeedParser()
    private let pointsParser = PointsFileParser()
    private let downloader: HTTPDataDownloader = URLSession.shared
    
    func fetchPoints() async throws -> Points {
        async let pointsText = fetchPointsFile()
        
        do {
            let points = try await pointsText
                        
            // Parse the points file into a polygon result
            let polygons = self.pointsParser.parse(content: points)

            return polygons
        } catch {
            throw SpcError.parsingError
        }
    }
    
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
    
    func fetchFeedAndPoints() async throws -> SpcResult {
        async let rssData = fetchRSSFeed()
        async let pointsText = fetchPointsFile()
        
        do {
            let (rss, points) = try await (rssData, pointsText)
            
            // Parse RSS into feed result
            let feedResult = try self.parser.parse(data:rss)
            
            // Parse the points file into a polygon result
            let polygons = self.pointsParser.parse(content: points)

            return SpcResult(feedData: feedResult!, pointsData: polygons)
        } catch {
            throw SpcError.parsingError
        }
    }
    
    private func fetchRSSFeed() async throws -> Data {
        let request = URLRequest(url: feedURL)
        let data = try await downloader.httpData(from: request)
        
        return data
    }
    
    private func fetchPointsFile() async throws -> String {
        let request = URLRequest(url: pointsURL)
        let data = try await downloader.httpData(from: request)
        guard let text = String(data: data, encoding: .utf8) else {
            throw SpcError.parsingError
        }
        
        return text
    }
}
