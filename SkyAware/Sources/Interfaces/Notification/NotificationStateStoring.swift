//
//  NotificationStateStoring.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/3/26.
//

import Foundation

protocol NotificationStateStoring: Sendable {
    func lastStamp() async -> String?
    func setLastStamp(_ stamp: String) async
}
