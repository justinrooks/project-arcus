import CoreLocation
import Foundation
import ArcusCore
import MapKit
import Testing
@testable import SkyAware

private let mapFeatureModelTestNow = Date(timeIntervalSince1970: 1_735_689_600) // Jan 1, 2025 00:00:00 UTC

func makeStormRisk(level: StormRiskLevel, title: String) -> StormRiskDTO {
    StormRiskDTO(
        riskLevel: level,
        issued: mapFeatureModelTestNow,
        expires: mapFeatureModelTestNow.addingTimeInterval(3_600),
        valid: mapFeatureModelTestNow,
        stroke: nil,
        fill: nil,
        polygons: [makeGeoPolygon(title: title)]
    )
}

func makeSevereRisk(
    type: ThreatType,
    probability: ThreatProbability,
    title: String
) -> SevereRiskShapeDTO {
    SevereRiskShapeDTO(
        type: type,
        probabilities: probability,
        stroke: nil,
        fill: nil,
        polygons: [makeGeoPolygon(title: title)]
    )
}

func makeGeoPolygon(
    title: String,
    coordinates: [Coordinate2D] = [
        Coordinate2D(latitude: 35.0, longitude: -97.0),
        Coordinate2D(latitude: 35.1, longitude: -96.9),
        Coordinate2D(latitude: 35.2, longitude: -97.1)
    ]
) -> GeoPolygonEntity {
    GeoPolygonEntity(title: title, coordinates: coordinates)
}

func makeWarning(
    event: String,
    id: String = "warn-1",
    messageId: String? = "msg-1",
    geometry: DeviceAlertGeometry = .polygon(
        rings: [[
            DeviceAlertCoordinate(longitude: -97.0, latitude: 35.0),
            DeviceAlertCoordinate(longitude: -96.9, latitude: 35.1),
            DeviceAlertCoordinate(longitude: -97.1, latitude: 35.2)
        ]]
    )
) -> ActiveWarningGeometry {
    ActiveWarningGeometry(
        id: id,
        messageId: messageId,
        currentRevisionSent: mapFeatureModelTestNow,
        event: event,
        issued: mapFeatureModelTestNow,
        effective: mapFeatureModelTestNow,
        expires: mapFeatureModelTestNow.addingTimeInterval(3_600),
        ends: mapFeatureModelTestNow.addingTimeInterval(3_600),
        messageType: "Alert",
        geometry: geometry
    )
}

func coordinatesEqual(
    _ lhs: CLLocationCoordinate2D,
    _ rhs: CLLocationCoordinate2D,
    tolerance: CLLocationDegrees = 0.000_001
) -> Bool {
    abs(lhs.latitude - rhs.latitude) <= tolerance &&
    abs(lhs.longitude - rhs.longitude) <= tolerance
}

func overlayTitles(in scene: MapLayerScene) -> [String] {
    scene.canvasState.overlays.compactMap { entry in
        (entry.overlay as? RiskPolygonOverlay)?.polygon.title
    }
}

func overlayKeys(in scene: MapLayerScene) -> [String] {
    scene.canvasState.overlays.map(\.key)
}

func warningLegendItems(in scene: MapLayerScene) -> [WarningLegendItem] {
    scene.warningLegendItems
}

struct StubSpcMapData: SpcMapData {
    let severeRisks: Result<[SevereRiskShapeDTO], Error>
    let stormRisk: Result<[StormRiskDTO], Error>
    let mesos: Result<[MdDTO], Error>
    let fireRisk: Result<[FireRiskDTO], Error>

    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        try severeRisks.get()
    }

    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        try stormRisk.get()
    }

    func getMesoMapData() async throws -> [MdDTO] {
        try mesos.get()
    }

    func getFireRisk() async throws -> [FireRiskDTO] {
        try fireRisk.get()
    }
}

struct StubArcusAlertQuerying: ArcusAlertQuerying {
    let activeWarnings: Result<[ActiveWarningGeometry], Error>

    func getActiveAlerts(context: LocationContext) async throws -> [AlertDTO] {
        []
    }

    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry] {
        try activeWarnings.get()
    }

    func getAlert(id: String) async throws -> AlertDTO? {
        nil
    }
}

actor MapDataCallCounter {
    private(set) var severe = 0
    private(set) var storm = 0
    private(set) var meso = 0
    private(set) var fire = 0

    func recordSevere() { severe += 1 }
    func recordStorm() { storm += 1 }
    func recordMeso() { meso += 1 }
    func recordFire() { fire += 1 }

    func snapshot() -> (severe: Int, storm: Int, meso: Int, fire: Int) {
        (severe, storm, meso, fire)
    }
}

actor MutableResultMapDataStore {
    private var severeRisks: Result<[SevereRiskShapeDTO], Error>
    private var stormRisk: Result<[StormRiskDTO], Error>
    private var mesos: Result<[MdDTO], Error>
    private var fireRisk: Result<[FireRiskDTO], Error>

    init(
        severeRisks: Result<[SevereRiskShapeDTO], Error>,
        stormRisk: Result<[StormRiskDTO], Error>,
        mesos: Result<[MdDTO], Error>,
        fireRisk: Result<[FireRiskDTO], Error>
    ) {
        self.severeRisks = severeRisks
        self.stormRisk = stormRisk
        self.mesos = mesos
        self.fireRisk = fireRisk
    }

    func currentSevereRisks() -> Result<[SevereRiskShapeDTO], Error> { severeRisks }
    func currentStormRisk() -> Result<[StormRiskDTO], Error> { stormRisk }
    func currentMesos() -> Result<[MdDTO], Error> { mesos }
    func currentFireRisk() -> Result<[FireRiskDTO], Error> { fireRisk }

    func replace(
        severeRisks: Result<[SevereRiskShapeDTO], Error>? = nil,
        stormRisk: Result<[StormRiskDTO], Error>? = nil,
        mesos: Result<[MdDTO], Error>? = nil,
        fireRisk: Result<[FireRiskDTO], Error>? = nil
    ) {
        if let severeRisks { self.severeRisks = severeRisks }
        if let stormRisk { self.stormRisk = stormRisk }
        if let mesos { self.mesos = mesos }
        if let fireRisk { self.fireRisk = fireRisk }
    }
}

struct MutableResultSpcMapData: SpcMapData {
    let store: MutableResultMapDataStore

    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        try await store.currentSevereRisks().get()
    }

    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        try await store.currentStormRisk().get()
    }

    func getMesoMapData() async throws -> [MdDTO] {
        try await store.currentMesos().get()
    }

    func getFireRisk() async throws -> [FireRiskDTO] {
        try await store.currentFireRisk().get()
    }
}

actor ReloadGate {
    private var didStartFirstStormFetch = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func markFirstStormFetchStarted() {
        didStartFirstStormFetch = true
        startContinuation?.resume()
        startContinuation = nil
    }

    func waitUntilFirstStormFetchStarts() async {
        guard didStartFirstStormFetch == false else { return }

        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func waitForRelease() async {
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func releaseFirstStormFetch() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

struct QueuedReloadSpcMapData: SpcMapData {
    let gate: ReloadGate
    let counter: MapDataCallCounter
    let firstStormRisk: [StormRiskDTO]
    let secondStormRisk: [StormRiskDTO]

    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        await counter.recordSevere()
        return []
    }

    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        await counter.recordStorm()
        let stormCalls = await counter.snapshot().storm

        if stormCalls == 1 {
            await gate.markFirstStormFetchStarted()
            await gate.waitForRelease()
            return firstStormRisk
        }

        return secondStormRisk
    }

    func getMesoMapData() async throws -> [MdDTO] {
        await counter.recordMeso()
        return []
    }

    func getFireRisk() async throws -> [FireRiskDTO] {
        await counter.recordFire()
        return []
    }
}

struct StubError: Error {}

