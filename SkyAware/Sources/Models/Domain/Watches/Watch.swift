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
    @Attribute(.unique) var number: Int
    var title: String           // e.g., "Day 1 Convective Outlook"
    var link: URL               // link to full outlook page
    var issued: Date         // pubDate
    var validStart: Date        // Valid start
    var validEnd: Date          // Valid end
    var summary: String         // description / CDATA
    var alertType: AlertType    // Type of alert to conform to alert item
    
    convenience init? (from dto: WatchDTO) {
        self.init(
            number: dto.number,
            title: dto.title,
            link: dto.link,
            issued: dto.issued,
            validStart: dto.validStart,
            validEnd: dto.validEnd,
            summary: dto.summary,
            alertType: .watch
        )
    }
    
    init(number: Int, title: String, link: URL, issued: Date, validStart: Date, validEnd: Date, summary: String, alertType: AlertType) {
        self.id = UUID()
        self.number = number
        self.title = title
        self.link = link
        self.issued = issued
        self.validStart = validStart
        self.validEnd = validEnd
        self.summary = summary
        self.alertType = alertType
    }
}
