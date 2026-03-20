//
//  Cleaning.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/21/25.
//

import Foundation

protocol Cleaning: Sendable {
    func cleanup(daysToKeep: Int) async -> Void
}
