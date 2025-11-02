//
//  SpcCleanup.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import Foundation

protocol SpcCleanup: Sendable {
    func cleanup(daysToKeep: Int) async -> Void
}
