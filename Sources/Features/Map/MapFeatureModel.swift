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
import ArcusCore

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
    private var showsWarningGeometry = true
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

        showRefreshStateForCurrentSelection()

        while Task.isCancelled == false {
            pendingReload = false
            await performReload(using: service, warningSource: warningSource)

            guard pendingReload else { return }
            showRefreshStateForCurrentSelection()
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

        let activeWarnings: [ActiveWarningGeometry]
        switch warningResult {
        case .success(let value):
            activeWarnings = value
        case .failure:
            activeWarnings = []
        case .cancelled:
            return
        }

        let payload = MapDataPayload(
            stormRisk: stormResult,
            severeRisks: severeResult,
            mesos: mesoResult,
            fireRisk: fireResult,
            activeWarnings: activeWarnings
        )

        let warningPolygons = polygonMapper.warningPolygons(from: payload.activeWarnings)

        let plannedScenes = await planner.buildRenderPlans(
            payload: payload,
            existingPlans: renderPlans,
            polygonMapper: polygonMapper,
            warningPolygons: warningPolygons
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

    func setWarningGeometryVisible(_ isVisible: Bool) {
        guard showsWarningGeometry != isVisible else { return }

        showsWarningGeometry = isVisible
        cachedScenes.removeAll(keepingCapacity: true)
        warmScenesTask?.cancel()
        warmScenesTask = nil
        applySelectedLayer(currentSelectedLayer)
        scheduleWarmRemainingScenes()
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

    private func showRefreshStateForCurrentSelection() {
        if let scene = cachedScenes[currentSelectedLayer] ?? renderPlans[currentSelectedLayer].map({ MapSceneMaterializer.materialize(
            plan: $0,
            initialCenterCoordinate: initialCenterCoordinate,
            showsWarningGeometry: showsWarningGeometry
        ) }) {
            switch scene.legendState.presentationState {
            case .current, .confirmedEmpty, .stale:
                activeScene = scene.withPresentationState(.resolving)
            case .loading, .resolving, .unavailable:
                activeScene = scene
            }
        } else {
            activeScene = MapLayerScene.placeholder(
                for: currentSelectedLayer,
                initialCenterCoordinate: initialCenterCoordinate
            )
        }
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
            initialCenterCoordinate: initialCenterCoordinate,
            showsWarningGeometry: showsWarningGeometry
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
                    initialCenterCoordinate: self.initialCenterCoordinate,
                    showsWarningGeometry: self.showsWarningGeometry
                )

                await Task.yield()
            }
        }
    }

    private func fetchSevereRiskShapes(using service: any SpcMapData) async -> MapFetchOutcome<[SevereRiskShapeDTO]> {
        do {
            return .success(try await service.getSevereRiskShapes())
        } catch is CancellationError {
            return .cancelled
        } catch {
            logger.error("Failed to load severe risk map data: \(error.localizedDescription, privacy: .public)")
            return .failure
        }
    }

    private func fetchStormRiskShapes(using service: any SpcMapData) async -> MapFetchOutcome<[StormRiskDTO]> {
        do {
            return .success(try await service.getStormRiskMapData())
        } catch is CancellationError {
            return .cancelled
        } catch {
            logger.error("Failed to load categorical map data: \(error.localizedDescription, privacy: .public)")
            return .failure
        }
    }

    private func fetchMesoShapes(using service: any SpcMapData) async -> MapFetchOutcome<[MdDTO]> {
        do {
            return .success(try await service.getMesoMapData())
        } catch is CancellationError {
            return .cancelled
        } catch {
            logger.error("Failed to load mesoscale map data: \(error.localizedDescription, privacy: .public)")
            return .failure
        }
    }

    private func fetchFireRiskShapes(using service: any SpcMapData) async -> MapFetchOutcome<[FireRiskDTO]> {
        do {
            return .success(try await service.getFireRisk())
        } catch is CancellationError {
            return .cancelled
        } catch {
            logger.error("Failed to load fire map data: \(error.localizedDescription, privacy: .public)")
            return .failure
        }
    }

    private func fetchActiveWarningGeometry(
        using warningSource: any ArcusAlertQuerying
    ) async -> MapFetchOutcome<[ActiveWarningGeometry]> {
        do {
            return .success(try await warningSource.getActiveWarningGeometries())
        } catch is CancellationError {
            return .cancelled
        } catch {
            logger.error("Failed to load active warning geometry: \(error.localizedDescription, privacy: .public)")
            return .failure
        }
    }

    private static func temporaryWarningSamples(
        around center: CLLocationCoordinate2D
    ) -> [ActiveWarningGeometry] {
        [
            warningSample(
                id: "debug-severe-thunderstorm",
                event: "Severe Thunderstorm Warning",
                center: CLLocationCoordinate2D(latitude: center.latitude + 0.55, longitude: center.longitude - 0.85)
            ),
            warningSample(
                id: "debug-tornado",
                event: "Tornado Warning",
                center: center
            ),
            warningSample(
                id: "debug-flash-flood",
                event: "Flash Flood Warning",
                center: CLLocationCoordinate2D(latitude: center.latitude - 0.55, longitude: center.longitude + 0.85)
            )
        ]
    }

    private static func warningSample(
        id: String,
        event: String,
        center: CLLocationCoordinate2D
    ) -> ActiveWarningGeometry {
        ActiveWarningGeometry(
            id: id,
            messageId: id,
            currentRevisionSent: Date(timeIntervalSince1970: 1_735_689_600),
            event: event,
            issued: Date(timeIntervalSince1970: 1_735_689_600),
            effective: Date(timeIntervalSince1970: 1_735_689_600),
            expires: Date(timeIntervalSince1970: 1_735_693_200),
            ends: Date(timeIntervalSince1970: 1_735_693_200),
            messageType: "Alert",
            geometry: .polygon(
                rings: [[
                    DeviceAlertCoordinate(longitude: center.longitude - 0.35, latitude: center.latitude - 0.20),
                    DeviceAlertCoordinate(longitude: center.longitude + 0.35, latitude: center.latitude - 0.20),
                    DeviceAlertCoordinate(longitude: center.longitude + 0.35, latitude: center.latitude + 0.20),
                    DeviceAlertCoordinate(longitude: center.longitude - 0.35, latitude: center.latitude + 0.20)
                ]]
            )
        )
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
            legendState: .loading(for: layer)
        )
    }

    func withInitialCenterCoordinateIfNeeded(_ coordinate: CLLocationCoordinate2D) -> MapLayerScene {
        guard canvasState.initialCenterCoordinate == nil else { return self }
        return MapLayerScene(
            canvasState: canvasState.withInitialCenterCoordinate(coordinate),
            legendState: legendState
        )
    }

    func withPresentationState(_ presentationState: MapLegendPresentationState) -> MapLayerScene {
        MapLayerScene(
            canvasState: canvasState,
            legendState: legendState.withPresentationState(presentationState)
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
    let presentationState: MapLegendPresentationState
    let layer: MapLayer
    let severeItems: [SevereLegendItem]
    let fireItems: [FireLegendItem]
    let showsHatchingExplanation: Bool

    var allowsInteraction: Bool {
        showsHatchingExplanation &&
        !severeItems.isEmpty &&
        presentationState != .loading &&
        presentationState != .confirmedEmpty &&
        presentationState != .unavailable
    }

    static func loading(for layer: MapLayer) -> MapLegendState {
        MapLegendState(
            presentationState: .loading,
            layer: layer,
            severeItems: [],
            fireItems: [],
            showsHatchingExplanation: false
        )
    }

    static func resolving(
        for layer: MapLayer,
        severeItems: [SevereLegendItem],
        fireItems: [FireLegendItem],
        showsHatchingExplanation: Bool
    ) -> MapLegendState {
        MapLegendState(
            presentationState: .resolving,
            layer: layer,
            severeItems: severeItems,
            fireItems: fireItems,
            showsHatchingExplanation: showsHatchingExplanation
        )
    }

    static func current(
        for layer: MapLayer,
        severeItems: [SevereLegendItem],
        fireItems: [FireLegendItem],
        showsHatchingExplanation: Bool
    ) -> MapLegendState {
        MapLegendState(
            presentationState: .current,
            layer: layer,
            severeItems: severeItems,
            fireItems: fireItems,
            showsHatchingExplanation: showsHatchingExplanation
        )
    }

    static func confirmedEmpty(for layer: MapLayer) -> MapLegendState {
        MapLegendState(
            presentationState: .confirmedEmpty,
            layer: layer,
            severeItems: [],
            fireItems: [],
            showsHatchingExplanation: false
        )
    }

    static func stale(
        for layer: MapLayer,
        severeItems: [SevereLegendItem],
        fireItems: [FireLegendItem],
        showsHatchingExplanation: Bool
    ) -> MapLegendState {
        MapLegendState(
            presentationState: .stale,
            layer: layer,
            severeItems: severeItems,
            fireItems: fireItems,
            showsHatchingExplanation: showsHatchingExplanation
        )
    }

    static func unavailable(for layer: MapLayer) -> MapLegendState {
        MapLegendState(
            presentationState: .unavailable,
            layer: layer,
            severeItems: [],
            fireItems: [],
            showsHatchingExplanation: false
        )
    }

    func withPresentationState(_ presentationState: MapLegendPresentationState) -> MapLegendState {
        MapLegendState(
            presentationState: presentationState,
            layer: layer,
            severeItems: severeItems,
            fireItems: fireItems,
            showsHatchingExplanation: showsHatchingExplanation
        )
    }

    var headlineText: String {
        switch presentationState {
        case .loading:
            "Getting \(layer.legendSubject)…"
        case .resolving:
            "\(layer.legendDisplayTitle) · Updating"
        case .current:
            layer.legendDisplayTitle
        case .confirmedEmpty:
            "No \(layer.legendSubject)"
        case .stale:
            "\(layer.legendDisplayTitle) saved locally"
        case .unavailable:
            "\(layer.legendDisplayTitle) unavailable"
        }
    }

    var voiceOverText: String {
        switch presentationState {
        case .loading:
            "Getting \(layer.legendSubject). Loading."
        case .resolving:
            "Updating \(layer.legendSubject). Showing saved data while the refresh completes."
        case .current:
            "\(layer.legendDisplayTitle) loaded."
        case .confirmedEmpty:
            "No \(layer.legendSubject). Successfully loaded and confirmed empty."
        case .stale:
            "\(layer.legendDisplayTitle) saved locally. Refresh failed."
        case .unavailable:
            "\(layer.legendDisplayTitle) unavailable. No saved data."
        }
    }
}

enum MapLegendPresentationState: Sendable, Equatable {
    case loading
    case resolving
    case current
    case confirmedEmpty
    case stale
    case unavailable
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
    let stormRisk: MapFetchOutcome<[StormRiskDTO]>
    let severeRisks: MapFetchOutcome<[SevereRiskShapeDTO]>
    let mesos: MapFetchOutcome<[MdDTO]>
    let fireRisk: MapFetchOutcome<[FireRiskDTO]>
    let activeWarnings: [ActiveWarningGeometry]
}

private enum MapFetchOutcome<Value: Sendable>: Sendable {
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

private actor MapScenePlanner {
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

@MainActor
private enum MapSceneMaterializer {
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
            legendState: plan.legendState
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

private enum MapRenderPlanBuilder {
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
    var legendDisplayTitle: String {
        switch self {
        case .categorical:
            return "Severe Risk"
        case .wind:
            return "Wind Risk"
        case .hail:
            return "Hail Risk"
        case .tornado:
            return "Tornado Risk"
        case .meso:
            return "Mesoscale"
        case .fire:
            return "Fire Risk"
        }
    }

    var legendSubject: String {
        switch self {
        case .categorical:
            return "severe risk"
        case .wind:
            return "wind risk"
        case .hail:
            return "hail risk"
        case .tornado:
            return "tornado risk"
        case .meso:
            return "mesoscale"
        case .fire:
            return "fire risk"
        }
    }

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
