//
//  StormSetupProfileAnalysisQuerying.swift
//  SkyAware
//
//  Created by Codex on 7/5/26.
//

import Foundation

protocol StormSetupProfileAnalysisQuerying: Sendable {
    func fetchProfileAnalysis(h3Cell: Int64) async throws -> StormSetupProfileAnalysisDTO
}
