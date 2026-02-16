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
    private let logger = Logger.reposWatch
    
    func active(county: String, zone: String, on date: Date = .now) async throws -> [WatchRowDTO] {
        logger.info("Fetching current local watches for \(county, privacy: .public), \(zone, privacy: .public)")
        
//        let candidates = try modelContext.fetch(allWatchesDescriptor())
        let candidates = try modelContext.fetch(currentWatchesDescriptor())
        
        var hits: [Watch] = []
        hits.reserveCapacity(candidates.count)
        
        for watch in candidates {
            let ugc = watch.ugcZones
            guard !ugc.isEmpty else { continue }
            
            if ugc.contains(county) || ugc.contains(zone) {
                hits.append(watch)
            }
        }
        
        return hits.map { WatchRowDTO.init(from: $0) }
    }
    
    func refresh(using client: any NwsClient, for location: Coordinate2D) async throws {
        let data = try await client.fetchActiveAlertsJsonData(for: location)

        guard let decoded = NWSWatchParser.decode(from: data) else {
            logger.error("Unable to parse NWS Json watch data")
            throw NwsError.parsingError
        }
        
        guard var features = decoded.features else {
            logger.debug("No NWS watch features found")
            return
        }
        
#if DEBUG
        // Temporarily we are injecting a sample tornado watch
        // this can eventually go away, but may be valuable.
        let x = Watch.buildNwsTornadoSample()
        if let coded: Data = x.data(using: .utf8),
           let slug = NWSWatchParser.decode(from: coded),
           let sample = slug.features?.first {
            features.append(sample)
        } else {
            logger.debug("Sample watch injection failed to decode")
        }
#endif // DEBUG
        let watches = features
            .compactMap { makeWatch(from: $0) }
        
        try upsert(watches)
        logger.debug("Parsed \(watches.count, privacy: .public) watch\(watches.count > 1 ? "es" : "", privacy: .public) from NWS")
    }
    
    /// Removes any expired watches from the database
    func purge(asOf now: Date = .init()) throws {
        logger.info("Purging expired NWS watches")
        
        let expired = try modelContext.fetch(expiredWatchesDescriptor(asOf: now))
        if expired.isEmpty {
            logger.debug("No expired watches to purge")
            return
        }
        
        logger.debug("Found \(expired.count, privacy: .public) watches to purge")
        for obj in expired { modelContext.delete(obj) }
        try modelContext.save()
        
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
            let watchDescription = item.properties.description,
            let sender           = item.properties.senderName,
            let instruction      = item.properties.instruction,
            let response         = item.properties.response
        else {
            logger.debug("Required watch property missing, returning null.")
            return nil
        }
        
        let vtec = item.properties.parameters?["VTEC"]?.first ?? ""
        let vtecP = vtec.parseVTEC()
        let key = vtecP?.eventKey
        
        return .init(
            nwsId: key ?? item.properties.id, // Uses vtec as a key, if we don't have a vtec, then fall back to messasge id
            messageId: item.properties.id,
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
            watchDescription: watchDescription,
            sender: sender,
            instruction: instruction,
            response: response
        )
    }
    
    private func upsert(_ items: [Watch]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }
    
    /// Returns a descriptor that filters watches that active
    /// - Parameter date: current date
    /// - Returns: fetch descriptor
    private func currentWatchesDescriptor(date: Date = .now) -> FetchDescriptor<Watch> {
        let predicate = #Predicate<Watch> { watch in
            watch.effective <= date && date <= watch.ends
        }
        return FetchDescriptor(predicate: predicate)
    }
    
    /// Returns a fetch descriptor that gets all watches
    /// - Returns: fetch descriptor
    private func allWatchesDescriptor() -> FetchDescriptor<Watch> {
        let predicate = #Predicate<Watch> { _ in true }
        return FetchDescriptor(predicate: predicate)
    }
    
    private func expiredWatchesDescriptor(asOf now: Date) -> FetchDescriptor<Watch> {
        let predicate = #Predicate<Watch> { $0.ends < now }
        return FetchDescriptor(predicate: predicate)
    }
}
