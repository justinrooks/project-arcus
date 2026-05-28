//
//  FireRiskRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 2/16/26.
//

import CoreLocation
import Foundation
import OSLog
import SwiftData

@ModelActor
actor FireRiskRepo {
    private let logger = Logger.reposFireRisk

    func refreshFireRisk(using client: any SpcClient) async throws {
        let data = try await client.fetchGeoJsonData(for: .fireRH)
        guard let decoded: GeoJSONFeatureCollection = JsonParser.decode(from: data) else {
            throw SpcError.parsingError
        }

        let dtos = try decoded.features.map {
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

        try replaceCurrentAndFutureRows(with: dtos)
        logger.debug(
            "Updated \(dtos.count, privacy: .public) fire risk feature\(dtos.count > 1 ? "s" : "", privacy: .public)"
        )
    }

    /// Returns the strongest fire risk level whose polygon contains the given point, as of `date`.
        func active(asOf date: Date = .init(), for point: CLLocationCoordinate2D) throws -> FireRiskLevel {
            let pred = #Predicate<FireRisk> { date >= $0.valid && date <= $0.expires }
            let risks = try modelContext.fetch(FetchDescriptor<FireRisk>(predicate: pred))
            let latestRisks = latestIssuanceSlice(from: risks)
    
            // Sort by descending risk so we can early-exit on first hit.
            let bySeverity = latestRisks.sorted { $0.riskLevel > $1.riskLevel }
    
            // 3) For each risk, check polygons with optional bbox prefilter, then precise hit test
            for risk in bySeverity {
                for poly in risk.polygons {
                    // Coarse bbox prefilter if available
                    if let bbox = poly.bbox, bbox.contains(point) == false { continue }
    
                    // Precise hit test on ring coordinates
                    let ring = poly.ringCoordinates
                    guard !ring.isEmpty else { continue }
                    if MesoGeometry.contains(point, inRing: ring) {
                        switch risk.riskLevel {
                        case 5: return .elevated
                        case 8: return .critical
                        case 10: return .extreme
                        default: return .clear
                        }
                    }
                }
            }
    
            return .clear
        }

    func getLatestMapData(asOf date: Date = .init()) throws -> [FireRiskDTO] {
        let pred = #Predicate<FireRisk> {
            $0.valid <= date && date <= $0.expires
        }
        let desc = FetchDescriptor<FireRisk>(predicate: pred)
        let risks = try modelContext.fetch(desc)
        let latestRisks = latestIssuanceSlice(from: risks)

        // For each risk level, keep only the most recent record within the latest issuance.
        let mostRecentByLevel: [Int: FireRisk] = Dictionary(
            latestRisks.map { ($0.riskLevel, $0) },
            uniquingKeysWith: { lhs, rhs in
                self.isMoreRecent(lhs, than: rhs) ? lhs : rhs
            }
        )

        let selected = mostRecentByLevel.values.sorted { $0.riskLevel > $1.riskLevel }

        return selected.map {
            FireRiskDTO(
                product: $0.product,
                issued: $0.issued,
                expires: $0.expires,
                valid: $0.valid,
                riskLevel: $0.riskLevel,
                riskLevelDescription: $0.riskLevelDescription,
                label: $0.label,
                stroke: $0.stroke,
                fill: $0.fill,
                polygons: $0.polygons
            )
        }
    }

    func purge(asOf now: Date = .init()) throws {
        logger.info("Purging expired fire risk geometry")

        // Fetch in batches to avoid large in-memory sets
        let predicate = #Predicate<FireRisk> { $0.expires < now }
        var desc = FetchDescriptor<FireRisk>(predicate: predicate)
        desc.fetchLimit = 50

        while true {
            let batch = try modelContext.fetch(desc)
            if batch.isEmpty { break }
            logger.debug("Found \(batch.count, privacy: .public) to purge")

            for obj in batch { modelContext.delete(obj) }

            try modelContext.save()
        }

        logger.info("Purged old fire risk geometry")
    }

    private func replaceCurrentAndFutureRows(with items: [FireRisk], asOf now: Date = .init()) throws {
        let predicate = #Predicate<FireRisk> { $0.expires >= now }
        let existing = try modelContext.fetch(FetchDescriptor<FireRisk>(predicate: predicate))
        for item in existing {
            modelContext.delete(item)
        }

        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }

    private func latestIssuanceSlice(from risks: [FireRisk]) -> [FireRisk] {
        guard let latest = risks.max(by: { lhs, rhs in isMoreRecent(rhs, than: lhs) }) else { return [] }
        return risks.filter {
            $0.issued == latest.issued &&
            $0.valid == latest.valid &&
            $0.expires == latest.expires
        }
    }

    private func isMoreRecent(_ lhs: FireRisk, than rhs: FireRisk) -> Bool {
        if lhs.issued != rhs.issued { return lhs.issued > rhs.issued }
        if lhs.valid != rhs.valid { return lhs.valid > rhs.valid }
        if lhs.expires != rhs.expires { return lhs.expires > rhs.expires }
        return lhs.key > rhs.key
    }
}
