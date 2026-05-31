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
    private struct ConvectiveDomainBackup {
        let stormRows: [StormRisk]
        let hailRows: [SevereRisk]
        let windRows: [SevereRisk]
        let tornadoRows: [SevereRisk]
    }

    func commitAcceptedConvectiveBatch(
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
        let backup = try makeConvectiveBackup(issued: anchorIssued, valid: anchorValid, expires: anchorExpires)

        do {
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
            try modelContext.save()
        } catch {
            try restoreConvectiveBackup(backup, issued: anchorIssued, valid: anchorValid, expires: anchorExpires)
            throw error
        }
    }

    func commitAcceptedFireBatch(
        using client: any SpcClient,
        anchorIssued: Date,
        anchorValid: Date,
        anchorExpires: Date
    ) async throws {
        let fireData = try await client.fetchGeoJsonData(for: .fireRH)
        let backup = try makeFireBackup(valid: anchorValid, expires: anchorExpires)

        do {
            if Task.isCancelled { throw CancellationError() }

            let fireRows = try parseFireRisks(from: fireData)
            try replaceFireRows(
                inWindowIssued: anchorIssued,
                valid: anchorValid,
                expires: anchorExpires,
                with: fireRows
            )
            try modelContext.save()
        } catch {
            try restoreFireBackup(backup, valid: anchorValid, expires: anchorExpires)
            throw error
        }
    }

    func commitAcceptedAllClearConvectiveBatch(
        syncTime: Date,
        failureInjection: SpcMapBatchPersistenceFailureInjection = .none
    ) async throws {
        let backup = try makeActiveConvectiveBackup(asOf: syncTime)

        do {
            if Task.isCancelled { throw CancellationError() }

            try clearActiveStormRows(asOf: syncTime)
            if failureInjection == .afterCategoricalMutation { throw SpcError.missingData }
            if Task.isCancelled { throw CancellationError() }

            try clearActiveSevereRows(asOf: syncTime, type: .hail)
            if failureInjection == .afterHailMutation { throw CancellationError() }
            if Task.isCancelled { throw CancellationError() }

            try clearActiveSevereRows(asOf: syncTime, type: .wind)
            if Task.isCancelled { throw CancellationError() }

            try clearActiveSevereRows(asOf: syncTime, type: .tornado)
            try modelContext.save()
        } catch {
            try restoreActiveConvectiveBackup(backup, asOf: syncTime)
            throw error
        }
    }

    func commitAcceptedAllClearFireBatch(syncTime: Date) async throws {
        let backup = try makeActiveFireBackup(asOf: syncTime)

        do {
            if Task.isCancelled { throw CancellationError() }
            try clearActiveFireRows(asOf: syncTime)
            try modelContext.save()
        } catch {
            try restoreActiveFireBackup(backup, asOf: syncTime)
            throw error
        }
    }

    private func makeConvectiveBackup(issued: Date, valid: Date, expires: Date) throws -> ConvectiveDomainBackup {
        ConvectiveDomainBackup(
            stormRows: try fetchStormRows(issued: issued, valid: valid, expires: expires).map(copyStormRisk),
            hailRows: try fetchSevereRows(type: .hail, valid: valid, expires: expires).map(copySevereRisk),
            windRows: try fetchSevereRows(type: .wind, valid: valid, expires: expires).map(copySevereRisk),
            tornadoRows: try fetchSevereRows(type: .tornado, valid: valid, expires: expires).map(copySevereRisk)
        )
    }

    private func restoreConvectiveBackup(
        _ backup: ConvectiveDomainBackup,
        issued: Date,
        valid: Date,
        expires: Date
    ) throws {
        try replaceStormRows(inWindowIssued: issued, valid: valid, expires: expires, with: backup.stormRows)
        try replaceSevereRows(for: .hail, valid: valid, expires: expires, with: backup.hailRows)
        try replaceSevereRows(for: .wind, valid: valid, expires: expires, with: backup.windRows)
        try replaceSevereRows(for: .tornado, valid: valid, expires: expires, with: backup.tornadoRows)
        try modelContext.save()
    }

    private func makeActiveConvectiveBackup(asOf now: Date) throws -> ConvectiveDomainBackup {
        ConvectiveDomainBackup(
            stormRows: try fetchActiveStormRows(asOf: now).map(copyStormRisk),
            hailRows: try fetchActiveSevereRows(asOf: now, type: .hail).map(copySevereRisk),
            windRows: try fetchActiveSevereRows(asOf: now, type: .wind).map(copySevereRisk),
            tornadoRows: try fetchActiveSevereRows(asOf: now, type: .tornado).map(copySevereRisk)
        )
    }

    private func restoreActiveConvectiveBackup(_ backup: ConvectiveDomainBackup, asOf now: Date) throws {
        try clearActiveStormRows(asOf: now)
        try clearActiveSevereRows(asOf: now, type: .hail)
        try clearActiveSevereRows(asOf: now, type: .wind)
        try clearActiveSevereRows(asOf: now, type: .tornado)
        for row in backup.stormRows { modelContext.insert(copyStormRisk(row)) }
        for row in backup.hailRows { modelContext.insert(copySevereRisk(row)) }
        for row in backup.windRows { modelContext.insert(copySevereRisk(row)) }
        for row in backup.tornadoRows { modelContext.insert(copySevereRisk(row)) }
        try modelContext.save()
    }

    private func makeFireBackup(valid: Date, expires: Date) throws -> [FireRisk] {
        try fetchFireRows(valid: valid, expires: expires).map(copyFireRisk)
    }

    private func restoreFireBackup(_ backup: [FireRisk], valid: Date, expires: Date) throws {
        let predicate = #Predicate<FireRisk> {
            $0.valid <= expires &&
            $0.expires >= valid
        }
        let existing = try modelContext.fetch(FetchDescriptor<FireRisk>(predicate: predicate))
        for row in existing {
            modelContext.delete(row)
        }
        for row in backup {
            modelContext.insert(copyFireRisk(row))
        }
        try modelContext.save()
    }

    private func makeActiveFireBackup(asOf now: Date) throws -> [FireRisk] {
        try fetchActiveFireRows(asOf: now).map(copyFireRisk)
    }

    private func restoreActiveFireBackup(_ backup: [FireRisk], asOf now: Date) throws {
        try clearActiveFireRows(asOf: now)
        for row in backup { modelContext.insert(copyFireRisk(row)) }
        try modelContext.save()
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

    private func fetchStormRows(issued: Date, valid: Date, expires: Date) throws -> [StormRisk] {
        let predicate = #Predicate<StormRisk> {
            $0.issued == issued &&
            $0.valid == valid &&
            $0.expires == expires
        }
        return try modelContext.fetch(FetchDescriptor<StormRisk>(predicate: predicate))
    }

    private func fetchSevereRows(type: ThreatType, valid: Date, expires: Date) throws -> [SevereRisk] {
        let predicate = #Predicate<SevereRisk> {
            $0.valid <= expires &&
            $0.expires >= valid
        }
        return try modelContext.fetch(FetchDescriptor<SevereRisk>(predicate: predicate))
            .filter { $0.type == type }
    }

    private func fetchFireRows(valid: Date, expires: Date) throws -> [FireRisk] {
        let predicate = #Predicate<FireRisk> {
            $0.valid <= expires &&
            $0.expires >= valid
        }
        return try modelContext.fetch(FetchDescriptor<FireRisk>(predicate: predicate))
    }

    private func fetchActiveStormRows(asOf now: Date) throws -> [StormRisk] {
        let predicate = #Predicate<StormRisk> {
            $0.valid <= now &&
            $0.expires >= now
        }
        return try modelContext.fetch(FetchDescriptor<StormRisk>(predicate: predicate))
    }

    private func fetchActiveSevereRows(asOf now: Date, type: ThreatType) throws -> [SevereRisk] {
        let predicate = #Predicate<SevereRisk> {
            $0.valid <= now &&
            $0.expires >= now
        }
        return try modelContext.fetch(FetchDescriptor<SevereRisk>(predicate: predicate))
            .filter { $0.type == type }
    }

    private func fetchActiveFireRows(asOf now: Date) throws -> [FireRisk] {
        let predicate = #Predicate<FireRisk> {
            $0.valid <= now &&
            $0.expires >= now
        }
        return try modelContext.fetch(FetchDescriptor<FireRisk>(predicate: predicate))
    }

    private func copyStormRisk(_ item: StormRisk) -> StormRisk {
        StormRisk(
            riskLevel: item.riskLevel,
            issued: item.issued,
            expires: item.expires,
            valid: item.valid,
            stroke: item.stroke,
            fill: item.fill,
            polygons: item.polygons
        )
    }

    private func copySevereRisk(_ item: SevereRisk) -> SevereRisk {
        SevereRisk(
            type: item.type,
            probability: item.probability,
            threatLevel: item.threatLevel,
            issued: item.issued,
            valid: item.valid,
            expires: item.expires,
            dn: item.probability.intValue,
            stroke: item.stroke,
            fill: item.fill,
            polygons: item.polygons,
            label: item.label ?? ""
        )
    }

    private func copyFireRisk(_ item: FireRisk) -> FireRisk {
        FireRisk(
            product: item.product,
            issued: item.issued,
            expires: item.expires,
            valid: item.valid,
            riskLevel: item.riskLevel,
            label: item.label,
            stroke: item.stroke,
            fill: item.fill,
            polygons: item.polygons
        )
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

    private func clearActiveStormRows(asOf now: Date) throws {
        let predicate = #Predicate<StormRisk> {
            $0.valid <= now &&
            $0.expires >= now
        }
        let existing = try modelContext.fetch(FetchDescriptor<StormRisk>(predicate: predicate))
        for row in existing {
            modelContext.delete(row)
        }
    }

    private func clearActiveSevereRows(asOf now: Date, type: ThreatType) throws {
        let predicate = #Predicate<SevereRisk> {
            $0.valid <= now &&
            $0.expires >= now
        }
        let existing = try modelContext.fetch(FetchDescriptor<SevereRisk>(predicate: predicate))
        for row in existing where row.type == type {
            modelContext.delete(row)
        }
    }

    private func clearActiveFireRows(asOf now: Date) throws {
        let predicate = #Predicate<FireRisk> {
            $0.valid <= now &&
            $0.expires >= now
        }
        let existing = try modelContext.fetch(FetchDescriptor<FireRisk>(predicate: predicate))
        for row in existing {
            modelContext.delete(row)
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
