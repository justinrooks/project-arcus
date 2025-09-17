//
//  WatchDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation

final class WatchDTO: Sendable, Identifiable {
    let id: UUID              // usually the GUID or derived from it
    let title: String           // e.g., "Day 1 Convective Outlook"
    let link: URL               // link to full outlook page
    let issued: Date         // pubDate
    let summary: String         // description / CDATA
    
    init(title: String, link: URL, issued: Date, summary: String) {
        self.id = UUID()
        self.title = title
        self.link = link
        self.issued = issued
        self.summary = summary
    }
}
