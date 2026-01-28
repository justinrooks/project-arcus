//
//  NotificationComposing.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/3/26.
//

import Foundation

protocol NotificationComposing: Sendable {
    func compose(_ event: NotificationEvent) -> (title: String, body: String, subtitle: String)
}
