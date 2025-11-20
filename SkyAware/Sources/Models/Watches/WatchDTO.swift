//
//  WatchDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation

struct WatchDTO: Sendable, Identifiable {
    let id: UUID              // usually the GUID or derived from it
    let number: Int
    let title: String           // e.g., "Day 1 Convective Outlook"
    let link: URL               // link to full outlook page
    let issued: Date         // pubDate
    let validStart: Date
    let validEnd: Date
    let summary: String         // description / CDATA
    let type: String
    
    init(number: Int, title: String, link: URL, issued: Date, validStart: Date, validEnd: Date, summary: String, type: String) {
        self.id = UUID()
        self.number = number
        self.title = title
        self.link = link
        self.issued = issued
        self.validStart = validStart
        self.validEnd = validEnd
        self.summary = summary
        self.type = type
    }
}
