//
//  ArcusAlertQuerying.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation

protocol ArcusAlertQuerying: Sendable {
    func getActiveWatches(context: LocationContext) async throws -> [WatchRowDTO]
    func getWatch(id: String) async throws -> WatchRowDTO?
}
