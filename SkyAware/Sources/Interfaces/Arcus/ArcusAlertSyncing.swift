//
//  ArcusAlertSyncing.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation

protocol ArcusAlertSyncing: Sendable {
    func sync(h3Cell: Int64?) async -> Void
}
