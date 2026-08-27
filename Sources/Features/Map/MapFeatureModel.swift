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
    private var sceneCache = MapSceneCache()
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
            let didReplaceRenderPlans = await performReload(using: service, warningSource: warningSource)

            if pendingReload == false {
                if didReplaceRenderPlans == false {
                    applySelectedLayer(currentSelectedLayer)
                }
                return
            }
            showRefreshStateForCurrentSelection()
        }
    }

    private func performReload(
        using service: any SpcMapData,
        warningSource: any ArcusAlertQuerying
    ) async -> Bool {
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

        guard !Task.isCancelled else { return false }

        if severeResult.isCancellation ||
            stormResult.isCancellation ||
            mesoResult.isCancellation ||
            fireResult.isCancellation ||
            warningResult.isCancellation {
            return false
        }

        let payload = MapDataPayload(
            stormRisk: stormResult,
            severeRisks: severeResult,
            mesos: mesoResult,
            fireRisk: fireResult,
            activeWarnings: warningResult
        )

        let warningPolygons = polygonMapper.warningPolygons(from: payload.activeWarnings.value ?? [])

        let plannedScenes = await planner.buildRenderPlans(
            payload: payload,
            existingPlans: renderPlans,
            polygonMapper: polygonMapper,
            warningPolygons: warningPolygons
        )

        guard !Task.isCancelled else { return false }

        renderPlans = plannedScenes
        sceneCache.removeAll()

        applySelectedLayer(currentSelectedLayer)
        return true
    }

    func selectLayer(_ layer: MapLayer) {
        currentSelectedLayer = layer
        applySelectedLayer(layer)
    }

    func setWarningGeometryVisible(_ isVisible: Bool) {
        guard showsWarningGeometry != isVisible else { return }

        showsWarningGeometry = isVisible
        sceneCache.removeAll()
        applySelectedLayer(currentSelectedLayer)
    }

    func captureInitialCenterCoordinateIfNeeded(_ coordinate: CLLocationCoordinate2D?) {
        guard initialCenterCoordinate == nil, let coordinate else { return }

        initialCenterCoordinate = coordinate
        activeScene = activeScene.withInitialCenterCoordinateIfNeeded(coordinate)

        sceneCache.updateScenes { scene in
            scene.withInitialCenterCoordinateIfNeeded(coordinate)
        }
    }

    private func showRefreshStateForCurrentSelection() {
        if let scene = sceneCache.scene(for: currentSelectedLayer) ?? renderPlans[currentSelectedLayer].map({ MapSceneMaterializer.materialize(
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

        if let cachedScene = sceneCache.scene(for: layer) {
            activeScene = cachedScene
            return
        }

        let scene = MapSceneMaterializer.materialize(
            plan: plan,
            initialCenterCoordinate: initialCenterCoordinate,
            showsWarningGeometry: showsWarningGeometry
        )
        sceneCache.insert(scene, for: layer)
        activeScene = scene
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

struct MapSceneCache {
    static let capacity = 2

    private var scenes: [MapLayer: MapLayerScene] = [:]
    private(set) var layers: [MapLayer] = []

    var retainedSceneCount: Int { scenes.count }
    var retainedOverlayCount: Int {
        scenes.values.reduce(0) { $0 + $1.canvasState.overlays.count }
    }

    mutating func scene(for layer: MapLayer) -> MapLayerScene? {
        guard let scene = scenes[layer] else { return nil }

        touch(layer)
        return scene
    }

    mutating func insert(_ scene: MapLayerScene, for layer: MapLayer) {
        scenes[layer] = scene
        touch(layer)

        while layers.count > Self.capacity {
            scenes.removeValue(forKey: layers.removeFirst())
        }
    }

    mutating func removeAll() {
        scenes.removeAll(keepingCapacity: true)
        layers.removeAll(keepingCapacity: true)
    }

    mutating func updateScenes(_ transform: (MapLayerScene) -> MapLayerScene) {
        scenes = scenes.mapValues(transform)
    }

    private mutating func touch(_ layer: MapLayer) {
        layers.removeAll { $0 == layer }
        layers.append(layer)
    }
}
