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
    private static let invalidatingFeedIDs: Set<String> = [
        "spc.map.convective",
        "spc.map.fire",
        "spc.meso",
        "arcus.alert",
        "arcus.alerts"
    ]

    private let logger = Logger.uiMap
    private let polygonMapper = MapPolygonMapper()
    private let planner = MapScenePlanner()
    private var renderPlans: [MapLayer: MapLayerRenderPlan] = [:]
    private var sceneCache = MapSceneCache()
    private var currentSelectedLayer: MapLayer = .categorical
    private var showsWarningGeometry = true
    private var isLoading = false
    private var pendingReload = false

    static func shouldReload(forAcceptedFeedID feedID: String) -> Bool {
        invalidatingFeedIDs.contains(feedID)
    }

    static func observeAcceptedFeedUpdates(
        from updates: AsyncStream<FeedStateGenerationUpdate>,
        onRelevantUpdate: @MainActor (FeedStateGenerationUpdate) async -> Void
    ) async {
        for await update in updates {
            guard shouldReload(forAcceptedFeedID: update.feedID) else { continue }
            await onRelevantUpdate(update)
        }
    }

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
        let selectedLayer = currentSelectedLayer
        let selectedPayload = await fetchSelectedLayerPayload(
            selectedLayer,
            using: service,
            warningSource: warningSource
        )

        guard Task.isCancelled == false, containsCancellation(in: selectedPayload) == false else {
            return false
        }

        let selectedWarningPolygons = polygonMapper.warningPolygons(
            from: selectedPayload.activeWarnings.value ?? []
        )
        let selectedPlan = await planner.buildRenderPlan(
            for: selectedLayer,
            payload: selectedPayload,
            existingPlan: renderPlans[selectedLayer],
            polygonMapper: polygonMapper,
            warningPolygons: selectedWarningPolygons
        )

        guard Task.isCancelled == false else { return false }

        let payload = await fetchRemainingPayload(
            selectedLayer,
            selectedPayload: selectedPayload,
            using: service
        )

        guard Task.isCancelled == false, containsCancellation(in: payload) == false else {
            return false
        }

        let warningPolygons = polygonMapper.warningPolygons(from: payload.activeWarnings.value ?? [])
        var candidatePlans = renderPlans
        candidatePlans[selectedLayer] = selectedPlan
        let remainingPlans = await planner.buildRemainingRenderPlans(
            excluding: selectedLayer,
            payload: payload,
            existingPlans: candidatePlans,
            polygonMapper: polygonMapper,
            warningPolygons: warningPolygons
        )

        guard Task.isCancelled == false else { return false }

        candidatePlans.merge(remainingPlans) { _, newPlan in newPlan }
        renderPlans = candidatePlans
        sceneCache.removeAll()
        applySelectedLayer(currentSelectedLayer)
        return true
    }

    private func fetchSelectedLayerPayload(
        _ layer: MapLayer,
        using service: any SpcMapData,
        warningSource: any ArcusAlertQuerying
    ) async -> MapDataPayload {
        async let warnings = fetchActiveWarningGeometry(using: warningSource)

        switch layer {
        case .categorical:
            let stormRisk = await fetchStormRiskShapes(using: service)
            return MapDataPayload(
                stormRisk: stormRisk,
                severeRisks: .failure,
                mesos: .failure,
                fireRisk: .failure,
                activeWarnings: await warnings
            )
        case .wind, .hail, .tornado:
            let severeRisks = await fetchSevereRiskShapes(using: service)
            return MapDataPayload(
                stormRisk: .failure,
                severeRisks: severeRisks,
                mesos: .failure,
                fireRisk: .failure,
                activeWarnings: await warnings
            )
        case .meso:
            let mesos = await fetchMesoShapes(using: service)
            return MapDataPayload(
                stormRisk: .failure,
                severeRisks: .failure,
                mesos: mesos,
                fireRisk: .failure,
                activeWarnings: await warnings
            )
        case .fire:
            let fireRisk = await fetchFireRiskShapes(using: service)
            return MapDataPayload(
                stormRisk: .failure,
                severeRisks: .failure,
                mesos: .failure,
                fireRisk: fireRisk,
                activeWarnings: await warnings
            )
        }
    }

    private func fetchRemainingPayload(
        _ selectedLayer: MapLayer,
        selectedPayload: MapDataPayload,
        using service: any SpcMapData
    ) async -> MapDataPayload {
        async let severeRisks = usesSevereRiskShapes(selectedLayer)
            ? selectedPayload.severeRisks
            : fetchSevereRiskShapes(using: service)
        async let stormRisk = selectedLayer == .categorical
            ? selectedPayload.stormRisk
            : fetchStormRiskShapes(using: service)
        async let mesos = selectedLayer == .meso
            ? selectedPayload.mesos
            : fetchMesoShapes(using: service)
        async let fireRisk = selectedLayer == .fire
            ? selectedPayload.fireRisk
            : fetchFireRiskShapes(using: service)

        return await MapDataPayload(
            stormRisk: stormRisk,
            severeRisks: severeRisks,
            mesos: mesos,
            fireRisk: fireRisk,
            activeWarnings: selectedPayload.activeWarnings
        )
    }

    private func usesSevereRiskShapes(_ layer: MapLayer) -> Bool {
        switch layer {
        case .wind, .hail, .tornado:
            true
        case .categorical, .meso, .fire:
            false
        }
    }

    private func containsCancellation(in payload: MapDataPayload) -> Bool {
        payload.stormRisk.isCancellation ||
            payload.severeRisks.isCancellation ||
            payload.mesos.isCancellation ||
            payload.fireRisk.isCancellation ||
            payload.activeWarnings.isCancellation
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

@MainActor
final class MapReloadCoordinator {
    typealias Operation = @MainActor @Sendable () async -> Void

    private var reloadTask: Task<Void, Never>?
    private var activeTaskID: UUID?
    private var pendingOperation: Operation?

    var hasScheduledReload: Bool { reloadTask != nil }

    func schedule(_ operation: @escaping Operation) {
        guard reloadTask == nil else {
            pendingOperation = operation
            return
        }

        let taskID = UUID()
        activeTaskID = taskID
        reloadTask = Task {
            var nextOperation = operation
            repeat {
                pendingOperation = nil
                await nextOperation()
                guard Task.isCancelled == false,
                      activeTaskID == taskID,
                      let pendingOperation else {
                    break
                }
                nextOperation = pendingOperation
            } while true

            guard activeTaskID == taskID else { return }
            reloadTask = nil
            activeTaskID = nil
        }
    }

    func cancel() {
        activeTaskID = nil
        pendingOperation = nil
        reloadTask?.cancel()
        reloadTask = nil
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

    mutating func removeAll(except layer: MapLayer) {
        scenes = scenes.filter { $0.key == layer }
        layers = layers.filter { $0 == layer }
    }

    mutating func updateScenes(_ transform: (MapLayerScene) -> MapLayerScene) {
        scenes = scenes.mapValues(transform)
    }

    private mutating func touch(_ layer: MapLayer) {
        layers.removeAll { $0 == layer }
        layers.append(layer)
    }
}
