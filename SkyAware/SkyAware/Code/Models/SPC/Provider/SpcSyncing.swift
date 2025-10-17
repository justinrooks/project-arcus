//
//  SpcSyncing.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import Foundation

protocol SpcSyncing: Sendable {
    func sync() async -> Void
    func syncTextProducts() async -> Void
    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO?
}

extension SpcProvider: SpcSyncing {}
