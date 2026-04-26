//
//  WatchComposer.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import OSLog

struct WatchComposer: NotificationComposing {
    private let logger = Logger.notificationsWatchComposer

    func compose(_ event: NotificationEvent) -> (title: String, body: String, subtitle: String) {
        logger.debug("Building watch notification")

        let title = (event.payload["title"] as? String) ?? "New watch detected"
        let headline = (event.payload["headline"] as? String) ?? "A new watch has been issued for your location."
        let placeMark = (event.payload["placeMark"] as? String) ?? "Unknown"

        return (
            title,
            headline,
            "Current location: \(placeMark)"
        )
    }
}
