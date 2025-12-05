//
//  MesoRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import SwiftData
import CoreLocation
import OSLog

@ModelActor
actor MesoRepo {
    private let logger = Logger.mesoRepo
    private let parser: RSSFeedParser = RSSFeedParser()
 
    func refreshMesoscaleDiscussions(using client: SpcClient) async throws {
        let data = try await client.fetchRssData(for: .meso)

        guard let data else {
            logger.warning("No mesoscale discussions found")
            return
        }
                
        guard let rss = try parser.parse(data: data) else {
            throw SpcError.parsingError
        }
        
        guard let channel = rss.channel else {
            logger.warning("Error parsing mesoscale items")
            return
        }
        
        // Filters out some odd contents
        let mesos = channel.items
            .filter { ($0.title ?? "").contains("SPC MD ") }
            .compactMap { makeMD(from: $0) }
        
        try upsert(mesos)
        logger.debug("Parsed \(mesos.count) meso discussion\(mesos.count > 1 ? "s" : "") from SPC")
    }
    
    func active(at date: Date, point: CLLocationCoordinate2D) throws -> [MdDTO] {
        logger.info("Fetching current local mesos")
        
        // Filter by our rough box
        let lat = point.latitude
        let lon = point.longitude
        
        let pred = #Predicate<MD> {md in
            md.validStart <= date && date <= md.validEnd &&
            (md.minLat ?? 91.0) <= lat && lat <= (md.maxLat ?? -91.0) &&
            (md.minLon ?? 181.0) <= lon && lon <= (md.maxLon ?? -181.0)
        }
        
        let candidates = try modelContext.fetch(FetchDescriptor(predicate: pred))
        
        var hits: [MD] = []
        hits.reserveCapacity(candidates.count)
        
        for md in candidates {
            let ring = md.ringCoordinates
            guard !ring.isEmpty else { continue }
            if MesoGeometry.contains(point, inRing: ring) {
                hits.append(md)
            }
        }
        
        return hits.map {
            MdDTO(
                number: $0.number,
                title: $0.title,
                link: $0.link,
                issued: $0.issued,
                validStart: $0.validStart,
                validEnd: $0.validEnd,
                areasAffected: $0.areasAffected,
                summary: $0.summary,
                watchProbability: $0.watchProbability,
                threats: $0.threats,
                coordinates: $0.coordinates
            )
        }
    }
    
    func getLatestMapData(asOf date: Date = .init()) throws -> [MdDTO] {
        // 1) Fetch only risks that are currently valid
        let pred = #Predicate<MD> { $0.validStart <= date && date < $0.validEnd }
        var desc = FetchDescriptor<MD>(predicate: pred)
        desc.sortBy = [SortDescriptor(\.issued, order: .reverse)]
        
        let risks = try modelContext.fetch(desc)
        
        // 2) Sort by descending risk so we can early-exit on first hit
//        let bySeverity = risks.sorted { $0.riskLevel > $1.riskLevel }
    
        return risks.map {
            MdDTO(
                number: $0.number,
                title: $0.title,
                link: $0.link,
                issued: $0.issued,
                validStart: $0.validStart,
                validEnd: $0.validEnd,
                areasAffected: $0.areasAffected,
                summary: $0.summary,
                watchProbability: $0.watchProbability,
                threats: $0.threats,
                coordinates: $0.coordinates
            )
        }
        
//        return bySeverity.map {
//            StormRiskDTO(riskLevel: $0.riskLevel,
//                         issued: $0.issued,
//                         expires: $0.expires,
//                         valid: $0.valid,
//                         polygons: $0.polygons)
//        }
    }
    
    
    /// Removes any expired mesoscale discussions from datastore
    /// - Parameter now: defaults to now
    func purge(asOf now: Date = .init()) throws {
        logger.info("Purging expired mesos")
        
        // Fetch in batches to avoid large in-memory sets
        let predicate = #Predicate<MD> { $0.validEnd < now }
        var desc = FetchDescriptor<MD>(predicate: predicate)
        desc.fetchLimit = 50
        
        while true {
            let batch = try modelContext.fetch(desc)
            if batch.isEmpty { break }
            logger.debug("Found \(batch.count) to purge")
            
            for obj in batch { modelContext.delete(obj) }
            
            try modelContext.save()
        }
        
        logger.info("Expired mesos purged")
    }
    
    private func upsert(_ items: [MD]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }
    
    private func makeMD(from rssItem: Item) -> MD? {
        guard
            let title = rssItem.title,
            let linkString = rssItem.link,
            let link = URL(string: linkString),
            let pubDateString = rssItem.pubDate,
            let rawText = rssItem.description, // SPC MD free text lives here in your feed
            let issued = pubDateString.fromRFC822()
        else { return nil }

        let mdNumber = MDParser.parseMDNumber(from: link) ?? {
            // Fallback: try to read from title if present
            if let r = title.range(of: #"\b(\d{3,4})\b"#, options: .regularExpression) { return Int(title[r]) } else { return nil }
        }() ?? -1

        // Areas / Summary (block captures)
        let areasAffected = MDParser.parseAreas(rawText)
//        let summaryParsed = MDParser.parseSummary(rawText)

        // Valid range (UTC), fallback to issued+2h if missing
        let validPair = MDParser.parseValid(rawText, issued: issued)
        let validStart = validPair?.0 ?? issued
        let validEnd   = validPair?.1 ?? Calendar.current.date(byAdding: .hour, value: 2, to: issued)!

        // Watch probability + concerning
        let (watchProb, concerningLine) = MDParser.parseWatchFields(rawText)

        // Threats
        let windMPH  = MDParser.parseWindMPH(rawText)
        let hailRng  = MDParser.parseHailRange(rawText)
        let torText  = MDParser.parseTornadoStrength(rawText)

        let threats = MDThreats(
            peakWindMPH: windMPH,
            hailRangeInches: hailRng,
            tornadoStrength: torText
        )
        
        let coordinates = MesoGeometry.coordinates(from: rawText) ?? []
        let m = coordinates.compactMap(Coordinate2D.init)
        
        return MD(
            number: mdNumber,
            title: title,
            link: link,
            issued: issued,
            validStart: validStart,
            validEnd: validEnd,
            areasAffected: areasAffected,
            summary: rawText, //summaryParsed.isEmpty ? rawText : summaryParsed,
            concerning: concerningLine,
            watchProbability: watchProb,
            threats: threats,
            coordinates: m,
            alertType: .mesoscale
        )
    }
}
