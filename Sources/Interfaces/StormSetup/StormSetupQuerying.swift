//
//  StormSetupQuerying.swift
//  SkyAware
//
//  Created by Codex on 7/2/26.
//

import Foundation
import ArcusCore

protocol StormSetupQuerying: Sendable {
    func fetchCurrentStormSetup(h3Cell: Int64) async throws -> StormSetupCurrentResponse
}
