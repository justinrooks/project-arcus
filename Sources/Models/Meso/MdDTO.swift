//
//  MdDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation

// DTO for transfering across actor boundaries
struct MdDTO: Sendable, Identifiable, Hashable, Codable, AlertItem {
    var alertType: AlertType { .mesoscale }
    
    // Stable identity for SwiftUI diffing. MD numbers are unique in our store.
    var id: Int { number }
    let number: Int             // the MD number 1895
    let title: String           // e.g., "Day 1 Convective Outlook"
    let link: URL               // link to full outlook page
    let issued: Date            // Issued Date
    let validStart: Date        // Valid start
    let validEnd: Date          // Valid end
    let areasAffected: String   // locations affected by the meso
    let summary: String         // description / CDATA
    let concerning: String?     // e.g. "Severe potential... Watch unlikely"
    var severeRiskTags: String? { nil }
    let watchProbability: Double?
    let watchProbabilityText: String
    let threats: MDThreats?
    let coordinates: [Coordinate2D]

    private enum CodingKeys: String, CodingKey {
        case number
        case title
        case link
        case issued
        case validStart
        case validEnd
        case areasAffected
        case summary
        case concerning
        case watchProbability
        case watchProbabilityText
        case threats
        case coordinates
    }
    
    init(number: Int, title: String, link: URL, issued: Date, validStart: Date, validEnd: Date, areasAffected: String, summary: String, concerning: String? = nil, watchProbability: String, threats: MDThreats?, coordinates: [Coordinate2D]) {
        self.number = number
        self.title = title
        self.link = link
        self.issued = issued
        self.validStart = validStart
        self.validEnd = validEnd
        self.areasAffected = areasAffected
        self.summary = summary
        self.concerning = concerning
        let normalizedWatchProbability = watchProbability.trimmingCharacters(in: .whitespacesAndNewlines)
        self.watchProbabilityText = normalizedWatchProbability.isEmpty ? "Unknown" : normalizedWatchProbability
        self.watchProbability = Double(normalizedWatchProbability)
        self.threats = threats
        self.coordinates = coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decode(Int.self, forKey: .number)
        title = try container.decode(String.self, forKey: .title)
        link = try container.decode(URL.self, forKey: .link)
        issued = try container.decode(Date.self, forKey: .issued)
        validStart = try container.decode(Date.self, forKey: .validStart)
        validEnd = try container.decode(Date.self, forKey: .validEnd)
        areasAffected = try container.decode(String.self, forKey: .areasAffected)
        summary = try container.decode(String.self, forKey: .summary)
        concerning = try container.decodeIfPresent(String.self, forKey: .concerning)
        watchProbability = try container.decodeIfPresent(Double.self, forKey: .watchProbability)
        threats = try container.decodeIfPresent(MDThreats.self, forKey: .threats)
        coordinates = try container.decode([Coordinate2D].self, forKey: .coordinates)

        let legacyFallback = watchProbability.map { value in
            value.formatted(.number.precision(.fractionLength(0...2)))
        } ?? "Unknown"
        let decodedText = try container.decodeIfPresent(String.self, forKey: .watchProbabilityText)
        if let normalizedText = decodedText?.trimmingCharacters(in: .whitespacesAndNewlines),
           normalizedText.isEmpty == false {
            watchProbabilityText = normalizedText
        } else {
            watchProbabilityText = legacyFallback
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(number, forKey: .number)
        try container.encode(title, forKey: .title)
        try container.encode(link, forKey: .link)
        try container.encode(issued, forKey: .issued)
        try container.encode(validStart, forKey: .validStart)
        try container.encode(validEnd, forKey: .validEnd)
        try container.encode(areasAffected, forKey: .areasAffected)
        try container.encode(summary, forKey: .summary)
        try container.encodeIfPresent(concerning, forKey: .concerning)
        try container.encodeIfPresent(watchProbability, forKey: .watchProbability)
        try container.encode(watchProbabilityText, forKey: .watchProbabilityText)
        try container.encodeIfPresent(threats, forKey: .threats)
        try container.encode(coordinates, forKey: .coordinates)
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
