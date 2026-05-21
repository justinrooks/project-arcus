//
//  AlertRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import ArcusCore
import SwiftData
import OSLog

@ModelActor
actor AlertRepo {
    private let logger = Logger.reposAlert
    private static let referenceDateEpochOffset: TimeInterval = 978_307_200 // 2001-01-01T00:00:00Z
    
    func active(countyCode: String, fireZone: String, forecastZone: String, cell: Int64?, on date: Date = .now) async throws -> [AlertDTO] {
        let candidates = try modelContext.fetch(Watch.currentWatchesDescriptor(date: date))

        var hits: [Watch] = []
        hits.reserveCapacity(candidates.count)
        
        for alert in candidates {
            let ugc = alert.ugcZones
            let cells = alert.h3Cells
            let matchesCell = cell.map { cells.contains($0) } ?? false
            let matchesUGC = ugc.contains(countyCode) || ugc.contains(fireZone) || ugc.contains(forecastZone)
            
            let matchesLocation: Bool
            if alert.geometry != nil {
                matchesLocation = matchesCell
            } else {
                matchesLocation = matchesCell || matchesUGC
            }

            if matchesLocation && isRenderableAlertLifecycle(status: alert.status, messageType: alert.messageType) {
                hits.append(alert)
            }
        }
        
        // Dedupe before returning since its possible to be in the same cell and county/fire zone.
        let rows = hits.removingDuplicates(by: \.nwsId).map { AlertDTO.init(from: $0) }
        logger.debug(
            "Resolved current local alert candidates=\(candidates.count, privacy: .public) matches=\(rows.count, privacy: .public) hasCell=\((cell != nil), privacy: .public)"
        )
        return rows
    }

    func activeWarningGeometries(on date: Date = .now) throws -> [ActiveWarningGeometry] {
        let candidates = try modelContext.fetch(Watch.currentWatchesDescriptor(date: date))

        let rows = candidates.compactMap { alert -> ActiveWarningGeometry? in
            guard isSupportedWarningGeometryEvent(alert.event),
                  isRenderableWarningLifecycle(alert, on: date),
                  let geometry = alert.geometry else {
                return nil
            }

            return ActiveWarningGeometry(
                id: alert.nwsId,
                messageId: alert.messageId,
                currentRevisionSent: alert.currentRevisionSent,
                event: alert.event,
                issued: alert.sent,
                effective: alert.effective,
                expires: alert.expires,
                ends: alert.ends,
                messageType: alert.messageType,
                geometry: geometry
            )
        }

        return rows.sorted {
            if $0.event != $1.event { return $0.event < $1.event }
            return $0.id < $1.id
        }
    }

    func alert(id: String) throws -> AlertDTO? {
        let canonicalID = ArcusAlertIdentifier.canonical(id)
        let predicate = #Predicate<Watch> { watch in
            watch.nwsId == canonicalID
        }
        var descriptor = FetchDescriptor<Watch>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map(AlertDTO.init(from:))
    }

    func refresh(using client: any ArcusClient, for countyCode: String, and fireZone: String, and forecastZone: String, in cell: Int64?) async throws {
        let data = try await client.fetchActiveAlerts(for: countyCode, and: fireZone, and: forecastZone, in: cell)

        guard let decoded = decodePayloads(from: data) else {
            logger.error("Alert payload decode failed; leaving persisted watches unchanged")
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
            "Persisted alert refresh count=\(watches.count, privacy: .public) reconciledTerminal=\(reconciledTerminalCount, privacy: .public)"
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
        logger.info("Purging expired alerts")
        
        let expired = try modelContext.fetch(Watch.expiredWatchesDescriptor(asOf: now))
        if expired.isEmpty {
            logger.debug("No expired alertss to purge")
            return
        }
        
        logger.debug("Found \(expired.count, privacy: .public) alertss to purge")
        for obj in expired { modelContext.delete(obj) }
        try modelContext.save()
        
        logger.info("Expired alerts purged")
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
            let sent             = normalizedAlertDate(item.sent),
            let effective        = normalizedAlertDate(item.effective),
            let onset            = normalizedAlertDate(item.onset),
            let expires          = normalizedAlertDate(item.expires),
            let watchDescription = item.description
        else {
            logger.debug("Required watch property missing, returning null.")
            return nil
        }
        let ends = normalizedAlertDate(item.ends) ?? expires

        return .init(
            nwsId: ArcusAlertIdentifier.canonical(item.id),
            messageId: item.currentRevisionUrn,
            currentRevisionSent: item.currentRevisionSent,
            areaDesc: item.areaDesc ?? "",
            ugcZones: item.ugc,
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
            cells: item.h3Cells,
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
            existing.currentRevisionSent = normalizedAlertDate(currentRevisionSent)
        }
        if let sent = item.sent {
            existing.sent = normalizedAlertDate(sent) ?? sent
        }
        if let effective = item.effective {
            existing.effective = normalizedAlertDate(effective) ?? effective
        }
        if let onset = item.onset {
            existing.onset = normalizedAlertDate(onset) ?? onset
        }
        if let expires = item.expires {
            existing.expires = normalizedAlertDate(expires) ?? expires
        }
        if let ends = item.ends {
            existing.ends = normalizedAlertDate(ends) ?? ends
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

    private func normalizedAlertDate(_ value: Date?) -> Date? {
        guard let value else { return nil }
        // Arcus payloads can arrive as seconds since the 2001 reference date.
        // If decoded as Unix seconds they land around the 1990s; remap those.
        let unixEpoch = value.timeIntervalSince1970
        if unixEpoch > 0, unixEpoch < AlertRepo.referenceDateEpochOffset {
            return Date(timeIntervalSince1970: unixEpoch + AlertRepo.referenceDateEpochOffset)
        }
        return value
    }
    
    // MARK: Upsert
    private func upsert(_ items: [Watch]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }
}
