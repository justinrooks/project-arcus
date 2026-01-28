//
//  NwsProvider+Cleanup.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/21/25.
//

import Foundation

extension NwsProvider: NwsCleanup {
    func cleanup(daysToKeep: Int = 3) async {
        do {
            try await watchRepo.purge()
        } catch {
            logger.error("Error cleaning up old NWS data: \(error.localizedDescription, privacy: .public)")
        }
    }
}
