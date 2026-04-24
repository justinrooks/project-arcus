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
        let candidates = try modelContext.fetch(Watch.currentWatchesDescriptor(date: date))

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
        let rows = hits.removingDuplicates(by: \.nwsId).map { WatchRowDTO.init(from: $0) }
        logger.debug(
            "Resolved current local watches candidates=\(candidates.count, privacy: .public) matches=\(rows.count, privacy: .public) hasCell=\((cell != nil), privacy: .public)"
        )
        return rows
    }

    func watch(id: String) throws -> WatchRowDTO? {
        let canonicalID = ArcusAlertIdentifier.canonical(id)
        let predicate = #Predicate<Watch> { watch in
            watch.nwsId == canonicalID
        }
        var descriptor = FetchDescriptor<Watch>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map(WatchRowDTO.init(from:))
    }

    func refresh(using client: any ArcusClient, for countyCode: String, and fireZone: String, in cell: Int64?) async throws {
        let data = try await client.fetchActiveAlerts(for: countyCode, or: fireZone, in: cell)

        guard let decoded = decodePayloads(from: data) else {
            logger.error("Arcus alert payload decode failed; leaving persisted watches unchanged")
            throw ArcusError.parsingError
        }
        
        let watches = decoded
            .compactMap { makeWatch(from: $0) }
        
        try upsert(watches)
        logger.debug("Persisted Arcus watch refresh count=\(watches.count, privacy: .public)")
    }

    func refreshAlert(using client: any ArcusClient, id: String, revisionSent: Date?) async throws {
        let data = try await client.fetchAlert(id: id, revisionSent: revisionSent)

        guard let decoded = decodePayloads(from: data) else {
            logger.error("Targeted Arcus alert payload decode failed; leaving persisted watches unchanged")
            throw ArcusError.parsingError
        }

        let watches = decoded.compactMap(makeWatch(from:))
        try upsert(watches)
        logger.debug("Persisted targeted Arcus alert refresh count=\(watches.count, privacy: .public)")
    }

    /// Removes any expired watches from the database
    func purge(asOf now: Date = .init()) throws {
        logger.info("Purging expired NWS watches")
        
        let expired = try modelContext.fetch(Watch.expiredWatchesDescriptor(asOf: now))
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
            nwsId: ArcusAlertIdentifier.canonical(item.id),
            messageId: item.currentRevisionUrn,
            currentRevisionSent: item.currentRevisionSent,
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
            cells: item.h3Cells ?? [],
            geometry: item.geometry,
            tornadoDetection: item.tornadoDetection,
            tornadoDamageThreat: item.tornadoDamageThreat,
            maxWindGust: item.maxWindGust,
            maxHailSize: item.maxHailSize,
            windThreat: item.windThreat,
            hailThreat: item.hailThreat,
            thunderstormDamageThreat: item.thunderstormDamageThreat,
            flashFloodDetection: item.flashFloodDetection,
            flashFloodDamageThreat: item.flashFloodDamageThreat
        )
    }

    private func decodePayloads(from data: Data) -> [DeviceAlertPayload]? {
        if let payloads: [DeviceAlertPayload] = JsonParser.decode(from: data) {
            return payloads
        }

        if let payload: DeviceAlertPayload = JsonParser.decode(from: data) {
            return [payload]
        }

        return nil
    }
    
    // MARK: Upsert
    private func upsert(_ items: [Watch]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }
}
