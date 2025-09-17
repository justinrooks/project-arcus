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
    
    convenience init? (from rssItem: Item) {
        guard
            let title = rssItem.title,
            let linkString = rssItem.link,
            let link = URL(string: linkString),
            let pubDateString = rssItem.pubDate,
            let summary = rssItem.description,
            let published = DateFormatter.rfc822.date(from: pubDateString)
        else {
            return nil
        }
        
        self.init(
            title: title,
            link: link,
            issued: published,
            summary: summary,
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
