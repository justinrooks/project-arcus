//
//  SpcProvider+Cleanup.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/1/25.
//

import Foundation

// MARK: SpcCleanup
extension SpcProvider: SpcCleanup {
    func cleanup(daysToKeep: Int = 3) async {
        do {
            try await outlookRepo.purge()
            try await mesoRepo.purge()
            
            // Clean up the geojson
            try await stormRiskRepo.purge()
            try await severeRiskRepo.purge()
        } catch {
            logger.error("Error cleaning up old Spc feed data: \(error.localizedDescription, privacy: .public)")
        }
    }
}
