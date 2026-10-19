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

struct MapForecastSelection: Hashable {
    let day: SPCForecastDay
    let layer: MapLayer

    static func supports(day: SPCForecastDay, layer: MapLayer) -> Bool {
        switch layer {
        case .categorical: SPCForecastProduct.categorical.supports(day)
        case .wind: SPCForecastProduct.wind.supports(day)
        case .hail: SPCForecastProduct.hail.supports(day)
        case .tornado: SPCForecastProduct.tornado.supports(day)
        case .meso: SPCForecastProduct.meso.supports(day)
        case .fire: SPCForecastProduct.fire.supports(day)
        }
    }
}

private extension MapLayerScene {
    func withForecastDay(_ day: SPCForecastDay) -> Self {
        Self(canvasState: canvasState,
             legendState: legendState.withForecast(day: day, period: legendState.forecastPeriod),
             warningLegendItems: warningLegendItems)
    }
}

@MainActor
@Observable
final class MapFeatureModel {
    private static let invalidatingFeedIDs: Set<String> = [
        "spc.map.convective",
        "spc.map.fire",
        "spc.map.categorical.day2",
        "spc.map.categorical.day3",
        "spc.map.hazards.day2",
        "arcus.alert",
        "arcus.alerts"
    ]

    private let logger = Logger.uiMap
    private let polygonMapper = MapPolygonMapper()
    private let planner = MapScenePlanner()
    private let nowProvider: () -> Date
    private var renderPlans: [MapLayer: MapLayerRenderPlan] = [:]
    private var sceneCache = MapSceneCache()
    private var forecastPlans: [MapForecastSelection: MapLayerRenderPlan] = [:]
    private(set) var selectedForecastDay: SPCForecastDay = .day1
    private var currentSelectedLayer: MapLayer = .categorical
    private var showsWarningGeometry = true
    private var isLoading = false
    private var pendingReload = false
    private var acceptedInputRevision = 0

    init(nowProvider: @escaping () -> Date = Date.init) {
        self.nowProvider = nowProvider
    }

    /// Called at scheduling time, before the coordinator can defer the next reload.
    func invalidateAcceptedInputs() {
        acceptedInputRevision += 1
    }

    static func shouldReload(forAcceptedFeedID feedID: String) -> Bool {
        invalidatingFeedIDs.contains(feedID) || feedID.hasPrefix("home.hot.")
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
        mesoSource: any ArcusMesoQuerying,
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
            let inputRevision = acceptedInputRevision
            let didReplaceRenderPlans = await performReload(
                using: service,
                mesoSource: mesoSource,
                warningSource: warningSource
            )

            if pendingReload == false {
                if didReplaceRenderPlans == false, inputRevision == acceptedInputRevision {
                    applySelectedLayer(currentSelectedLayer)
                }
                return
            }
            showRefreshStateForCurrentSelection()
        }
    }

    func reloadMesoscale(using source: any ArcusMesoQuerying) async {
        let mesos = await fetchMesoShapes(using: source)
        guard Task.isCancelled == false, mesos.isCancellation == false else { return }

        let payload = MapDataPayload(
            stormRisk: .failure,
            severeRisks: .failure,
            mesos: mesos,
            fireRisk: .failure,
            activeWarnings: .failure
        )
        let plan = await planner.buildRenderPlan(
            for: .meso,
            payload: payload,
            existingPlan: renderPlans[.meso],
            polygonMapper: polygonMapper,
            warningPolygons: KeyedMapPolygons(entries: [])
        )
        guard Task.isCancelled == false else { return }

        renderPlans[.meso] = plan
        sceneCache.remove(.meso)
        applySelectedLayer(currentSelectedLayer)
    }

    private func performReload(
        using service: any SpcMapData,
        mesoSource: any ArcusMesoQuerying,
        warningSource: any ArcusAlertQuerying
    ) async -> Bool {
        let inputRevision = acceptedInputRevision
        let selectedLayer = currentSelectedLayer
        let selectedPayload = await fetchSelectedLayerPayload(
            selectedLayer,
            using: service,
            mesoSource: mesoSource,
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
            using: service,
            mesoSource: mesoSource
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
        guard let candidateForecastPlans = await buildForecastPlans(using: service),
              Task.isCancelled == false, pendingReload == false,
              inputRevision == acceptedInputRevision else { return false }

        renderPlans = candidatePlans
        forecastPlans = candidateForecastPlans
        sceneCache.removeAll()
        applySelectedLayer(currentSelectedLayer)
        return true
    }

    /// Fixed supported set: five future plans, replaced together with current plans.
    /// Serial reload ownership and cache invalidation make accepted replacement the scene generation.
    private func buildForecastPlans(using service: any SpcMapData) async -> [MapForecastSelection: MapLayerRenderPlan]? {
        var plans = forecastPlans
        for day in [SPCForecastDay.day2, .day3] {
            let categorical = await acceptedForecast { try await service.getCategoricalForecast(for: day) }
            let hazards = day == .day2
                ? await acceptedForecast { try await service.getHazardForecast(for: day) }
                : MapFetchOutcome<SPCHazardForecastSnapshot?>.success(nil)
            guard !categorical.isCancellation, !hazards.isCancellation else { return nil }
            for layer in MapLayer.allCases where MapForecastSelection.supports(day: day, layer: layer) {
                let key = MapForecastSelection(day: day, layer: layer)
                let category = categorical.value.flatMap { $0 }
                let hazard = hazards.value.flatMap { $0 }
                let period: MapForecastPeriod?
                if layer == .categorical {
                    period = category.map { MapForecastPeriod(issued: $0.issued, valid: $0.valid, expires: $0.expires) }
                } else {
                    period = hazard.map { MapForecastPeriod(issued: $0.issued, valid: $0.valid, expires: $0.expires) }
                }
                // Failed or absent reads retain this exact day/product, including accepted-empty identity.
                guard let period else {
                    if let previous = plans[key], previous.legendState.forecastPeriod != nil {
                        plans[key] = previous.withLegendState(previous.legendState.withPresentationState(.stale))
                    } else {
                        let empty = MapDataPayload(stormRisk: .failure, severeRisks: .failure,
                            mesos: .failure, fireRisk: .failure, activeWarnings: .success([]))
                        let plan = await planner.buildRenderPlan(for: layer, payload: empty, existingPlan: nil,
                            polygonMapper: polygonMapper, warningPolygons: KeyedMapPolygons(entries: []))
                        plans[key] = plan.withLegendState(plan.legendState.withForecast(day: day))
                    }
                    continue
                }
                let payload = MapDataPayload(
                    stormRisk: category.map { .success($0.risks) } ?? .failure,
                    severeRisks: hazard.map { snapshot in
                        .success(snapshot.shapes.filter { shape in
                            switch layer {
                            case .wind: shape.type == .wind
                            case .hail: shape.type == .hail
                            case .tornado: shape.type == .tornado
                            default: false
                            }
                        })
                    } ?? .failure,
                    mesos: .failure, fireRisk: .failure, activeWarnings: .success([])
                )
                let plan = await planner.buildRenderPlan(for: layer, payload: payload, existingPlan: nil,
                    polygonMapper: polygonMapper, warningPolygons: KeyedMapPolygons(entries: []))
                let legend = period.expires <= nowProvider()
                    ? plan.legendState.withPresentationState(.stale) : plan.legendState
                plans[key] = plan.withLegendState(legend.withForecast(day: day, period: period))
            }
        }
        return plans
    }

    private func acceptedForecast<Value: Sendable>(
        _ read: @Sendable () async throws -> Value
    ) async -> MapFetchOutcome<Value> {
        do { return .success(try await read()) }
        catch is CancellationError { return .cancelled }
        catch {
            logger.error("Failed to read accepted forecast: \(error.localizedDescription, privacy: .public)")
            return .failure
        }
    }

    private func fetchSelectedLayerPayload(
        _ layer: MapLayer,
        using service: any SpcMapData,
        mesoSource: any ArcusMesoQuerying,
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
            let mesos = await fetchMesoShapes(using: mesoSource)
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
        using service: any SpcMapData,
        mesoSource: any ArcusMesoQuerying
    ) async -> MapDataPayload {
        async let severeRisks = usesSevereRiskShapes(selectedLayer)
            ? selectedPayload.severeRisks
            : fetchSevereRiskShapes(using: service)
        async let stormRisk = selectedLayer == .categorical
            ? selectedPayload.stormRisk
            : fetchStormRiskShapes(using: service)
        async let mesos = selectedLayer == .meso
            ? selectedPayload.mesos
            : fetchMesoShapes(using: mesoSource)
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

    @discardableResult
    func selectForecast(day: SPCForecastDay, layer: MapLayer) -> Bool {
        guard MapForecastSelection.supports(day: day, layer: layer) else { return false }
        selectedForecastDay = day
        currentSelectedLayer = layer
        applySelectedLayer(layer)
        return true
    }

    func selectLayer(_ layer: MapLayer) {
        if layer == .meso || layer == .fire {
            selectedForecastDay = .current
        } else if !MapForecastSelection.supports(day: selectedForecastDay, layer: layer) {
            selectedForecastDay = .day1
        }
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
        if let scene = sceneCache.scene(for: currentSelectedLayer, day: selectedForecastDay) ?? selectedPlan.map({ MapSceneMaterializer.materialize(
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
            ).withForecastDay(selectedForecastDay)
        }
    }

    private var selectedPlan: MapLayerRenderPlan? {
        if selectedForecastDay == .day2 || selectedForecastDay == .day3 {
            return forecastPlans[MapForecastSelection(day: selectedForecastDay, layer: currentSelectedLayer)]
        }
        return renderPlans[currentSelectedLayer]
    }

    private func applySelectedLayer(_ layer: MapLayer) {
        guard let plan = selectedPlan else {
            activeScene = MapLayerScene.placeholder(
                for: layer,
                initialCenterCoordinate: initialCenterCoordinate
            ).withForecastDay(selectedForecastDay)
            return
        }

        if let cachedScene = sceneCache.scene(for: layer, day: selectedForecastDay) {
            activeScene = markingExpiredForecast(cachedScene)
            return
        }

        let scene = MapSceneMaterializer.materialize(
            plan: plan,
            initialCenterCoordinate: initialCenterCoordinate,
            showsWarningGeometry: showsWarningGeometry
        )
        let scopedScene = scene.withForecastDay(selectedForecastDay)
        sceneCache.insert(scopedScene, for: layer, day: selectedForecastDay)
        activeScene = markingExpiredForecast(scopedScene)
    }

    private func markingExpiredForecast(_ scene: MapLayerScene) -> MapLayerScene {
        guard let period = scene.legendState.forecastPeriod, period.expires <= nowProvider() else { return scene }
        return scene.withPresentationState(.stale)
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

    private func fetchMesoShapes(using source: any ArcusMesoQuerying) async -> MapFetchOutcome<[MdDTO]> {
        do {
            let response = try await source.getActiveMesos(h3Cell: nil)
            guard response.source == .live || response.source == .cacheRevalidated304 else {
                return .failure
            }
            return .success(response.value.map(MdDTO.init(payload:)))
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
        enqueue(operation, preservingPendingOperation: false)
    }

    func scheduleMesoscale(_ operation: @escaping Operation) {
        enqueue(operation, preservingPendingOperation: true)
    }

    func updateLifecycle(isActive: Bool, isVisible: Bool) {
        guard isActive, isVisible else {
            cancel()
            return
        }
    }

    private func enqueue(_ operation: @escaping Operation, preservingPendingOperation: Bool) {
        guard reloadTask == nil else {
            if preservingPendingOperation == false || pendingOperation == nil {
                pendingOperation = operation
            }
            return
        }

        start(operation)
    }

    private func start(_ operation: @escaping Operation) {
        let taskID = UUID()
        activeTaskID = taskID
        reloadTask = Task { @MainActor in
            if Task.isCancelled == false {
                await operation()
            }
            finish(taskID: taskID)
        }
    }

    private func finish(taskID: UUID) {
        guard activeTaskID == taskID else { return }

        reloadTask = nil
        activeTaskID = nil

        guard let pendingOperation else { return }
        self.pendingOperation = nil
        start(pendingOperation)
    }

    func cancel() {
        pendingOperation = nil
        reloadTask?.cancel()
    }
}

struct MapSceneCache {
    static let capacity = 2

    private var scenes: [MapForecastSelection: MapLayerScene] = [:]
    private(set) var selections: [MapForecastSelection] = []
    var layers: [MapLayer] { selections.map(\.layer) }

    var retainedSceneCount: Int { scenes.count }
    var retainedOverlayCount: Int {
        scenes.values.reduce(0) { $0 + $1.canvasState.overlays.count }
    }

    mutating func scene(for layer: MapLayer, day: SPCForecastDay = .day1) -> MapLayerScene? {
        let selection = MapForecastSelection(day: day, layer: layer)
        guard let scene = scenes[selection] else { return nil }

        touch(selection)
        return scene
    }

    mutating func insert(_ scene: MapLayerScene, for layer: MapLayer, day: SPCForecastDay = .day1) {
        let selection = MapForecastSelection(day: day, layer: layer)
        scenes[selection] = scene
        touch(selection)

        while selections.count > Self.capacity {
            scenes.removeValue(forKey: selections.removeFirst())
        }
    }

    mutating func removeAll() {
        scenes.removeAll(keepingCapacity: true)
        selections.removeAll(keepingCapacity: true)
    }

    mutating func removeAll(except layer: MapLayer) {
        scenes = scenes.filter { $0.key.layer == layer }
        selections = selections.filter { $0.layer == layer }
    }

    mutating func remove(_ layer: MapLayer) {
        scenes = scenes.filter { $0.key.layer != layer }
        selections.removeAll { $0.layer == layer }
    }

    mutating func updateScenes(_ transform: (MapLayerScene) -> MapLayerScene) {
        scenes = scenes.mapValues(transform)
    }

    private mutating func touch(_ selection: MapForecastSelection) {
        selections.removeAll { $0 == selection }
        selections.append(selection)
    }
}
