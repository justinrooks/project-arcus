//
//  SpcRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import CoreLocation
import Foundation
import OSLog
import SwiftData

@ModelActor
actor SevereRiskRepo {
    private let logger = Logger.reposSevereRisk

    func refreshHailRisk(using client: any SpcClient) async throws {
        let data = try await client.fetchGeoJsonData(for: .hail)

        let decoded: GeoJSONFeatureCollection = JsonParser.decode(from: data) as GeoJSONFeatureCollection? ?? .empty

        if decoded.features.count == 0 {
            logger.debug("No hail risk features to parse")
            return
        }

        let dtos = decoded.features.compactMap {
            makeSevereRisk(for: .hail, with: $0)
        }

        try upsert(dtos)
        logger.debug(
            "Updated \(dtos.count, privacy: .public) hail risk feature\(dtos.count > 1 ? "s" : "", privacy: .public)"
        )
    }

    func refreshWindRisk(using client: any SpcClient) async throws {
        let data = try await client.fetchGeoJsonData(for: .wind)

        let decoded: GeoJSONFeatureCollection = JsonParser.decode(from: data) as GeoJSONFeatureCollection? ?? .empty

        if decoded.features.count == 0 {
            logger.debug("No wind risk features to parse")
            return
        }

        let dtos = decoded.features.compactMap {
            makeSevereRisk(for: .wind, with: $0)
        }

        try upsert(dtos)
        logger.debug(
            "Updated \(dtos.count, privacy: .public) wind risk feature\(dtos.count > 1 ? "s" : "", privacy: .public)"
        )
    }

    /// Testable overload that allows injecting a client
    func refreshTornadoRisk(using client: any SpcClient) async throws {
        let data = try await client.fetchGeoJsonData(for: .tornado)

        let decoded: GeoJSONFeatureCollection = JsonParser.decode(from: data) as GeoJSONFeatureCollection? ?? .empty

        if decoded.features.count == 0 {
            logger.debug("No tornado risk features to parse")
            return
        }

        let dtos = decoded.features.compactMap {
            makeSevereRisk(for: .tornado, with: $0)
        }

        try upsert(dtos)
        logger.debug(
            "Updated \(dtos.count, privacy: .public) tornado risk feature\(dtos.count > 1 ? "s" : "", privacy: .public)"
        )
    }

    /// Returns the strongest storm risk level whose polygon contains the given point, as of `date`.
    func active(asOf date: Date = .init(), for point: CLLocationCoordinate2D)
        throws -> SevereWeatherThreat
    {
        // 1) Fetch only risks that are currently valid
        let pred = #Predicate<SevereRisk> {
            date >= $0.valid && date <= $0.expires
        }
        let risks = try modelContext.fetch(
            FetchDescriptor<SevereRisk>(predicate: pred)
        )

        // 2) Sort by descending severity so we can early-exit on first hit.
        //    Within a threat type, prefer higher probability and then fresher issuances.
        let bySeverity = risks.sorted { lhs, rhs in
            if lhs.threatLevel.priority != rhs.threatLevel.priority {
                return lhs.threatLevel.priority > rhs.threatLevel.priority
            }

            let lhsProbability = lhs.probability.decimalValue
            let rhsProbability = rhs.probability.decimalValue
            if lhsProbability != rhsProbability {
                return lhsProbability > rhsProbability
            }

            if lhs.issued != rhs.issued { return lhs.issued > rhs.issued }
            if lhs.valid != rhs.valid { return lhs.valid > rhs.valid }
            if lhs.expires != rhs.expires { return lhs.expires > rhs.expires }
            return lhs.key > rhs.key
        }

        // 3) For each risk, check polygons with optional bbox prefilter, then precise hit test
        for risk in bySeverity {
            for poly in risk.polygons {
                // Coarse bbox prefilter if available
                if let bbox = poly.bbox, bbox.contains(point) == false {
                    continue
                }

                // Precise hit test on ring coordinates
                let ring = poly.ringCoordinates
                guard !ring.isEmpty else { continue }
                if MesoGeometry.contains(point, inRing: ring) {
                    return risk.threatLevel
                }
            }
        }

        return .allClear
    }

    func getSevereRiskShapes(asOf date: Date = .init()) throws
        -> [SevereRiskShapeDTO]
    {
        // Target only items that are both valid and not expired.
        let desc = FetchDescriptor<SevereRisk>(
            predicate: #Predicate<SevereRisk> {
                $0.valid <= date && date <= $0.expires
            }
        )

        // Keep only the freshest record per type + probability bucket.
        // CIG overlays are bucketed independently so they are not collapsed into percent(0) buckets.
        let risks = try modelContext.fetch(desc)
        var mostRecentByBucket: [SevereRiskBucket: SevereRisk] = [:]

        for risk in risks {
            let bucket = SevereRiskBucket(
                type: risk.type,
                probability: risk.probability,
                intensityLevel: SevereRiskShapeDTO.intensityLevel(from: risk.label ?? "")
            )
            if let current = mostRecentByBucket[bucket] {
                if isMoreRecent(risk, than: current) {
                    mostRecentByBucket[bucket] = risk
                }
            } else {
                mostRecentByBucket[bucket] = risk
            }
        }

        var result: [SevereRiskShapeDTO] = []

        for (_, data) in mostRecentByBucket {
            result.append(
                SevereRiskShapeDTO(
                    type: data.type,
                    probabilities: data.probability,
                    stroke: data.stroke,
                    fill: data.fill,
                    polygons: data.polygons,
                    label: data.label ?? ""
                )
            )
        }

        return result

    }

    func purge(asOf now: Date = .init()) throws {
        logger.info("Purging expired severe risk geometry")

        // Fetch in batches to avoid large in-memory sets
        let predicate = #Predicate<SevereRisk> { $0.expires < now }
        var desc = FetchDescriptor<SevereRisk>(predicate: predicate)
        desc.fetchLimit = 50

        while true {
            let batch = try modelContext.fetch(desc)
            if batch.isEmpty { break }
            logger.debug("Found \(batch.count, privacy: .public) to purge")

            for obj in batch { modelContext.delete(obj) }

            try modelContext.save()
        }

        logger.info("Purged old severe risk geometry")
    }

    private func makeSevereRisk(
        for threat: ThreatType,
        with feature: GeoJSONFeature
    ) -> SevereRisk {
        let props = feature.properties
        let parsedProbability = getProbability(from: props)

        return SevereRisk(
            type: threat,
            probability: parsedProbability,
            threatLevel: getThreatLevel(
                from: threat,
                probability: parsedProbability.decimalValue
            ),
            issued: props.ISSUE.asUTCDate() ?? Date(),
            valid: props.VALID.asUTCDate() ?? Date(),
            expires: props.EXPIRE.asUTCDate() ?? Date(),
            dn: props.DN,
            stroke: props.stroke,
            fill: props.fill,
            polygons: feature.createPolygonEntities(polyTitle: props.LABEL2),
            label: props.LABEL
        )
    }

    private func getProbability(from properties: GeoJSONProperties)
        -> ThreatProbability
    {
        // Content comes in from both label and label2
        // When its significant label has "SIGN" and label2 has something like "10% Significant Hail Risk"
        // When its not significant then label has the percentage like "0.05" as a string
        // This is where we would possibly need to tweak that probability calculation/display

        if let parsedDouble = Double(properties.LABEL) {
            return .percent(parsedDouble)
        } else {
            if properties.LABEL == "SIGN" {
                let cleaned = properties.LABEL2.split(separator: "%").first?
                    .trimmingCharacters(in: .whitespaces)

                if let intPercent = Int(cleaned ?? "0") {
                    return .significant(intPercent)
                }
            }

            return .percent(0)  // shouldn't really get here, but need to cover the case.
        }
    }

    private func getThreatLevel(from threat: ThreatType, probability: Double)
        -> SevereWeatherThreat
    {
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

    private func upsert(_ items: [any PersistentModel]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }

    private func isMoreRecent(_ lhs: SevereRisk, than rhs: SevereRisk) -> Bool {
        if lhs.issued != rhs.issued { return lhs.issued > rhs.issued }
        if lhs.valid != rhs.valid { return lhs.valid > rhs.valid }
        if lhs.expires != rhs.expires { return lhs.expires > rhs.expires }
        return lhs.key > rhs.key
    }
}

private struct SevereRiskBucket: Hashable {
    let type: ThreatType
    let probability: ThreatProbability
    let intensityLevel: Int?
}
