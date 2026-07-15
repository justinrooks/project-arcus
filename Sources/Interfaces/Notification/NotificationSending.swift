//
//  NotificationSender.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/3/26.
//

import Foundation

protocol NotificationSending: Sendable {
    /// Returns whether the notification request was accepted for scheduling.
    func send(title: String, body: String, subtitle: String, id: String) async -> Bool
}
