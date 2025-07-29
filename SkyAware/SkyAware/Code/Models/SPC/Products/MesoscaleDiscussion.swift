//
//  MesoscaleDiscussion.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/11/25.
//

import Foundation

struct MesoscaleDiscussion: Identifiable, Hashable, AlertItem {
    let id: UUID              // usually the GUID or derived from it
    let title: String           // e.g., "Day 1 Convective Outlook"
    let link: URL               // link to full outlook page
    let published: Date         // pubDate
    let summary: String         // description / CDATA
    let alertType: AlertType    // type of alert to conform to AlertItem
}

extension MesoscaleDiscussion {
    static func from(rssItem: Item) -> MesoscaleDiscussion? {
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
        
        return MesoscaleDiscussion(
            id: UUID(),
            title: title,
            link: link,
            published: published,
            summary: summary,
            alertType: .mesoscale
        )
    }
}
