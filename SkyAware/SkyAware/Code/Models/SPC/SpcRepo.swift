//
//  SpcRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation
import OSLog

struct SpcRepo {
    private let logger = Logger.spcRepo
    let client: SpcClient
    let dba: DatabaseActor
    
    func refreshConvectiveOutlooks() async throws {
        let items = try await client.fetchOutlookItems()
        
        // Filters out some odd contents
        let outlooks = items
            .filter { ($0.title ?? "").contains(" Convective Outlook") }
            .compactMap { makeConvectiveDto(from: $0) }
        
        try await dba.upsertConvectiveOutlooks(outlooks)
        logger.debug("Parsed \(outlooks.count) outlooks from SPC")
    }
    
    func refreshMesoscaleDiscussions() async throws {
        let items = try await client.fetchMesoItems()
        // Filters out some odd contents
        let mesos = items
            .filter { ($0.title ?? "").contains("SPC MD ") }
            .compactMap { makeMdDto(from: $0) }
        
        try await dba.upsertMesos(mesos)
        logger.debug("Parsed \(mesos.count) meso discussions from SPC")
    }
    
    func refreshWatches() async throws {
        let items = try await client.fetchWatchItems()
        // Filters out some odd contents
        let watches = items
            .filter {
                guard let t = $0.title else { return false }
                return t.contains("Watch") && !t.contains("Status Reports")
            }
            .compactMap { makeWatchDto(from: $0) }
        
        try await dba.upsertWatches(watches)
        logger.debug("Parsed \(watches.count) watches from SPC")
    }
    
    func refreshStormRisk() async throws {
        let risk = try await client.fetchStormRisk()
        guard let risk else { return } // if we don't have any items, just return
        
        let dto = risk.featureCollection.features.compactMap {
            let props = $0.properties

            return StormRiskDTO(riskLevel: StormRiskLevel(abbreviation: props.LABEL),
                                issued: props.ISSUE.asUTCDate() ?? Date(),
                                validUntil: props.VALID.asUTCDate() ?? Date(),
                                polygons: $0.createPolygonEntities(polyTitle: props.LABEL2)
            )
        }
        
        try await dba.upsertStormRisk(dto)
        logger.debug("Updated Categorical Storm Risk")
    }
    
    func refreshHailRisk() async throws {
        let risk = try await client.fetchHailRisk()
        guard let risk else { return } // if we don't have any items, just return
        
        let dto = risk.featureCollection.features.compactMap {
            makeSevereRiskDTO(for: .hail, with: $0)
        }

        try await dba.upsertHailRisk(dto)
        logger.debug("Updated Hail Risk")
    }
    
    func refreshWindRisk() async throws {
        let risk = try await client.fetchWindRisk()
        guard let risk else { return } // if we don't have any items, just return
        
        let dto = risk.featureCollection.features.compactMap {
            makeSevereRiskDTO(for: .wind, with: $0)
        }
        
        try await dba.upsertWindRisk(dto)
        logger.debug("Updated Wind Risk")
    }
    
    func refreshTornadoRisk() async throws {
        let risk = try await client.fetchTornadoRisk()
        guard let risk else { return } // if we don't have any items, just return
        
        let dto = risk.featureCollection.features.compactMap {
            makeSevereRiskDTO(for: .tornado, with: $0)
        }
        
        try await dba.upsertTornadoRisk(dto)
        logger.debug("Updated Tornado Risk")
    }
    
    private func makeConvectiveDto(from rssItem: Item) -> ConvectiveOutlookDTO? {
        guard
            let title = rssItem.title,
            let linkString = rssItem.link,
            let link = URL(string: linkString),
            let pubDateString = rssItem.pubDate,
            let summary = rssItem.description,
            let published = DateFormatter.rfc822.date(from: pubDateString)
        else { return nil }
        
        let day = title.contains("Day 1") ? 1 :
        title.contains("Day 2") ? 2 :
        title.contains("Day 3") ? 3 : nil
        
        let riskLevel = "TBD"//extractRiskLevel(from: summary)
        
        return ConvectiveOutlookDTO(
                  title: title,
                  link: link,
                  published: published,
                  summary: summary,
                  day: day,
                  riskLevel: riskLevel)
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
    
    private func makeWatchDto(from rssItem: Item) -> WatchDTO? {
        guard
            let title = rssItem.title,
            let linkString = rssItem.link,
            let link = URL(string: linkString),
            let pubDateString = rssItem.pubDate,
            let summary = rssItem.description,
            let published = DateFormatter.rfc822.date(from: pubDateString)
        else { return nil }
        
        return WatchDTO(
            title: title,
            link: link,
            issued: published,
            summary: summary
        )
    }
    
    private func makeSevereRiskDTO(for threat: ThreatType, with feature: GeoJSONFeature) -> SevereRiskDTO {
        let props = feature.properties
        let parsedProbability = getProbability(from: props)
        
        return SevereRiskDTO(type: threat,
                             probability: parsedProbability,
                             threatLevel: getThreatLevel(from: threat, probability: parsedProbability.decimalValue),
                             issued: props.ISSUE.asUTCDate() ?? Date(),
                             validUntil: props.VALID.asUTCDate() ?? Date(),
                             polygons: feature.createPolygonEntities(polyTitle: props.LABEL2)
                             )
    }
    
    private func getProbability(from properties: GeoJSONProperties) -> ThreatProbability {
        // Content comes in from both label and label2
        // When its significant label has "SIGN" and label2 has something like "10% Significant Hail Risk"
        // When its not significant then label has the percentage like "0.05" as a string
        // This is where we would possibly need to tweak that probability calculation/display
        
        if let parsedDouble = Double(properties.LABEL) {
            return .percent(parsedDouble)
        } else {
            if properties.LABEL == "SIGN" {
                let cleaned = properties.LABEL2.split(separator: "%").first?.trimmingCharacters(in: .whitespaces)
                
                if let intPercent = Int(cleaned ?? "0") {
                    return .significant(intPercent)
                }
            }
            
            return .percent(0) // shouldn't really get here, but need to cover the case.
        }
    }
    
    private func getThreatLevel(from threat: ThreatType, probability: Double) -> SevereWeatherThreat {
        switch threat {
        case .wind:
            return .wind(probability: probability)
        case .hail:
            return .hail(probability: probability)
        case .tornado:
            return .tornado(probability: probability)
        default:
            return .allClear
        }
    }
}
