//
//  SpcMapBatchPersistenceRepo.swift
//  SkyAware
//
//  Created by Codex on 5/28/26.
//

import Foundation
import SwiftData

enum SpcMapBatchPersistenceFailureInjection: Sendable {
    case none
    case afterCategoricalMutation
    case afterHailMutation
}

@ModelActor
actor SpcMapBatchPersistenceRepo {
    func commitAcceptedMapBatch(
        using client: any SpcClient,
        anchorIssued: Date,
        anchorValid: Date,
        anchorExpires: Date,
        failureInjection: SpcMapBatchPersistenceFailureInjection = .none
    ) async throws {
        let categoricalData = try await client.fetchGeoJsonData(for: .categorical)
        let hailData = try await client.fetchGeoJsonData(for: .hail)
        let windData = try await client.fetchGeoJsonData(for: .wind)
        let tornadoData = try await client.fetchGeoJsonData(for: .tornado)
        let fireData = try await client.fetchGeoJsonData(for: .fireRH)

        try modelContext.transaction {
            if Task.isCancelled { throw CancellationError() }

            let categoricalRows = try parseStormRiskRows(from: categoricalData)
            try replaceStormRows(
                inWindowIssued: anchorIssued,
                valid: anchorValid,
                expires: anchorExpires,
                with: categoricalRows
            )
            if failureInjection == .afterCategoricalMutation { throw SpcError.missingData }
            if Task.isCancelled { throw CancellationError() }

            let hailRows = try parseSevereRisks(from: hailData, threat: .hail)
            try replaceSevereRows(for: .hail, valid: anchorValid, expires: anchorExpires, with: hailRows)
            if failureInjection == .afterHailMutation { throw CancellationError() }
            if Task.isCancelled { throw CancellationError() }

            let windRows = try parseSevereRisks(from: windData, threat: .wind)
            try replaceSevereRows(for: .wind, valid: anchorValid, expires: anchorExpires, with: windRows)
            if Task.isCancelled { throw CancellationError() }

            let tornadoRows = try parseSevereRisks(from: tornadoData, threat: .tornado)
            try replaceSevereRows(for: .tornado, valid: anchorValid, expires: anchorExpires, with: tornadoRows)
            if Task.isCancelled { throw CancellationError() }

            let fireRows = try parseFireRisks(from: fireData)
            try replaceFireRows(
                inWindowIssued: anchorIssued,
                valid: anchorValid,
                expires: anchorExpires,
                with: fireRows
            )
        }
    }

    private func replaceStormRows(
        inWindowIssued issued: Date,
        valid: Date,
        expires: Date,
        with items: [StormRisk]
    ) throws {
        let predicate = #Predicate<StormRisk> {
            $0.issued == issued &&
            $0.valid == valid &&
            $0.expires == expires
        }
        let existing = try modelContext.fetch(FetchDescriptor<StormRisk>(predicate: predicate))
        for item in existing {
            modelContext.delete(item)
        }

        for item in items where item.issued == issued && item.valid == valid && item.expires == expires {
            modelContext.insert(item)
        }
    }

    private func replaceSevereRows(
        for type: ThreatType,
        valid: Date,
        expires: Date,
        with items: [SevereRisk]
    ) throws {
        let predicate = #Predicate<SevereRisk> {
            $0.valid <= expires &&
            $0.expires >= valid
        }
        let existing = try modelContext.fetch(FetchDescriptor<SevereRisk>(predicate: predicate))
        for item in existing where item.type == type {
            modelContext.delete(item)
        }

        for item in items where item.type == type && item.valid == valid && item.expires == expires {
            modelContext.insert(item)
        }
    }

    private func replaceFireRows(
        inWindowIssued issued: Date,
        valid: Date,
        expires: Date,
        with items: [FireRisk]
    ) throws {
        let predicate = #Predicate<FireRisk> {
            $0.valid <= expires &&
            $0.expires >= valid
        }
        let existing = try modelContext.fetch(FetchDescriptor<FireRisk>(predicate: predicate))
        for item in existing {
            modelContext.delete(item)
        }

        for item in items where item.issued == issued && item.valid == valid && item.expires == expires {
            modelContext.insert(item)
        }
    }

    private func parseStormRiskRows(from data: Data) throws -> [StormRisk] {
        guard let decoded: GeoJSONFeatureCollection = JsonParser.decode(from: data) else {
            throw SpcError.parsingError
        }

        return try decoded.features.map {
            let props = $0.properties

            guard
                let issued = props.ISSUE.asUTCDate(),
                let expires = props.EXPIRE.asUTCDate(),
                let valid = props.VALID.asUTCDate()
            else {
                throw SpcError.parsingError
            }

            return StormRisk(
                riskLevel: StormRiskLevel(abbreviation: props.LABEL),
                issued: issued,
                expires: expires,
                valid: valid,
                stroke: props.stroke,
                fill: props.fill,
                polygons: $0.createPolygonEntities(polyTitle: props.LABEL2)
            )
        }
    }

    private func parseSevereRisks(from data: Data, threat: ThreatType) throws -> [SevereRisk] {
        guard let decoded: GeoJSONFeatureCollection = JsonParser.decode(from: data) else {
            throw SpcError.parsingError
        }

        return try decoded.features.map {
            let props = $0.properties
            let probability = parseProbability(from: props)
            guard
                let issued = props.ISSUE.asUTCDate(),
                let valid = props.VALID.asUTCDate(),
                let expires = props.EXPIRE.asUTCDate()
            else {
                throw SpcError.parsingError
            }

            return SevereRisk(
                type: threat,
                probability: probability,
                threatLevel: severeThreatLevel(for: threat, probability: probability.decimalValue),
                issued: issued,
                valid: valid,
                expires: expires,
                dn: props.DN,
                stroke: props.stroke,
                fill: props.fill,
                polygons: $0.createPolygonEntities(polyTitle: props.LABEL2),
                label: props.LABEL
            )
        }
    }

    private func parseFireRisks(from data: Data) throws -> [FireRisk] {
        guard let decoded: GeoJSONFeatureCollection = JsonParser.decode(from: data) else {
            throw SpcError.parsingError
        }

        return try decoded.features.map {
            let props = $0.properties
            guard
                let issued = props.ISSUE.asUTCDate(),
                let expires = props.EXPIRE.asUTCDate(),
                let valid = props.VALID.asUTCDate()
            else {
                throw SpcError.parsingError
            }

            return FireRisk(
                product: "WindRH",
                issued: issued,
                expires: expires,
                valid: valid,
                riskLevel: props.DN,
                label: props.LABEL2,
                stroke: props.stroke,
                fill: props.fill,
                polygons: $0.createPolygonEntities(polyTitle: props.LABEL2)
            )
        }
    }

    private func parseProbability(from properties: GeoJSONProperties) -> ThreatProbability {
        if let parsedDouble = Double(properties.LABEL) {
            return .percent(parsedDouble)
        }

        if properties.LABEL == "SIGN" {
            let cleaned = properties.LABEL2.split(separator: "%").first?
                .trimmingCharacters(in: .whitespaces)
            if let intPercent = Int(cleaned ?? "0") {
                return .significant(intPercent)
            }
        }

        return .percent(0)
    }

    private func severeThreatLevel(for threat: ThreatType, probability: Double) -> SevereWeatherThreat {
        switch threat {
        case .wind:
            return .wind(probability: probability)
        case .hail:
            return .hail(probability: probability)
        case .tornado:
            return .tornado(probability: probability)
        case .unknown:
            return .allClear
        }
    }
}
