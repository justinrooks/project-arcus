//
//  MapRenderPlan.swift
//  SkyAware
//
//  Created by Codex on 7/13/26.
//

import MapKit
import ArcusCore

struct MapOverlayBuildPlan: Sendable {
    enum Kind: Sendable {
        case probability
        case intensity(level: Int)
        case warning
    }

    let key: String
    let polygonKey: String
    let kind: Kind
    let signature: Int
}

struct MapLayerRenderPlan: Sendable {
    let layer: MapLayer
    let polygonEntries: [MapPolygonEntry]
    let overlayPlans: [MapOverlayBuildPlan]
    let overlayRevision: Int
    let legendState: MapLegendState

    func withLegendState(_ legendState: MapLegendState) -> MapLayerRenderPlan {
        MapLayerRenderPlan(
            layer: layer,
            polygonEntries: polygonEntries,
            overlayPlans: overlayPlans,
            overlayRevision: overlayRevision,
            legendState: legendState
        )
    }
}

@MainActor
enum MapSceneMaterializer {
    static func materialize(
        plan: MapLayerRenderPlan,
        initialCenterCoordinate: CLLocationCoordinate2D?,
        showsWarningGeometry: Bool
    ) -> MapLayerScene {
        var polygonsByKey: [String: MKPolygon] = [:]
        polygonsByKey.reserveCapacity(plan.polygonEntries.count)

        for polygonEntry in plan.polygonEntries {
            polygonsByKey[polygonEntry.key] = polygonEntry.polygon
        }

        var overlays: [MapOverlayEntry] = []
        overlays.reserveCapacity(plan.overlayPlans.count)

        for overlayPlan in plan.overlayPlans {
            if case .warning = overlayPlan.kind, showsWarningGeometry == false {
                continue
            }

            guard let polygon = polygonsByKey[overlayPlan.polygonKey] else { continue }

            let overlay: MKOverlay
            switch overlayPlan.kind {
            case .probability:
                overlay = RiskPolygonOverlay.probability(from: polygon, overlayKey: overlayPlan.key)
            case .intensity(let level):
                let style = RiskPolygonStyleResolver.probabilityStyle(for: polygon)
                overlay = RiskPolygonOverlay.intensity(
                    from: polygon,
                    level: level,
                    strokeColor: style.stroke,
                    fillColor: style.fill,
                    overlayKey: overlayPlan.key
                )
            case .warning:
                overlay = polygon
            }

            overlays.append(
                MapOverlayEntry(
                    key: overlayPlan.key,
                    overlay: overlay,
                    signature: overlayPlan.signature
                )
            )
        }

        return MapLayerScene(
            canvasState: MapCanvasState(
                overlays: overlays,
                overlayRevision: overlayRevision(for: overlays),
                initialCenterCoordinate: initialCenterCoordinate
            ),
            legendState: plan.legendState,
            warningLegendItems: WarningLegendItem.rendered(from: overlays)
        )
    }

    private static func overlayRevision(for overlays: [MapOverlayEntry]) -> Int {
        var hasher = StableMapHasher()
        hasher.combine(overlays.count)

        for overlay in overlays {
            hasher.combine(overlay.key)
            hasher.combine(overlay.signature)
        }

        return hasher.intValue
    }
}

enum MapRenderPlanBuilder {
    static func build(
        layer: MapLayer,
        payload: MapDataPayload,
        existingPlan: MapLayerRenderPlan?,
        polygonMapper: MapPolygonMapper,
        warningPolygons: KeyedMapPolygons
    ) -> MapLayerRenderPlan {
        switch layer {
        case .categorical:
            guard case .success(let stormRisk) = payload.stormRisk else {
                return buildFailurePlan(
                    layer: layer,
                    existingPlan: existingPlan,
                    warningPolygons: warningPolygons
                )
            }
            let severeRisks = payload.severeRisks.value ?? []
            let mesos = payload.mesos.value ?? []
            let fireRisk = payload.fireRisk.value ?? []
            let mappedPolygons = polygonMapper.polygons(
                for: layer,
                stormRisk: stormRisk,
                severeRisks: severeRisks,
                mesos: mesos,
                fires: fireRisk
            )
            return buildLoadedPlan(
                layer: layer,
                mappedPolygons: mappedPolygons,
                warningPolygons: warningPolygons,
                legendState: legendState(
                    for: layer,
                    presentationState: stormRisk.isEmpty ? .confirmedEmpty : .current,
                    severeRisks: severeRisks,
                    fireRisk: fireRisk
                )
            )

        case .wind, .hail, .tornado:
            guard case .success(let severeRisks) = payload.severeRisks else {
                return buildFailurePlan(
                    layer: layer,
                    existingPlan: existingPlan,
                    warningPolygons: warningPolygons
                )
            }
            let stormRisk = payload.stormRisk.value ?? []
            let mesos = payload.mesos.value ?? []
            let fireRisk = payload.fireRisk.value ?? []
            let mappedPolygons = polygonMapper.polygons(
                for: layer,
                stormRisk: stormRisk,
                severeRisks: severeRisks,
                mesos: mesos,
                fires: fireRisk
            )
            return buildLoadedPlan(
                layer: layer,
                mappedPolygons: mappedPolygons,
                warningPolygons: warningPolygons,
                legendState: legendState(
                    for: layer,
                    presentationState: severeRisks.isEmpty ? .confirmedEmpty : .current,
                    severeRisks: severeRisks,
                    fireRisk: fireRisk
                )
            )

        case .fire:
            guard case .success(let fireRisk) = payload.fireRisk else {
                return buildFailurePlan(
                    layer: layer,
                    existingPlan: existingPlan,
                    warningPolygons: warningPolygons
                )
            }
            let stormRisk = payload.stormRisk.value ?? []
            let severeRisks = payload.severeRisks.value ?? []
            let mesos = payload.mesos.value ?? []
            let mappedPolygons = polygonMapper.polygons(
                for: layer,
                stormRisk: stormRisk,
                severeRisks: severeRisks,
                mesos: mesos,
                fires: fireRisk
            )
            return buildLoadedPlan(
                layer: layer,
                mappedPolygons: mappedPolygons,
                warningPolygons: warningPolygons,
                legendState: legendState(
                    for: layer,
                    presentationState: fireRisk.isEmpty ? .confirmedEmpty : .current,
                    severeRisks: severeRisks,
                    fireRisk: fireRisk
                )
            )

        case .meso:
            guard case .success(let mesos) = payload.mesos else {
                return buildFailurePlan(
                    layer: layer,
                    existingPlan: existingPlan,
                    warningPolygons: warningPolygons
                )
            }
            let stormRisk = payload.stormRisk.value ?? []
            let severeRisks = payload.severeRisks.value ?? []
            let fireRisk = payload.fireRisk.value ?? []
            let mappedPolygons = polygonMapper.polygons(
                for: layer,
                stormRisk: stormRisk,
                severeRisks: severeRisks,
                mesos: mesos,
                fires: fireRisk
            )
            return buildLoadedPlan(
                layer: layer,
                mappedPolygons: mappedPolygons,
                warningPolygons: warningPolygons,
                legendState: legendState(
                    for: layer,
                    presentationState: mesos.isEmpty ? .confirmedEmpty : .current,
                    severeRisks: severeRisks,
                    fireRisk: fireRisk
                )
            )
        }
    }

    private static func buildLoadedPlan(
        layer: MapLayer,
        mappedPolygons: KeyedMapPolygons,
        warningPolygons: KeyedMapPolygons,
        legendState: MapLegendState
    ) -> MapLayerRenderPlan {
        var probabilityOverlays: [MapOverlayBuildPlan] = []
        var intensityOverlaysByLevel: [(level: Int, plan: MapOverlayBuildPlan)] = []
        probabilityOverlays.reserveCapacity(mappedPolygons.keyedPolygons.count)

        for polygonEntry in mappedPolygons.keyedPolygons {
            let metadata = StormRiskPolygonStyleMetadata.decode(from: polygonEntry.subtitle)
            if let cigLevel = metadata?.cigLevel {
                intensityOverlaysByLevel.append(
                    (
                        level: cigLevel,
                        plan: overlayPlan(
                            for: polygonEntry,
                            kind: .intensity(level: cigLevel)
                        )
                    )
                )
            } else {
                probabilityOverlays.append(
                    overlayPlan(
                        for: polygonEntry,
                        kind: .probability
                    )
                )
            }
        }

        let orderedIntensityOverlays = intensityOverlaysByLevel
            .sorted { $0.level < $1.level }
            .map(\.plan)

        let warningOverlays = warningPolygons.keyedPolygons.map {
            overlayPlan(
                for: $0,
                kind: .warning
            )
        }
        let overlayPlans = probabilityOverlays + orderedIntensityOverlays + warningOverlays

        return MapLayerRenderPlan(
            layer: layer,
            polygonEntries: mappedPolygons.keyedPolygons + warningPolygons.keyedPolygons,
            overlayPlans: overlayPlans,
            overlayRevision: overlayRevision(for: overlayPlans),
            legendState: legendState
        )
    }

    private static func buildFailurePlan(
        layer: MapLayer,
        existingPlan: MapLayerRenderPlan?,
        warningPolygons: KeyedMapPolygons
    ) -> MapLayerRenderPlan {
        guard let existingPlan else {
            return warningPolygons.keyedPolygons.isEmpty
                ? MapLayerRenderPlan(
                    layer: layer,
                    polygonEntries: [],
                    overlayPlans: [],
                    overlayRevision: 0,
                    legendState: .unavailable(for: layer)
                )
                : buildWarningOnlyFailurePlan(
                    layer: layer,
                    warningPolygons: warningPolygons
                )
        }

        if warningPolygons.keyedPolygons.isEmpty == false {
            return buildWarningPreservingFailurePlan(
                layer: layer,
                existingPlan: existingPlan,
                warningPolygons: warningPolygons
            )
        }

        switch existingPlan.legendState.presentationState {
        case .current, .resolving, .stale:
            return existingPlan.withLegendState(
                existingPlan.legendState.withPresentationState(.stale)
            )
        case .loading, .confirmedEmpty, .unavailable:
            return MapLayerRenderPlan(
                layer: layer,
                polygonEntries: [],
                overlayPlans: [],
                overlayRevision: 0,
                legendState: .unavailable(for: layer)
            )
        }
    }

    private static func buildWarningOnlyFailurePlan(
        layer: MapLayer,
        warningPolygons: KeyedMapPolygons
    ) -> MapLayerRenderPlan {
        let warningOverlayPlans = warningPolygons.keyedPolygons.map {
            overlayPlan(for: $0, kind: .warning)
        }

        return MapLayerRenderPlan(
            layer: layer,
            polygonEntries: warningPolygons.keyedPolygons,
            overlayPlans: warningOverlayPlans,
            overlayRevision: overlayRevision(for: warningOverlayPlans),
            legendState: .unavailable(for: layer)
        )
    }

    private static func buildWarningPreservingFailurePlan(
        layer: MapLayer,
        existingPlan: MapLayerRenderPlan,
        warningPolygons: KeyedMapPolygons
    ) -> MapLayerRenderPlan {
        let existingWarningPolygonKeys = Set(
            existingPlan.overlayPlans.compactMap {
                if case .warning = $0.kind {
                    $0.polygonKey
                } else {
                    nil
                }
            }
        )

        let preservedPolygons = existingPlan.polygonEntries.filter {
            existingWarningPolygonKeys.contains($0.key) == false
        }
        let warningOverlayPlans = warningPolygons.keyedPolygons.map {
            overlayPlan(for: $0, kind: .warning)
        }
        let preservedOverlayPlans = existingPlan.overlayPlans.filter {
            if case .warning = $0.kind {
                return false
            }
            return true
        }

        let legendState: MapLegendState
        switch existingPlan.legendState.presentationState {
        case .current, .resolving, .stale:
            legendState = existingPlan.legendState.withPresentationState(.stale)
        case .loading, .confirmedEmpty, .unavailable:
            legendState = .unavailable(for: layer)
        }

        let overlayPlans = preservedOverlayPlans + warningOverlayPlans
        return MapLayerRenderPlan(
            layer: layer,
            polygonEntries: preservedPolygons + warningPolygons.keyedPolygons,
            overlayPlans: overlayPlans,
            overlayRevision: overlayRevision(for: overlayPlans),
            legendState: legendState
        )
    }

    private static func overlayPlan(
        for polygonEntry: MapPolygonEntry,
        kind: MapOverlayBuildPlan.Kind
    ) -> MapOverlayBuildPlan {
        let key: String
        switch kind {
        case .probability:
            key = "\(polygonEntry.key)|probability"
        case .intensity(let level):
            key = "\(polygonEntry.key)|intensity|\(level)"
        case .warning:
            key = "\(polygonEntry.key)|warning"
        }

        return MapOverlayBuildPlan(
            key: key,
            polygonKey: polygonEntry.key,
            kind: kind,
            signature: overlaySignature(
                key: key,
                subtitle: polygonEntry.subtitle,
                kind: kind
            )
        )
    }

    private static func overlaySignature(
        key: String,
        subtitle: String?,
        kind: MapOverlayBuildPlan.Kind
    ) -> Int {
        var hasher = StableMapHasher()
        hasher.combine(key)
        hasher.combine(subtitle)

        switch kind {
        case .probability:
            hasher.combine("probability")
        case .intensity(let level):
            hasher.combine("intensity")
            hasher.combine(level)
        case .warning:
            hasher.combine("warning")
        }

        return hasher.intValue
    }

    private static func overlayRevision(for plans: [MapOverlayBuildPlan]) -> Int {
        var hasher = StableMapHasher()
        hasher.combine(plans.count)
        for plan in plans {
            hasher.combine(plan.key)
            hasher.combine(plan.signature)
        }
        return hasher.intValue
    }

    private static func legendState(
        for layer: MapLayer,
        presentationState: MapLegendPresentationState,
        severeRisks: [SevereRiskShapeDTO],
        fireRisk: [FireRiskDTO]
    ) -> MapLegendState {
        switch layer {
        case .fire:
            let items = fireLegendItems(from: fireRisk)
            if presentationState == .confirmedEmpty {
                return .confirmedEmpty(for: layer)
            }

            return MapLegendState(
                presentationState: presentationState,
                layer: layer,
                severeItems: [],
                fireItems: items,
                showsHatchingExplanation: false
            )

        case .tornado, .hail, .wind:
            let severeItems = severeLegendItems(for: layer, severeRisks: severeRisks)
            let hasHatching = severeRisks
                .filter { $0.type == layer.threatType }
                .contains { $0.intensityLevel != nil }

            if presentationState == .confirmedEmpty {
                return .confirmedEmpty(for: layer)
            }

            return MapLegendState(
                presentationState: presentationState,
                layer: layer,
                severeItems: severeItems,
                fireItems: [],
                showsHatchingExplanation: hasHatching
            )

        default:
            if presentationState == .confirmedEmpty {
                return .confirmedEmpty(for: layer)
            }

            return MapLegendState(
                presentationState: presentationState,
                layer: layer,
                severeItems: [],
                fireItems: [],
                showsHatchingExplanation: false
            )
        }
    }

    private static func fireLegendItems(from fireRisk: [FireRiskDTO]) -> [FireLegendItem] {
        let mostRecentByLevel = Dictionary(
            fireRisk.map {
                (
                    $0.riskLevel,
                    FireLegendItem(
                        riskLevel: $0.riskLevel,
                        riskLevelDescription: $0.riskLevelDescription,
                        fillHex: $0.fill,
                        strokeHex: $0.stroke
                    )
                )
            },
            uniquingKeysWith: { lhs, _ in lhs }
        )

        return mostRecentByLevel.values.sorted { $0.riskLevel > $1.riskLevel }
    }

    private static func severeLegendItems(
        for layer: MapLayer,
        severeRisks: [SevereRiskShapeDTO]
    ) -> [SevereLegendItem] {
        let filtered = severeRisks.filter { risk in
            guard risk.type == layer.threatType else { return false }
            guard risk.intensityLevel == nil else { return false }

            if case .percent(let value) = risk.probabilities, value <= 0 {
                return false
            }

            return true
        }

        let dedupedByTitle = Dictionary(
            filtered.map {
                (
                    $0.title,
                    SevereLegendItem(
                        id: $0.title,
                        probability: $0.probabilities,
                        fillHex: $0.fill,
                        strokeHex: $0.stroke
                    )
                )
            },
            uniquingKeysWith: { lhs, _ in lhs }
        )

        return dedupedByTitle.values.sorted {
            let lhsProbability = $0.probability.intValue
            let rhsProbability = $1.probability.intValue
            if lhsProbability != rhsProbability {
                return lhsProbability < rhsProbability
            }

            let lhsSignificanceRank = isSignificant($0.probability) ? 1 : 0
            let rhsSignificanceRank = isSignificant($1.probability) ? 1 : 0
            if lhsSignificanceRank != rhsSignificanceRank {
                return lhsSignificanceRank < rhsSignificanceRank
            }

            return $0.id < $1.id
        }
    }

    private static func isSignificant(_ probability: ThreatProbability) -> Bool {
        if case .significant = probability {
            return true
        }
        return false
    }
}

private extension MapLayer {
    var threatType: ThreatType {
        switch self {
        case .tornado:
            return .tornado
        case .hail:
            return .hail
        case .wind:
            return .wind
        default:
            return .unknown
        }
    }
}
