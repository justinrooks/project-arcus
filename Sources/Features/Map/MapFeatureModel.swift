//
//  MapFeatureModel.swift
//  SkyAware
//
//  Created by Codex on 4/21/26.
//

import CoreLocation
import MapKit
import Observation
import OSLog

@MainActor
@Observable
final class MapFeatureModel {
    private let logger = Logger.uiMap
    private let polygonMapper = MapPolygonMapper()
    private let planner = MapScenePlanner()

    private var renderPlans: [MapLayer: MapLayerRenderPlan] = [:]
    private var cachedScenes: [MapLayer: MapLayerScene] = [:]
    private var warmScenesTask: Task<Void, Never>?
    private var currentSelectedLayer: MapLayer = .categorical
    private var isLoading = false
    private var pendingReload = false

    private(set) var activeScene = MapLayerScene.placeholder(for: .categorical)
    private(set) var initialCenterCoordinate: CLLocationCoordinate2D?

    func reload(
        using service: any SpcMapData,
        warningSource: any ArcusAlertQuerying,
        selectedLayer: MapLayer
    ) async {
        selectLayer(selectedLayer)

        if isLoading {
            pendingReload = true
            return
        }

        isLoading = true
        defer {
            isLoading = false
            pendingReload = false
        }

        while Task.isCancelled == false {
            pendingReload = false
            await performReload(using: service, warningSource: warningSource)

            guard pendingReload else { return }
        }
    }

    private func performReload(
        using service: any SpcMapData,
        warningSource: any ArcusAlertQuerying
    ) async {
        async let severeTask = fetchSevereRiskShapes(using: service)
        async let stormTask = fetchStormRiskShapes(using: service)
        async let mesoTask = fetchMesoShapes(using: service)
        async let fireTask = fetchFireRiskShapes(using: service)
        async let warningTask = fetchActiveWarningGeometry(using: warningSource)

        let (severeResult, stormResult, mesoResult, fireResult, warningResult) = await (
            severeTask,
            stormTask,
            mesoTask,
            fireTask,
            warningTask
        )

        guard !Task.isCancelled else { return }

        if severeResult.isCancellation ||
            stormResult.isCancellation ||
            mesoResult.isCancellation ||
            fireResult.isCancellation ||
            warningResult.isCancellation {
            return
        }

        let severeRisks = severeResult.value(orLogging: "severe risk map data", logger: logger)
        let stormRisk = stormResult.value(orLogging: "categorical map data", logger: logger)
        let mesos = mesoResult.value(orLogging: "mesoscale map data", logger: logger)
        let fireRisk = fireResult.value(orLogging: "fire map data", logger: logger)
        let activeWarnings: [ActiveWarningGeometry]
        switch warningResult {
        case .success(let value):
            activeWarnings = value
        case .failure(let error):
            if error is CancellationError {
                return
            }
            logger.error("Failed to load active warning geometry: \(error.localizedDescription, privacy: .public)")
            activeWarnings = []
        }

        let payload = MapDataPayload(
            stormRisk: stormRisk,
            severeRisks: severeRisks,
            mesos: mesos,
            fireRisk: fireRisk,
            activeWarnings: activeWarnings
        )

        let plannedScenes = await planner.buildRenderPlans(
            payload: payload,
            polygonMapper: polygonMapper
        )

        guard !Task.isCancelled else { return }

        warmScenesTask?.cancel()
        warmScenesTask = nil
        renderPlans = plannedScenes
        cachedScenes.removeAll(keepingCapacity: true)

        applySelectedLayer(currentSelectedLayer)
        scheduleWarmRemainingScenes()
    }

    func selectLayer(_ layer: MapLayer) {
        currentSelectedLayer = layer
        applySelectedLayer(layer)
    }

    func captureInitialCenterCoordinateIfNeeded(_ coordinate: CLLocationCoordinate2D?) {
        guard initialCenterCoordinate == nil, let coordinate else { return }

        initialCenterCoordinate = coordinate
        activeScene = activeScene.withInitialCenterCoordinateIfNeeded(coordinate)

        for (layer, scene) in cachedScenes {
            cachedScenes[layer] = scene.withInitialCenterCoordinateIfNeeded(coordinate)
        }
    }

    func cancelWork() {
        warmScenesTask?.cancel()
        warmScenesTask = nil
    }

    private func applySelectedLayer(_ layer: MapLayer) {
        guard let plan = renderPlans[layer] else {
            activeScene = MapLayerScene.placeholder(
                for: layer,
                initialCenterCoordinate: initialCenterCoordinate
            )
            return
        }

        if let cachedScene = cachedScenes[layer] {
            activeScene = cachedScene
            return
        }

        let scene = MapSceneMaterializer.materialize(
            plan: plan,
            initialCenterCoordinate: initialCenterCoordinate
        )
        cachedScenes[layer] = scene
        activeScene = scene
    }

    private func scheduleWarmRemainingScenes() {
        warmScenesTask?.cancel()

        let layersToWarm = MapLayer.allCases.filter { $0 != currentSelectedLayer }
        guard !layersToWarm.isEmpty else { return }

        warmScenesTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for layer in layersToWarm {
                if Task.isCancelled { return }
                guard self.cachedScenes[layer] == nil, let plan = self.renderPlans[layer] else { continue }

                self.cachedScenes[layer] = MapSceneMaterializer.materialize(
                    plan: plan,
                    initialCenterCoordinate: self.initialCenterCoordinate
                )

                await Task.yield()
            }
        }
    }

    private func fetchSevereRiskShapes(using service: any SpcMapData) async -> Result<[SevereRiskShapeDTO], Error> {
        do {
            return .success(try await service.getSevereRiskShapes())
        } catch is CancellationError {
            return .failure(CancellationError())
        } catch {
            return .failure(error)
        }
    }

    private func fetchStormRiskShapes(using service: any SpcMapData) async -> Result<[StormRiskDTO], Error> {
        do {
            return .success(try await service.getStormRiskMapData())
        } catch is CancellationError {
            return .failure(CancellationError())
        } catch {
            return .failure(error)
        }
    }

    private func fetchMesoShapes(using service: any SpcMapData) async -> Result<[MdDTO], Error> {
        do {
            return .success(try await service.getMesoMapData())
        } catch is CancellationError {
            return .failure(CancellationError())
        } catch {
            return .failure(error)
        }
    }

    private func fetchFireRiskShapes(using service: any SpcMapData) async -> Result<[FireRiskDTO], Error> {
        do {
            return .success(try await service.getFireRisk())
        } catch is CancellationError {
            return .failure(CancellationError())
        } catch {
            return .failure(error)
        }
    }

    private func fetchActiveWarningGeometry(
        using warningSource: any ArcusAlertQuerying
    ) async -> Result<[ActiveWarningGeometry], Error> {
        do {
            return .success(try await warningSource.getActiveWarningGeometries())
        } catch is CancellationError {
            return .failure(CancellationError())
        } catch {
            return .failure(error)
        }
    }
}

struct MapLayerScene {
    let canvasState: MapCanvasState
    let legendState: MapLegendState

    static func placeholder(
        for layer: MapLayer,
        initialCenterCoordinate: CLLocationCoordinate2D? = nil
    ) -> MapLayerScene {
        MapLayerScene(
            canvasState: MapCanvasState(
                overlays: [],
                overlayRevision: 0,
                initialCenterCoordinate: initialCenterCoordinate
            ),
            legendState: .empty(for: layer)
        )
    }

    func withInitialCenterCoordinateIfNeeded(_ coordinate: CLLocationCoordinate2D) -> MapLayerScene {
        guard canvasState.initialCenterCoordinate == nil else { return self }
        return MapLayerScene(
            canvasState: canvasState.withInitialCenterCoordinate(coordinate),
            legendState: legendState
        )
    }
}

struct MapCanvasState {
    let overlays: [MapOverlayEntry]
    let overlayRevision: Int
    let initialCenterCoordinate: CLLocationCoordinate2D?

    func withInitialCenterCoordinate(_ coordinate: CLLocationCoordinate2D) -> MapCanvasState {
        MapCanvasState(
            overlays: overlays,
            overlayRevision: overlayRevision,
            initialCenterCoordinate: coordinate
        )
    }
}

struct MapLegendState: Sendable {
    let layer: MapLayer
    let severeItems: [SevereLegendItem]
    let fireItems: [FireLegendItem]
    let showsHatchingExplanation: Bool

    var allowsInteraction: Bool {
        showsHatchingExplanation && !severeItems.isEmpty
    }

    static func empty(for layer: MapLayer) -> MapLegendState {
        MapLegendState(
            layer: layer,
            severeItems: [],
            fireItems: [],
            showsHatchingExplanation: false
        )
    }
}

struct SevereLegendItem: Sendable, Hashable, Identifiable {
    let id: String
    let probability: ThreatProbability
    let fillHex: String?
    let strokeHex: String?
}

struct FireLegendItem: Sendable, Hashable, Identifiable {
    let riskLevel: Int
    let riskLevelDescription: String
    let fillHex: String?
    let strokeHex: String?

    var id: Int { riskLevel }
}

private struct MapDataPayload: Sendable {
    let stormRisk: [StormRiskDTO]
    let severeRisks: [SevereRiskShapeDTO]
    let mesos: [MdDTO]
    let fireRisk: [FireRiskDTO]
    let activeWarnings: [ActiveWarningGeometry]
}

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

private struct MapLayerRenderPlan: Sendable {
    let layer: MapLayer
    let polygonEntries: [MapPolygonEntry]
    let overlayPlans: [MapOverlayBuildPlan]
    let overlayRevision: Int
    let legendState: MapLegendState
}

private actor MapScenePlanner {
    func buildRenderPlans(
        payload: MapDataPayload,
        polygonMapper: MapPolygonMapper
    ) -> [MapLayer: MapLayerRenderPlan] {
        Dictionary(
            uniqueKeysWithValues: MapLayer.allCases.map { layer in
                (
                    layer,
                    MapRenderPlanBuilder.build(
                        layer: layer,
                        payload: payload,
                        polygonMapper: polygonMapper
                    )
                )
            }
        )
    }
}

@MainActor
private enum MapSceneMaterializer {
    static func materialize(
        plan: MapLayerRenderPlan,
        initialCenterCoordinate: CLLocationCoordinate2D?
    ) -> MapLayerScene {
        var polygonsByKey: [String: MKPolygon] = [:]
        polygonsByKey.reserveCapacity(plan.polygonEntries.count)

        for polygonEntry in plan.polygonEntries {
            polygonsByKey[polygonEntry.key] = polygonEntry.polygon
        }

        var overlays: [MapOverlayEntry] = []
        overlays.reserveCapacity(plan.overlayPlans.count)

        for overlayPlan in plan.overlayPlans {
            guard let polygon = polygonsByKey[overlayPlan.polygonKey] else { continue }

            let overlay: MKOverlay
            switch overlayPlan.kind {
            case .probability:
                overlay = RiskPolygonOverlay.probability(from: polygon)
            case .intensity(let level):
                let style = RiskPolygonStyleResolver.probabilityStyle(for: polygon)
                overlay = RiskPolygonOverlay.intensity(
                    from: polygon,
                    level: level,
                    strokeColor: style.stroke,
                    fillColor: style.fill
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
                overlayRevision: plan.overlayRevision,
                initialCenterCoordinate: initialCenterCoordinate
            ),
            legendState: plan.legendState
        )
    }
}

private enum MapRenderPlanBuilder {
    static func build(
        layer: MapLayer,
        payload: MapDataPayload,
        polygonMapper: MapPolygonMapper
    ) -> MapLayerRenderPlan {
        let mappedPolygons = polygonMapper.polygons(
            for: layer,
            stormRisk: payload.stormRisk,
            severeRisks: payload.severeRisks,
            mesos: payload.mesos,
            fires: payload.fireRisk
        )
        let warningPolygons = polygonMapper.warningPolygons(from: payload.activeWarnings)

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
            legendState: legendState(
                for: layer,
                severeRisks: payload.severeRisks,
                fireRisk: payload.fireRisk
            )
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
        severeRisks: [SevereRiskShapeDTO],
        fireRisk: [FireRiskDTO]
    ) -> MapLegendState {
        switch layer {
        case .fire:
            return MapLegendState(
                layer: layer,
                severeItems: [],
                fireItems: fireLegendItems(from: fireRisk),
                showsHatchingExplanation: false
            )

        case .tornado, .hail, .wind:
            let severeItems = severeLegendItems(for: layer, severeRisks: severeRisks)
            let hasHatching = severeRisks
                .filter { $0.type == layer.threatType }
                .contains { $0.intensityLevel != nil }

            return MapLegendState(
                layer: layer,
                severeItems: severeItems,
                fireItems: [],
                showsHatchingExplanation: hasHatching
            )

        default:
            return .empty(for: layer)
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
