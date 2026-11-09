//
//  NwsMetadataRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/27/25.
//

import Foundation
import OSLog

struct NwsGridRegionContext: Sendable, Equatable {
    let countyCode: String?
    let forecastZone: String?
    let fireZone: String?
    let countyLabel: String?
    let fireZoneLabel: String?
}

actor NwsMetadataRepo {
    private let logger = Logger.reposNwsMetadata
    private var currentRegionContext: NwsGridRegionContext?
    private let labelTimeout: Duration
    private struct LabelLookup {
        let type: NwsZoneType
        let worker: Task<Void, Never>
        let timer: Task<Void, Never>
        var waiter: CheckedContinuation<NWSZoneDTO?, Never>?
    }
    private var labelLookups: [UUID: LabelLookup] = [:]

    init(labelTimeout: Duration = .seconds(5)) {
        self.labelTimeout = labelTimeout
    }

    func getPointMetadata(using client: any NwsClient, for location: Coordinate2D) async throws -> NWSGridPoint {
        logger.debug("Decoding NWS point metadata response")
        let data = try await client.fetchPointMetadata(for: location)

        guard let decoded: NWSGridPoint = JsonParser.decode(from: data) else {
            throw NwsError.parsingError
        }

        logger.debug("Decoded NWS point metadata successfully")
        return decoded
    }
    
    func getLocationLabels(using client: any NwsClient, for countyCode: String?, and fireZone: String?) async throws -> (String?, String?) {
        logger.debug("Resolving NWS location labels")
        async let countyMetadata = optionalZoneMetadata(using: client, type: .county, identifier: countyCode)
        async let fireZoneMetadata = optionalZoneMetadata(using: client, type: .fire, identifier: fireZone)
        let (resolvedCountyMetadata, resolvedFireZoneMetadata) = await (countyMetadata, fireZoneMetadata)
        try Task.checkCancellation()

        let countyLabel = resolvedCountyMetadata.map { "\($0.name) \($0.type)".capitalized }
        let fireZoneLabel = resolvedFireZoneMetadata?.name

        logger.debug(
            "Resolved NWS location labels hasCountyLabel=\((countyLabel != nil), privacy: .public) hasFireZoneLabel=\((fireZoneLabel != nil), privacy: .public)"
        )
        return (countyLabel, fireZoneLabel)
    }
    
    func updateCurrentRegionContext(
        countyCode: String?,
        forecastZone: String?,
        fireZone: String?,
        countyLabel: String?,
        fireZoneLabel: String?
    ) {
        currentRegionContext = NwsGridRegionContext(
            countyCode: countyCode,
            forecastZone: forecastZone,
            fireZone: fireZone,
            countyLabel: countyLabel,
            fireZoneLabel: fireZoneLabel
        )
    }
    
    func currentRegionContextSnapshot() -> NwsGridRegionContext? {
        currentRegionContext
    }

    private func zoneMetadata(
        using client: any NwsClient,
        type: NwsZoneType,
        identifier: String?
    ) async throws -> NWSZoneDTO? {
        guard let identifier else {
            return nil
        }

        let data = try await client.fetchZoneMetadata(for: type, and: identifier)
        return try JSONDecoder().decode(NWSZoneDTO.self, from: data)
    }

    private func optionalZoneMetadata(
        using client: any NwsClient,
        type: NwsZoneType,
        identifier: String?
    ) async -> NWSZoneDTO? {
        // Keep a cancelled worker tracked until it actually exits; one per type bounds stalled work.
        guard identifier != nil, !labelLookups.values.contains(where: { $0.type == type }) else { return nil }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(returning: nil)
                    return
                }
                let worker = Task {
                    let result = try? await self.zoneMetadata(using: client, type: type, identifier: identifier)
                    self.finishLabelLookup(id: id, result: result)
                }
                let timer = Task {
                    do { try await Task.sleep(for: self.labelTimeout) } catch { return }
                    self.abandonLabelLookup(id: id)
                }
                labelLookups[id] = LabelLookup(type: type, worker: worker, timer: timer, waiter: continuation)
            }
        } onCancel: {
            Task { await self.abandonLabelLookup(id: id) }
        }
    }

    private func abandonLabelLookup(id: UUID) {
        guard var lookup = labelLookups[id], let waiter = lookup.waiter else { return }
        lookup.waiter = nil
        labelLookups[id] = lookup
        lookup.worker.cancel()
        lookup.timer.cancel()
        waiter.resume(returning: nil)
    }

    private func finishLabelLookup(id: UUID, result: NWSZoneDTO?) {
        guard let lookup = labelLookups.removeValue(forKey: id) else { return }
        lookup.timer.cancel()
        lookup.waiter?.resume(returning: result)
    }
}
