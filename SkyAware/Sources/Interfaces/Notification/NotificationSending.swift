//
//  NotificationSender.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/3/26.
//

import Foundation

protocol NotificationSending: Sendable {
    func send(title: String, body: String, subtitle: String, id: String) async
}
