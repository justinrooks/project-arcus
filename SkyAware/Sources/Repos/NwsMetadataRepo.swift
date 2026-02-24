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
    
    func updateCurrentRegionContext(county: String?, zone: String?, fireZone: String?) {
        currentRegionContext = NwsGridRegionContext(county: county, zone: zone, fireZone: fireZone)
    }
    
    func currentRegionContextSnapshot() -> NwsGridRegionContext? {
        currentRegionContext
    }
}
