//
//  MesoRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import SwiftData
import OSLog

@ModelActor
actor MesoRepo {
    private var context: ModelContext { modelExecutor.modelContext }
    private let logger = Logger.mesoRepo
 
    func refreshMesoscaleDiscussions() async throws {
        let client = SpcClient()
        let items = try await client.fetchMesoItems()
        
        // Filters out some odd contents
        let mesos = items
            .filter { ($0.title ?? "").contains("SPC MD ") }
            .compactMap { makeMdDto(from: $0) }
        
        try await upsertMesos(mesos)
        logger.debug("Parsed \(mesos.count) meso discussion\(mesos.count > 1 ? "s" : "") from SPC")
    }
    
    private func makeMdDto(from rssItem: Item) -> MdDTO? {
        guard
            let title = rssItem.title,
            let linkString = rssItem.link,
            let link = URL(string: linkString),
            let pubDateString = rssItem.pubDate,
            let rawText = rssItem.description, // SPC MD free text lives here in your feed
            let issued = DateFormatter.rfc822.date(from: pubDateString)
        else { return nil }

        let mdNumber = MDParser.parseMDNumber(from: link) ?? {
            // Fallback: try to read from title if present
            if let r = title.range(of: #"\b(\d{3,4})\b"#, options: .regularExpression) { return Int(title[r]) } else { return nil }
        }() ?? -1

        // Areas / Summary (block captures)
        let areasAffected = MDParser.parseAreas(rawText)
        let summaryParsed = MDParser.parseSummary(rawText)

        // Valid range (UTC), fallback to issued+2h if missing
        let validPair = MDParser.parseValid(rawText, issued: issued)
        let validStart = validPair?.0 ?? issued
        let validEnd   = validPair?.1 ?? Calendar.current.date(byAdding: .hour, value: 2, to: issued)!

        // Watch probability + concerning
        let (watchProb, concerningLine) = MDParser.parseWatchFields(rawText)

        // Threats
        let windMPH  = MDParser.parseWindMPH(rawText)
        let hailRng  = MDParser.parseHailRange(rawText)
        let torText  = MDParser.parseTornadoStrength(rawText)

        let threats = MDThreats(
            peakWindMPH: windMPH,
            hailRangeInches: hailRng,
            tornadoStrength: torText
        )
        
        let coordinates = MesoGeometry.coordinates(from: rawText) ?? []
        let m = coordinates.compactMap(Coordinate2D.init)
        
        return MdDTO(
            number: mdNumber,
            title: title,
            link: link,
            issued: issued,
            validStart: validStart,
            validEnd: validEnd,
            areasAffected: areasAffected,
            summary: summaryParsed.isEmpty ? rawText : summaryParsed,
            concerning: concerningLine,
            watchProbability: watchProb,
            threats: threats,
            coordinates: m
        )
    }
    
    private func upsertMesos(_ md: [MdDTO]) async throws {
        _ = try md.map {
            guard let m = MD(from: $0) else { throw OtherErrors.contextSaveError }
            context.insert(m)
        }
        
        try context.save()
    }
}
