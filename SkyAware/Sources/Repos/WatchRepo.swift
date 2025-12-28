//
//  WatchRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import SwiftData
import OSLog

@ModelActor
actor WatchRepo {
    private let logger = Logger.watchRepo
    private let parser: RSSFeedParser = RSSFeedParser()
    
    @available(*, deprecated, message: "Migrate to refreshWatchesNws instead")
    func refreshWatches(using client: any SpcClient) async throws {
        let data = try await client.fetchRssData(for: .watch)

        guard let data else {
            logger.info("No severe watches found")
            return
        }
                
        guard let rss = try parser.parse(data: data) else {
            logger.warning("Error parsing severe watch items")
            throw SpcError.parsingError
        }
        
        guard let channel = rss.channel else {
            logger.warning("Watch channel data not found")
            return
        }
        
        // Filters out some odd contents
        let watches = channel.items
            .filter {
                guard let t = $0.title else { return false }
                return t.contains("Watch") && !t.contains("Status Reports")
            }
            .compactMap { makeWatchModel(from: $0) }
        
        try upsert(watches)
        logger.debug("Parsed \(watches.count) watch\(watches.count > 1 ? "es" : "") from SPC")
    }
    
    func active(county: String, zone: String, on date: Date = .now) async throws -> [WatchDTO] {
        logger.info("Fetching current local watches")
//        let pred = #Predicate<Watch> { watch in
//            watch.effective <= date && date <= watch.ends &&
//        }
        let pred = #Predicate<Watch> { _ in true }
        let candidates = try modelContext.fetch(FetchDescriptor(predicate: pred))
        
        var hits: [Watch] = []
        hits.reserveCapacity(candidates.count)
        
        for watch in candidates {
            let ugc = watch.ugcZones
            guard !ugc.isEmpty else { continue }
            
            if ugc.contains(county) || ugc.contains(zone) {
                hits.append(watch)
            }
        }
        
        return hits.map {
                WatchDTO(
                    number: 100,
                    title: $0.headline,
                    link: URL(string:"https://api.weather.gov/alerts/\($0.nwsId)")!,
                    issued: $0.issued,
                    validStart: $0.effective,
                    validEnd: $0.ends,
                    summary: $0.watchDescription,
                    type: $0.event
                )
        }
    }
        
    func refreshWatchesNws(using client: any NwsClient, for location: Coordinate2D) async throws {
        let data = try await client.fetchActiveAlertsJsonData(for: location)
        
//        let x = WatchModel.buildNwsTornadoSample()
//        if let coded:Data = x.data(using: .utf8) {
//            let testingCode = NWSWatchParser.decode(from: coded)
//            let count = testingCode?.features?.count ?? 0
//        }
//        let jsonString = """
//        {
//          "type": "FeatureCollection",
//          "features": []
//        }
//        """
//
//        guard let data = jsonString.data(using: .utf8) else {
//            fatalError("Failed to create Data from JSON string")
//        }
        
        guard let data else {
            logger.debug("No watch data found")
            return
        }
        
        guard let decoded = NWSWatchParser.decode(from: data) else {
            logger.debug("Unable to parse NWS Json watch data")
            throw NwsError.parsingError
        }
        
        guard let features = decoded.features else {
            logger.debug("No NWS watch features found")
            return
        }
        
        let watches = features
            .compactMap { makeWatch(from: $0) }
        
        try upsert(watches)
        logger.debug("Parsed \(watches.count) watch\(watches.count > 1 ? "es" : "") from NWS")
    }
    
    /// Removes any expired watches from the database
    func purgeNwsWatches(asOf now: Date = .init()) throws {
        logger.info("Purging expired NWS watches")
        
        // Fetch in batches to avoid large in-memory sets
        let predicate = #Predicate<Watch> { $0.ends < now }
        var desc = FetchDescriptor<Watch>(predicate: predicate)
        desc.fetchLimit = 50
        
        while true {
            let batch = try modelContext.fetch(desc)
            if batch.isEmpty { break }
            logger.debug("Found \(batch.count) watches to purge")
            
            for obj in batch { modelContext.delete(obj) }
            
            try modelContext.save()
        }
        
        logger.info("Expired watches purged")
    }
    
    /// Removes any expired mesoscale discussions from datastore
    /// - Parameter now: defaults to now
    @available(*, deprecated, message: "Migrate to purge1 instead")
    func purgeSpcWatches(asOf now: Date = .init()) throws {
        logger.info("Purging expired watches")
        
        // Fetch in batches to avoid large in-memory sets
        let predicate = #Predicate<WatchModel> { $0.validEnd < now }
        var desc = FetchDescriptor<WatchModel>(predicate: predicate)
        desc.fetchLimit = 50
        
        while true {
            let batch = try modelContext.fetch(desc)
            if batch.isEmpty { break }
            logger.debug("Found \(batch.count) to purge")
            
            for obj in batch { modelContext.delete(obj) }
            
            try modelContext.save()
        }
        
        logger.info("Expired watches purged")
    }
    
    private func makeWatch(from item: NWSWatchFeatureDTO) -> Watch? {
        guard
            let ugcZones         = item.properties.geocode?.ugc,
            let sameCodes        = item.properties.geocode?.same,
            let sent             = item.properties.sent,
            let effective        = item.properties.effective,
            let onset            = item.properties.onset,
            let expires          = item.properties.expires,
            let ends             = item.properties.ends,
            let status           = item.properties.status,
            let messageType      = item.properties.messageType,
            let severity         = item.properties.severity,
            let certainty        = item.properties.certainty,
            let urgency          = item.properties.urgency,
            let event            = item.properties.event,
            let headline         = item.properties.headline,
            let watchDescription = item.properties.description
        else {
            logger.debug("Required watch property missing, returning null.")
            return nil
        }
        
        return .init(
            nwsId: item.properties.id,
            areaDesc: item.properties.areaDesc,
            ugcZones: ugcZones,
            sameCodes: sameCodes,
            sent: sent,
            effective: effective,
            onset: onset,
            expires: expires,
            ends: ends,
            status: status,
            messageType: messageType,
            severity: severity,
            certainty: certainty,
            urgency: urgency,
            event: event,
            headline: headline,
            watchDescription: watchDescription
        )
    }
    
    @available(*, deprecated, message: "Migrate to makeWatch instead")
    private func makeWatchModel(from rssItem: Item) -> WatchModel? {
        guard
            let title = rssItem.title,
            let linkString = rssItem.link,
            let link = URL(string: linkString),
            let pubDateString = rssItem.pubDate,
            let summary = rssItem.description,
            let issued = pubDateString.fromRFC822()
        else { return nil }
        
        let wwNumber = WatchParser.parseWatchNumber(from: link) ?? {
            // Fallback: try to read from title if present
            if let r = title.range(of: #"\b(\d{3,4})\b"#, options: .regularExpression) { return Int(title[r]) } else { return nil }
        }() ?? -1
        
        // Valid range (UTC), fallback to issued+2h if missing
        let validPair = WatchParser.parseValid(summary, issued: issued)
        let validStart = validPair?.0 ?? issued
        let validEnd   = validPair?.1 ?? Calendar.current.date(byAdding: .hour, value: 2, to: issued)!
        
        return WatchModel(
            number: wwNumber,
            title: title,
            link: link,
            issued: issued,
            validStart: validStart,
            validEnd: validEnd,
            summary: summary,
            alertType: .watch
        )
    }
    
    private func upsert(_ items: [Watch]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }
    
    @available(*, deprecated, message: "Migrate to Watch instead")
    private func upsert(_ items: [WatchModel]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }
}
