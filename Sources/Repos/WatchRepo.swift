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
    
    func active(countyCode: String, fireZone: String, forecastZone: String, cell: Int64?, on date: Date = .now) async throws -> [WatchRowDTO] {
        let candidates = try modelContext.fetch(Watch.currentWatchesDescriptor(date: date))

        var hits: [Watch] = []
        hits.reserveCapacity(candidates.count)
        
        for watch in candidates {
            let ugc = watch.ugcZones
            let cells = watch.h3Cells
            let matchesCell = cell.map { cells.contains($0) } ?? false
            let matchesUGC = ugc.contains(countyCode) || ugc.contains(fireZone) || ugc.contains(forecastZone)
            
            if (matchesCell || matchesUGC) && isRenderableAlertLifecycle(status: watch.status, messageType: watch.messageType) {
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

    func activeWarningGeometries(on date: Date = .now) throws -> [ActiveWarningGeometry] {
        let candidates = try modelContext.fetch(Watch.currentWatchesDescriptor(date: date))

        let rows = candidates.compactMap { watch -> ActiveWarningGeometry? in
            guard isSupportedWarningGeometryEvent(watch.event),
                  isRenderableWarningLifecycle(watch, on: date),
                  let geometry = watch.geometry else {
                return nil
            }

            return ActiveWarningGeometry(
                id: watch.nwsId,
                messageId: watch.messageId,
                currentRevisionSent: watch.currentRevisionSent,
                event: watch.event,
                issued: watch.sent,
                effective: watch.effective,
                expires: watch.expires,
                ends: watch.ends,
                messageType: watch.messageType,
                geometry: geometry
            )
        }

        return rows.sorted {
            if $0.event != $1.event { return $0.event < $1.event }
            return $0.id < $1.id
        }
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

    func refresh(using client: any ArcusClient, for countyCode: String, and fireZone: String, and forecastZone: String, in cell: Int64?) async throws {
        let data = try await client.fetchActiveAlerts(for: countyCode, and: fireZone, and: forecastZone, in: cell)

        guard let decoded = decodePayloads(from: data) else {
            logger.error("Arcus alert payload decode failed; leaving persisted watches unchanged")
            throw ArcusError.parsingError
        }
        
        var watches: [Watch] = []
        watches.reserveCapacity(decoded.count)
        var reconciledTerminalCount = 0

        for payload in decoded {
            if isTerminalLifecyclePayload(payload) {
                if try reconcileExistingWatchForTerminalPayload(payload) {
                    reconciledTerminalCount += 1
                }
                continue
            }

            if let watch = makeWatch(from: payload) {
                watches.append(watch)
            }
        }

        if watches.isEmpty == false {
            try upsert(watches)
        }
        logger.debug(
            "Persisted Arcus watch refresh count=\(watches.count, privacy: .public) reconciledTerminal=\(reconciledTerminalCount, privacy: .public)"
        )
    }

    func refreshAlert(using client: any ArcusClient, id: String, revisionSent: Date?) async throws {
        let data = try await client.fetchAlert(id: id, revisionSent: revisionSent)

        guard let decoded = decodePayloads(from: data) else {
            logger.error("Targeted Arcus alert payload decode failed; leaving persisted watches unchanged")
            throw ArcusError.parsingError
        }

        var watches: [Watch] = []
        watches.reserveCapacity(decoded.count)
        var reconciledTerminalCount = 0

        for payload in decoded {
            if isTerminalLifecyclePayload(payload) {
                if try reconcileExistingWatchForTerminalPayload(payload) {
                    reconciledTerminalCount += 1
                }
                continue
            }

            if let watch = makeWatch(from: payload) {
                watches.append(watch)
            }
        }

        if watches.isEmpty == false {
            try upsert(watches)
        }
        logger.debug(
            "Persisted targeted Arcus alert refresh count=\(watches.count, privacy: .public) reconciledTerminal=\(reconciledTerminalCount, privacy: .public)"
        )
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

        guard isRenderableAlertLifecycle(status: state, messageType: messageType) else {
            logger.debug("Skipping Arcus alert with non-active state: \(state, privacy: .public)")
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

    private func isTerminalLifecyclePayload(_ item: DeviceAlertPayload) -> Bool {
        isTerminalLifecycle(status: item.state, messageType: item.messageType)
    }

    private func reconcileExistingWatchForTerminalPayload(_ item: DeviceAlertPayload) throws -> Bool {
        let canonicalID = ArcusAlertIdentifier.canonical(item.id)
        let predicate = #Predicate<Watch> { watch in
            watch.nwsId == canonicalID
        }
        var descriptor = FetchDescriptor<Watch>(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let existing = try modelContext.fetch(descriptor).first else {
            logger.debug("Ignoring terminal Arcus alert with no local row id=\(canonicalID, privacy: .public)")
            return false
        }

        let state = item.state.trimmingCharacters(in: .whitespacesAndNewlines)
        if state.isEmpty == false {
            existing.status = state
        }

        let messageType = item.messageType.trimmingCharacters(in: .whitespacesAndNewlines)
        if messageType.isEmpty == false {
            existing.messageType = messageType
        }

        let revisionID = item.currentRevisionUrn.trimmingCharacters(in: .whitespacesAndNewlines)
        if revisionID.isEmpty == false {
            existing.messageId = revisionID
        }

        if let currentRevisionSent = item.currentRevisionSent {
            existing.currentRevisionSent = currentRevisionSent
        }
        if let sent = item.sent {
            existing.sent = sent
        }
        if let effective = item.effective {
            existing.effective = effective
        }
        if let onset = item.onset {
            existing.onset = onset
        }
        if let expires = item.expires {
            existing.expires = expires
        }
        if let ends = item.ends {
            existing.ends = ends
        }

        existing.geometry = nil
        try modelContext.save()
        return true
    }

    private func isSupportedWarningGeometryEvent(_ event: String) -> Bool {
        switch event.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase {
        case "tornado warning", "severe thunderstorm warning", "flash flood warning":
            return true
        default:
            return false
        }
    }

    private func isRenderableWarningLifecycle(_ watch: Watch, on date: Date) -> Bool {
        let status = watch.status
        let messageType = watch.messageType

        guard watch.effective <= date && date <= watch.ends else {
            return false
        }

        return isRenderableAlertLifecycle(status: status, messageType: messageType)
    }

    private func isRenderableAlertLifecycle(status: String, messageType: String) -> Bool {
        let normalizedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        let normalizedMessageType = messageType.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase

        guard normalizedStatus == "active" || normalizedStatus == "actual" else {
            return false
        }

        return normalizedMessageType != "cancel" && normalizedMessageType != "cancelled"
    }

    private func isTerminalLifecycle(status: String, messageType: String) -> Bool {
        let normalizedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        let normalizedMessageType = messageType.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase

        if normalizedMessageType == "cancel" || normalizedMessageType == "cancelled" {
            return true
        }

        switch normalizedStatus {
        case "superseded", "expired", "canceled", "cancelled":
            return true
        default:
            return false
        }
    }
    
    // MARK: Upsert
    private func upsert(_ items: [Watch]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }
}
