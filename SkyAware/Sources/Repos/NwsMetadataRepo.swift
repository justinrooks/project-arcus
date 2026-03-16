//
//  NwsMetadataRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/27/25.
//

import Foundation
import OSLog

struct NwsGridRegionContext: Sendable, Equatable {
    let county: String?
    let zone: String?
    let fireZone: String?
    let countyLabel: String?
    let fireZoneLabel: String?
}

actor NwsMetadataRepo {
    private let logger = Logger.reposNwsMetadata
    private var currentRegionContext: NwsGridRegionContext?

    func getPointMetadata(using client: any NwsClient, for location: Coordinate2D) async throws -> NWSGridPoint {
        let data = try await client.fetchPointMetadata(for: location)

        guard let decoded = NWSGridPointParser.decode(from: data) else {
            logger.error("Unable to parse NWS Json grid point data")
            throw NwsError.parsingError
        }
        
        return decoded
    }
    
    func getLocationLabels(using client: any NwsClient, for county: String?, and zone: String?) async throws -> (String?, String?) {
        let countyMetadata = try await zoneMetadata(using: client, type: .county, identifier: county)
        let fireZoneMetadata = try await zoneMetadata(using: client, type: .fire, identifier: zone)

        let countyLabel = countyMetadata.map { "\($0.name) \($0.type)".capitalized }
        let fireZoneLabel = fireZoneMetadata?.name

        return (countyLabel, fireZoneLabel)
    }
    
    func updateCurrentRegionContext(county: String?, zone: String?, fireZone: String?, countyLabel: String?, fireZoneLabel: String?) {
        currentRegionContext = NwsGridRegionContext(
            county: county,
            zone: zone,
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
}
