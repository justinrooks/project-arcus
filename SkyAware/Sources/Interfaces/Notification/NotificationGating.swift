//
//  NotificationGate.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/3/26.
//

import Foundation

protocol NotificationGating: Sendable {
    func allow(_ event: NotificationEvent, now: Date) async -> Bool
}
