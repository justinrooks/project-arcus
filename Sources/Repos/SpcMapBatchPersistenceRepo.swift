//
//  SpcMapBatchPersistenceRepo.swift
//  SkyAware
//
//  Created by Codex on 5/28/26.
//

import Foundation
import CoreLocation
import SwiftData

enum SpcMapBatchPersistenceFailureInjection: Sendable {
    case none
    case afterCategoricalMutation
    case afterHailMutation
}

@Model
final class SPCAcceptedDay1Convective {
    var id: UUID
    var issued: Date?
    var valid: Date?
    var expires: Date?
    var acceptedAt: Date
    var stormCount: Int
    var severeCount: Int

    init(
        issued: Date?, valid: Date?, expires: Date?, acceptedAt: Date,
        stormCount: Int, severeCount: Int
    ) {
        id = UUID()
        self.issued = issued
        self.valid = valid
        self.expires = expires
        self.acceptedAt = acceptedAt
        self.stormCount = stormCount
        self.severeCount = severeCount
    }

    var source: SpcMapSourceIdentity? {
        if stormCount == 0 && severeCount == 0 { return .acceptedAllClear(at: acceptedAt) }
        guard let issued, let valid, let expires else { return nil }
        return .forecast(issued: issued, valid: valid, expires: expires)
    }

    func isEffective(at now: Date, newlyAcceptedSource: SpcMapSourceIdentity?) -> Bool {
        guard acceptedAt <= now, let source else { return false }
        if let issued, let valid, let expires {
            return issued <= now && valid <= now && now < expires
        }
        // The existing immediate acceptance of undated empties does not establish a reusable validity window.
        return stormCount == 0 && severeCount == 0 && source == newlyAcceptedSource
    }
}

struct SPCDay1LocalRisk: Sendable, Equatable {
    let revision: UUID
    let source: SpcMapSourceIdentity
    let acceptedAt: Date
    let storm: StormRiskLevel
    let severe: SevereWeatherThreat
    let latitude: Double
    let longitude: Double
}

@ModelActor
actor SpcMapBatchPersistenceRepo {
    // The Home store validates this revision and saves its projection without suspending under the same lock.
    static let day1CommitLock = NSLock()

    static func acceptedDay1Revision(in context: ModelContext) throws -> SPCAcceptedDay1Convective? {
        var descriptor = FetchDescriptor<SPCAcceptedDay1Convective>()
        descriptor.fetchLimit = 2
        let revisions = try context.fetch(descriptor)
        return revisions.count == 1 ? revisions.first : nil
    }

    static func acceptedDay1Risk(
        in context: ModelContext, for point: CLLocationCoordinate2D, at now: Date,
        newlyAcceptedSource: SpcMapSourceIdentity?
    ) throws -> SPCDay1LocalRisk? {
        guard CLLocationCoordinate2DIsValid(point),
              let revision = try acceptedDay1Revision(in: context),
              let source = revision.source,
              revision.isEffective(at: now, newlyAcceptedSource: newlyAcceptedSource) else { return nil }
        let storm: StormRiskLevel
        let severe: SevereWeatherThreat
        if case .forecast(let issued, let valid, let expires) = source {
            let storms = try context.fetch(FetchDescriptor<StormRisk>(predicate: #Predicate {
                $0.issued == issued && $0.valid == valid && $0.expires == expires
            }))
            let hazards = try context.fetch(FetchDescriptor<SevereRisk>(predicate: #Predicate {
                $0.issued == issued && $0.valid == valid && $0.expires == expires
            }))
            guard revision.stormCount > 0, storms.count == revision.stormCount,
                  hazards.count == revision.severeCount,
                  storms.allSatisfy({ !$0.polygons.isEmpty }), hazards.allSatisfy({ !$0.polygons.isEmpty })
            else { return nil }
            storm = StormRiskRepo.strongestLocalRisk(in: storms, for: point)
            severe = SevereRiskRepo.strongestLocalRisk(in: hazards, for: point)
        } else {
            storm = .allClear
            severe = .allClear
        }
        return .init(
            revision: revision.id, source: source, acceptedAt: revision.acceptedAt, storm: storm, severe: severe,
            latitude: point.latitude, longitude: point.longitude
        )
    }

    private func replaceAcceptedDay1Revision(_ revision: SPCAcceptedDay1Convective) throws {
        for previous in try modelContext.fetch(FetchDescriptor<SPCAcceptedDay1Convective>()) {
            modelContext.delete(previous)
        }
        modelContext.insert(revision)
    }

    func acceptHazardForecast(
        _ responses: [GeoJSONProduct: HTTPResponse], day: SPCForecastDay, now: Date
    ) throws {
        guard responses.count == 3,
              responses.values.allSatisfy({ $0.source == .live || $0.source == .cacheRevalidated304 }),
              let tornado = responses[.tornado]?.data, let hail = responses[.hail]?.data,
              let wind = responses[.wind]?.data else { throw SpcError.parsingError }
        let snapshot = try SPCHazardForecastSnapshot.parse(tornado: tornado, hail: hail, wind: wind, day: day)
        guard snapshot.issued <= now, snapshot.valid > now,
              now.timeIntervalSince(snapshot.issued) < 86400 else { throw SpcError.parsingError }
        let rows = try modelContext.fetch(FetchDescriptor<SPCHazardForecast>())
        guard rows.allSatisfy({ $0.issued <= snapshot.issued && $0.valid <= snapshot.valid }) else {
            throw SpcError.parsingError
        }
        try Task.checkCancellation()
        if let previous = rows.first, previous.issued == snapshot.issued {
            guard previous.tornado == tornado, previous.hail == hail, previous.wind == wind else {
                throw SpcError.parsingError
            }
            return
        }
        do {
            for row in rows { modelContext.delete(row) }
            modelContext.insert(SPCHazardForecast(snapshot: snapshot, tornado: tornado, hail: hail, wind: wind, now: now))
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Reads accepted geometry with its source period, including expired last-known-good data.
    func hazardForecast(for day: SPCForecastDay) throws -> SPCHazardForecastSnapshot? {
        guard day == .day2 else { throw SpcError.parsingError }
        guard let row = try modelContext.fetch(FetchDescriptor<SPCHazardForecast>()).first else { return nil }
        return try SPCHazardForecastSnapshot.parse(tornado: row.tornado, hail: row.hail, wind: row.wind, day: day)
    }

    /// Replaces only this forecast day, atomically with its source identity and explicit empty state.
    func acceptCategoricalForecast(
        _ data: Data, day: SPCForecastDay, source: HTTPResponse.Source, now: Date
    ) throws {
        guard source == .live || source == .cacheRevalidated304 else { throw SpcError.parsingError }
        let snapshot = try SPCCategoricalForecastSnapshot.parse(data, day: day)
        guard snapshot.issued <= now, snapshot.valid > now,
              now.timeIntervalSince(snapshot.issued) < 86400 else { throw SpcError.parsingError }
        let dayValue = day.rawValue
        let rows = try modelContext.fetch(FetchDescriptor<SPCCategoricalForecast>(
            predicate: #Predicate { $0.day == dayValue }
        ))
        guard rows.allSatisfy({ $0.issued <= snapshot.issued && $0.valid <= snapshot.valid }) else {
            throw SpcError.parsingError
        }
        // Identical issuance metadata with different geometry is an incomplete/corrected publication.
        // Wait for a new source issuance rather than accepting a partial replacement.
        if let previous = rows.first, previous.issued == snapshot.issued {
            guard previous.payload == data else { throw SpcError.parsingError }
            return
        }
        do {
            try Task.checkCancellation()
            for row in rows { modelContext.delete(row) }
            modelContext.insert(SPCCategoricalForecast(
                day: day, snapshot: snapshot, payload: data,
                source: source == .live ? "live" : "revalidated", now: now
            ))
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// nil is never-loaded; an accepted snapshot may be empty or expired and remains cache-forward.
    func categoricalForecast(for day: SPCForecastDay) throws -> SPCCategoricalForecastSnapshot? {
        let dayValue = day.rawValue
        let rows = try modelContext.fetch(FetchDescriptor<SPCCategoricalForecast>(
            predicate: #Predicate { $0.day == dayValue }
        ))
        guard let row = rows.first else { return nil }
        return try SPCCategoricalForecastSnapshot.parse(row.payload, day: day)
    }

    func commitAcceptedConvectiveBatch(
        using client: any SpcClient,
        anchorIssued: Date,
        anchorValid: Date,
        anchorExpires: Date,
        acceptedAt: Date = .now,
        failureInjection: SpcMapBatchPersistenceFailureInjection = .none
    ) async throws {
        let categoricalData = try await client.fetchGeoJsonData(for: .categorical)
        let hailData = try await client.fetchGeoJsonData(for: .hail)
        let windData = try await client.fetchGeoJsonData(for: .wind)
        let tornadoData = try await client.fetchGeoJsonData(for: .tornado)
        let categorical = try parseStormRiskRows(from: categoricalData)
        let hail = try parseSevereRisks(from: hailData, threat: .hail)
        let wind = try parseSevereRisks(from: windData, threat: .wind)
        let tornado = try parseSevereRisks(from: tornadoData, threat: .tornado)

        try commitDay1 {
            try replaceStormRows(
                inWindowIssued: anchorIssued, valid: anchorValid, expires: anchorExpires, with: categorical
            )
            if failureInjection == .afterCategoricalMutation { throw SpcError.missingData }
            try replaceSevereRows(for: .hail, valid: anchorValid, expires: anchorExpires, with: hail)
            if failureInjection == .afterHailMutation { throw CancellationError() }
            try replaceSevereRows(for: .wind, valid: anchorValid, expires: anchorExpires, with: wind)
            try replaceSevereRows(for: .tornado, valid: anchorValid, expires: anchorExpires, with: tornado)
            return SPCAcceptedDay1Convective(
                issued: anchorIssued, valid: anchorValid, expires: anchorExpires, acceptedAt: acceptedAt,
                stormCount: categorical.count, severeCount: hail.count + wind.count + tornado.count
            )
        }
    }

    private func commitDay1(_ update: () throws -> SPCAcceptedDay1Convective) throws {
        try Self.day1CommitLock.withLock {
            do {
                try Task.checkCancellation()
                let revision = try update()
                try Task.checkCancellation()
                try replaceAcceptedDay1Revision(revision)
                try modelContext.save()
            } catch {
                modelContext.rollback()
                throw error
            }
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
        window: (issued: Date, valid: Date, expires: Date)? = nil,
        failureInjection: SpcMapBatchPersistenceFailureInjection = .none
    ) throws {
        try commitDay1 {
            try clearActiveStormRows(asOf: syncTime)
            if failureInjection == .afterCategoricalMutation { throw SpcError.missingData }
            try clearActiveSevereRows(asOf: syncTime, type: .hail)
            if failureInjection == .afterHailMutation { throw CancellationError() }
            try clearActiveSevereRows(asOf: syncTime, type: .wind)
            try clearActiveSevereRows(asOf: syncTime, type: .tornado)
            return SPCAcceptedDay1Convective(
                issued: window?.issued, valid: window?.valid, expires: window?.expires, acceptedAt: syncTime,
                stormCount: 0, severeCount: 0
            )
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

    private func fetchFireRows(valid: Date, expires: Date) throws -> [FireRisk] {
        let predicate = #Predicate<FireRisk> {
            $0.valid <= expires &&
            $0.expires >= valid
        }
        return try modelContext.fetch(FetchDescriptor<FireRisk>(predicate: predicate))
    }

    private func fetchActiveFireRows(asOf now: Date) throws -> [FireRisk] {
        let predicate = #Predicate<FireRisk> {
            $0.valid <= now &&
            $0.expires >= now
        }
        return try modelContext.fetch(FetchDescriptor<FireRisk>(predicate: predicate))
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
