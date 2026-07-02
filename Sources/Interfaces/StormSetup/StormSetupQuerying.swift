//
//  StormSetupQuerying.swift
//  SkyAware
//
//  Created by Codex on 7/2/26.
//

import Foundation

protocol StormSetupQuerying: Sendable {
    func fetchCurrentStormSetup(h3Cell: Int64) async throws -> StormSetupDTO
}
