//
//  MesoRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import ArcusCore
import SwiftData
import CoreLocation
import OSLog

@ModelActor
actor MesoRepo {
    private let logger = Logger.reposMeso
    private let parser: RSSFeedParser = RSSFeedParser()

    /// Targeted acceptance never writes a HomeProjection or marks an H3 collection complete.
    func acceptNotificationMeso(_ meso: MesoscaleDiscussionPayload, at date: Date) throws -> MesoscaleDiscussionPayload? {
        guard meso.validStart <= date, date < meso.validEnd else { return nil }
        let number = meso.number
        let existing = try modelContext.fetch(FetchDescriptor<MD>(predicate: #Predicate { $0.number == number })).first
        if let existing, existing.issued > meso.issued || payload(from: existing) == meso {
            return try notificationMeso(productID: meso.productID, at: date)
        }
        guard let model = MD(from: MdDTO(payload: meso)) else { return nil }
        do {
            modelContext.insert(model)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
        return try notificationMeso(productID: meso.productID, at: date)
    }

    func notificationMeso(productID: String, at date: Date) throws -> MesoscaleDiscussionPayload? {
        guard let suffix = productID.split(separator: "-").last, let number = Int(suffix) else { return nil }
        let models = try modelContext.fetch(FetchDescriptor<MD>(predicate: #Predicate { $0.number == number }))
        guard let model = models.first, model.validStart <= date, date < model.validEnd else { return nil }
        let meso = payload(from: model)
        return meso.productID == productID ? meso : nil
    }
 
    @discardableResult
    func refreshMesoscaleDiscussions(using client: SpcClient) async throws -> HTTPResponse.Source {
        let response = try await client.fetchRssResponse(for: .meso)
        guard let data = response.data else { throw SpcError.missingData }
                
        guard let rss = try parser.parse(data: data) else {
            throw SpcError.parsingError
        }
        
        guard let channel = rss.channel else {
            logger.error("Mesoscale RSS parsed without a channel")
            throw SpcError.parsingError
        }
        
        let recognizedMesos = channel.items
            .filter { ($0.title ?? "").contains("SPC MD ") }
        let mesos = recognizedMesos.compactMap { makeMD(from: $0) }

        guard mesos.count == recognizedMesos.count else {
            logger.error("Mesoscale RSS contained malformed recognized discussions")
            throw SpcError.parsingError
        }

        guard response.source == .live || response.source == .cacheRevalidated304 else {
            logger.notice("Ignored non-authoritative mesoscale response source=\(String(describing: response.source), privacy: .public)")
            return response.source
        }
        
        try upsert(mesos)
        logger.debug("Persisted mesoscale discussion refresh count=\(mesos.count, privacy: .public)")
        return response.source
    }
    
    func active(at date: Date, point: CLLocationCoordinate2D) throws -> [MesoscaleDiscussionPayload] {
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
        let dtos = hits.map { payload(from: $0) }
        logger.debug(
            "Resolved active mesos from datastore candidates=\(candidates.count, privacy: .public) matches=\(dtos.count, privacy: .public)"
        )
        return dtos
    }
    
    func getLatestMapData(asOf date: Date = .init()) throws -> [MesoscaleDiscussionPayload] {
        // 1) Fetch only risks that are currently valid
        let pred = #Predicate<MD> { $0.validStart <= date && date <= $0.validEnd }
        var desc = FetchDescriptor<MD>(predicate: pred)
        desc.sortBy = [SortDescriptor(\.issued, order: .reverse)]
        
        let risks = try modelContext.fetch(desc)
        
        // 2) Sort by descending risk so we can early-exit on first hit
//        let bySeverity = risks.sorted { $0.riskLevel > $1.riskLevel }
    
        return risks.map(payload(from:))
        
//        return bySeverity.map {
//            StormRiskDTO(riskLevel: $0.riskLevel,
//                         issued: $0.issued,
//                         expires: $0.expires,
//                         valid: $0.valid,
//                         polygons: $0.polygons)
//        }
    }

    private func payload(from md: MD) -> MesoscaleDiscussionPayload {
        let probabilityText = md.watchProbability.trimmingCharacters(in: .whitespacesAndNewlines)
        return MesoscaleDiscussionPayload(
            number: md.number,
            title: md.title,
            sourceURL: md.link,
            issued: md.issued,
            validStart: md.validStart,
            validEnd: md.validEnd,
            areasAffected: md.areasAffected,
            summary: md.summary,
            concerning: md.concerning,
            watchProbability: Double(probabilityText.replacingOccurrences(of: "%", with: "")),
            watchProbabilityText: probabilityText,
            threats: md.threats.map {
                MesoscaleDiscussionThreats(
                    peakWindMPH: $0.peakWindMPH,
                    hailRangeInches: $0.hailRangeInches,
                    tornadoStrength: $0.tornadoStrength
                )
            },
            coordinates: md.coordinates.map {
                MesoscaleDiscussionCoordinate(latitude: $0.latitude, longitude: $0.longitude)
            }
        )
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
            logger.debug("Found \(batch.count, privacy: .public) to purge")
            
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
            let scheme = link.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            link.host != nil,
            let pubDateString = rssItem.pubDate,
            let rawText = rssItem.description, // SPC MD free text lives here in your feed
            let issued = pubDateString.fromRFC822(),
            let validPair = MDParser.parseValid(rawText, issued: issued)
        else { return nil }

        guard let mdNumber = MDParser.parseMDNumber(from: link) ?? {
            // Fallback: try to read from title if present
            if let r = title.range(of: #"\b(\d{3,4})\b"#, options: .regularExpression) { return Int(title[r]) } else { return nil }
        }() else {
            return nil
        }

        // Areas / Summary (block captures)
        let areasAffected = MDParser.parseAreas(rawText)
//        let summaryParsed = MDParser.parseSummary(rawText)

        let validStart = validPair.0
        let validEnd = validPair.1

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
