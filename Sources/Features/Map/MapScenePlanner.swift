//
//  MapScenePlanner.swift
//  SkyAware
//
//  Created by Codex on 7/13/26.
//

import Foundation
import OSLog
import ArcusCore

struct MapDataPayload: Sendable {
    let stormRisk: MapFetchOutcome<[StormRiskDTO]>
    let severeRisks: MapFetchOutcome<[SevereRiskShapeDTO]>
    let mesos: MapFetchOutcome<[MdDTO]>
    let fireRisk: MapFetchOutcome<[FireRiskDTO]>
    let activeWarnings: [ActiveWarningGeometry]
}

enum MapFetchOutcome<Value: Sendable>: Sendable {
    case success(Value)
    case failure
    case cancelled

    var isCancellation: Bool {
        if case .cancelled = self {
            return true
        }
        return false
    }

    var value: Value? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
}

actor MapScenePlanner {
    func buildRenderPlans(
        payload: MapDataPayload,
        existingPlans: [MapLayer: MapLayerRenderPlan],
        polygonMapper: MapPolygonMapper,
        warningPolygons: KeyedMapPolygons
    ) -> [MapLayer: MapLayerRenderPlan] {
        Dictionary(
            uniqueKeysWithValues: MapLayer.allCases.map { layer in
                (
                    layer,
                    MapRenderPlanBuilder.build(
                        layer: layer,
                        payload: payload,
                        existingPlan: existingPlans[layer],
                        polygonMapper: polygonMapper,
                        warningPolygons: warningPolygons
                    )
                )
            }
        )
    }
}

private extension Result {
    var isCancellation: Bool {
        if case .failure(let error) = self, error is CancellationError {
            return true
        }
        return false
    }
}

private extension Result where Success == [SevereRiskShapeDTO], Failure == Error {
    func value(orLogging label: StaticString, logger: Logger) -> [SevereRiskShapeDTO] {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            if error is CancellationError { return [] }
            logger.error("Failed to load \(label): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}

private extension Result where Success == [StormRiskDTO], Failure == Error {
    func value(orLogging label: StaticString, logger: Logger) -> [StormRiskDTO] {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            if error is CancellationError { return [] }
            logger.error("Failed to load \(label): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}

private extension Result where Success == [MdDTO], Failure == Error {
    func value(orLogging label: StaticString, logger: Logger) -> [MdDTO] {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            if error is CancellationError { return [] }
            logger.error("Failed to load \(label): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}

private extension Result where Success == [FireRiskDTO], Failure == Error {
    func value(orLogging label: StaticString, logger: Logger) -> [FireRiskDTO] {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            if error is CancellationError { return [] }
            logger.error("Failed to load \(label): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
