//
//  Watch.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/11/25.
//

import Foundation
import SwiftData

@Model
final class WatchModel: AlertItem {
    var id: UUID              // usually the GUID or derived from it
    var title: String           // e.g., "Day 1 Convective Outlook"
    var link: URL               // link to full outlook page
    var issued: Date         // pubDate
    var summary: String         // description / CDATA
    var alertType: AlertType    // Type of alert to conform to alert item
    
    convenience init? (from dto: WatchDTO) {
        self.init(
            title: dto.title,
            link: dto.link,
            issued: dto.issued,
            summary: dto.summary,
            alertType: .watch
        )
    }
    
    init(title: String, link: URL, issued: Date, summary: String, alertType: AlertType) {
        self.id = UUID()
        self.title = title
        self.link = link
        self.issued = issued
        self.summary = summary
        self.alertType = alertType
    }
}
