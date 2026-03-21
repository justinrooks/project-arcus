//
//  ArcusAlertQuerying.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation

protocol ArcusAlertQuerying: Sendable {
    func getActiveWatches(h3Cell: Int64?) async throws -> [WatchRowDTO]
}
