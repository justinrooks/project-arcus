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
    
    func active(countyCode: String, fireZone: String, cell: Int64?, on date: Date = .now) async throws -> [WatchRowDTO] {
        logger.info("Fetching current local watches")
        
        let candidates = try modelContext.fetch(currentWatchesDescriptor(date: date))

        var hits: [Watch] = []
        hits.reserveCapacity(candidates.count)
        
        for watch in candidates {
            let ugc = watch.ugcZones
            let cells = watch.h3Cells
            let matchesCell = cell.map { cells.contains($0) } ?? false
            let matchesUGC = ugc.contains(countyCode) || ugc.contains(fireZone)
            
            if matchesCell || matchesUGC {
                hits.append(watch)
            }
        }
        
        // Dedupe before returning since its possible to be in the same cell and county/fire zone.
        return hits.removingDuplicates(by: \.nwsId).map { WatchRowDTO.init(from: $0) }
    }

    func refresh(using client: any ArcusClient, for countyCode: String, and fireZone: String, in cell: Int64?) async throws {
        let data = try await client.fetchActiveAlerts(for: countyCode, or: fireZone, in: cell)
        
        guard let decoded:[DeviceAlertPayload] = JsonParser.decode(from: data) else {
            logger.error("Unable to parse Arcus watch data")
            throw ArcusError.parsingError
        }
        
        let watches = decoded
            .compactMap { makeWatch(from: $0) }
        
        try upsert(watches)
        logger.debug("Parsed \(watches.count, privacy: .public) watch\(watches.count > 1 ? "es" : "", privacy: .public) from Arcus")
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
    
    // MARK: Translator
    private func makeWatch(from item: DeviceAlertPayload) -> Watch? {
        let state = item.state.trimmingCharacters(in: .whitespacesAndNewlines)
        let messageType = item.messageType.trimmingCharacters(in: .whitespacesAndNewlines)

        guard state.localizedCaseInsensitiveCompare("active") == .orderedSame else {
            logger.debug("Skipping Arcus alert with non-active state: \(state, privacy: .public)")
            return nil
        }

        guard messageType.localizedCaseInsensitiveCompare("cancel") != .orderedSame else {
            logger.debug("Skipping Arcus alert with cancel message type")
            return nil
        }

        guard
            let sent             = item.sent,
            let effective        = item.effective,
            let onset            = item.onset,
            let expires          = item.expires,
            let ends             = item.ends,
            let watchDescription = item.description
        else {
            logger.debug("Required watch property missing, returning null.")
            return nil
        }

        return .init(
            nwsId: "\(item.id)",
            messageId: item.currentRevisionUrn,
            areaDesc: item.areaDesc ?? "",
            ugcZones: item.ugc ?? [],
            sent: sent,
            effective: effective,
            onset: onset,
            expires: expires,
            ends: ends,
            status: state,
            messageType: messageType,
            severity: item.severity,
            certainty: item.certainty,
            urgency: item.urgency,
            event: item.event,
            headline: item.headline ?? "",
            watchDescription: watchDescription,
            sender: item.senderName,
            instruction: item.instructions,
            response: item.response,
            cells: item.h3Cells ?? []
        )
    }
    
    // MARK: Upsert
    private func upsert(_ items: [Watch]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }
    
    // MARK: Fetch Descriptors
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
