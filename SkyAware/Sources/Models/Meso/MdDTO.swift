//
//  MdDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation

// DTO for transfering across actor boundaries
struct MdDTO: Sendable, Identifiable {
    let id: UUID                // usually the GUID or derived from it
    let number: Int             // the MD number 1895
    let title: String           // e.g., "Day 1 Convective Outlook"
    let link: URL               // link to full outlook page
    let issued: Date            // Issued Date
    let validStart: Date        // Valid start
    let validEnd: Date          // Valid end
    let areasAffected: String   // locations affected by the meso
    let summary: String         // description / CDATA
    let concerning: String?     // e.g. "Severe potential... Watch unlikely"
    
    let watchProbability: String
    let threats: MDThreats?
    let coordinates: [Coordinate2D]
    
    init(number: Int, title: String, link: URL, issued: Date, validStart: Date, validEnd: Date, areasAffected: String, summary: String, concerning: String? = nil, watchProbability: String, threats: MDThreats?, coordinates: [Coordinate2D]) {
        self.id = UUID()
        self.number = number
        self.title = title
        self.link = link
        self.issued = issued
        self.validStart = validStart
        self.validEnd = validEnd
        self.areasAffected = areasAffected
        self.summary = summary
        self.concerning = concerning
        self.watchProbability = watchProbability
        self.threats = threats
        self.coordinates = coordinates
    }
    
//    static func from(md: MD) -> Self? {
//        return MdDTO(number: md.number,
//                    title: md.title,
//                    link: md.link,
//                    issued: md.issued,
//                    validStart: md.validStart,
//                    validEnd: md.validEnd,
//                    areasAffected: md.areasAffected,
//                    summary: md.summary,
//                    watchProbability: md.watchProbability,
//                    threats: md.threats ?? nil,
//                    coordinates:md.coordinates
//            )
//    }
}
