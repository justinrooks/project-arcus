//
//  Watch.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/11/25.
//

import Foundation

struct Watch: Identifiable, Hashable, AlertItem {
    let id: UUID              // usually the GUID or derived from it
    let title: String           // e.g., "Day 1 Convective Outlook"
    let link: URL               // link to full outlook page
    let issued: Date         // pubDate
    let summary: String         // description / CDATA
    let alertType: AlertType    // Type of alert to conform to alert item
}

extension Watch {
    static func from(rssItem: Item) -> Watch? {
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
        
        return Watch(
            id: UUID(),
            title: title,
            link: link,
            issued: published,
            summary: summary,
            alertType: .watch
        )
    }
}
