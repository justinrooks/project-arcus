//
//  NwsMetadataRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/27/25.
//

import Foundation
import OSLog

actor NwsMetadataRepo {
    private let logger = Logger.reposNwsMetadata

    func getPointMetadata(using client: any NwsClient,for location: Coordinate2D) async throws -> NWSGridPoint {
        let data = try await client.fetchPointMetadata(for: location)
        
        guard let data else {
            logger.error("No grid point data found")
            throw NwsError.parsingError
        }
        
        guard let decoded = NWSGridPointParser.decode(from: data) else {
            logger.error("Unable to parse NWS Json grid point data")
            throw NwsError.parsingError
        }
        
        return decoded
    }
}
