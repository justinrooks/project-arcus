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
    var mesoCallCounter: MesoMapDataCallCounter?

    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        try severeRisks.get()
    }

    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        try stormRisk.get()
    }

    func getMesoMapData() async throws -> [MdDTO] {
        await mesoCallCounter?.record()
        return try mesos.get()
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

struct StubArcusMesoQuerying: ArcusMesoQuerying {
    let mesos: Result<[MesoscaleDiscussionPayload], Error>
    var expectsNationwideRequest = false

    func getActiveMesos(h3Cell: Int64?) async throws -> ArcusMesoQueryResponse<[MesoscaleDiscussionPayload]> {
        if expectsNationwideRequest { #expect(h3Cell == nil) }
        try Task.checkCancellation()
        return ArcusMesoQueryResponse(value: try mesos.get(), source: .live)
    }

    func getMeso(productID: String) async throws -> ArcusMesoQueryResponse<MesoscaleDiscussionPayload>? {
        nil
    }
}

struct GatedArcusMesoQuerying: ArcusMesoQuerying {
    let gate: ReloadGate
    let mesos: [MesoscaleDiscussionPayload]

    func getActiveMesos(h3Cell: Int64?) async throws -> ArcusMesoQueryResponse<[MesoscaleDiscussionPayload]> {
        await gate.markFirstStormFetchStarted()
        await gate.waitForRelease()
        try Task.checkCancellation()
        return ArcusMesoQueryResponse(value: mesos, source: .live)
    }

    func getMeso(productID: String) async throws -> ArcusMesoQueryResponse<MesoscaleDiscussionPayload>? {
        nil
    }
}

func makeMesoPayload(number: Int, coordinates: [Coordinate2D]) -> MesoscaleDiscussionPayload {
    let issued = mapFeatureModelTestNow
    return MesoscaleDiscussionPayload(
        number: number,
        title: "Mesoscale Discussion \(number)",
        sourceURL: URL(string: "https://www.spc.noaa.gov/products/md/\(number).html")!,
        issued: issued,
        validStart: issued,
        validEnd: issued.addingTimeInterval(3_600),
        areasAffected: "Central Plains",
        summary: "Severe storms possible.",
        concerning: "Severe potential",
        watchProbability: 40,
        watchProbabilityText: "40%",
        threats: nil,
        coordinates: coordinates.map {
            MesoscaleDiscussionCoordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
    )
}

extension MapFeatureModel {
    func reload(
        using service: any SpcMapData,
        warningSource: any ArcusAlertQuerying,
        selectedLayer: MapLayer
    ) async {
        await reload(
            using: service,
            mesoSource: SpcMesoQueryingForExistingTests(service: service),
            warningSource: warningSource,
            selectedLayer: selectedLayer
        )
    }
}

private struct SpcMesoQueryingForExistingTests: ArcusMesoQuerying {
    let service: any SpcMapData

    func getActiveMesos(h3Cell: Int64?) async throws -> ArcusMesoQueryResponse<[MesoscaleDiscussionPayload]> {
        let payloads = try await service.getMesoMapData().map { meso in
            MesoscaleDiscussionPayload(
                number: meso.number,
                title: meso.title,
                sourceURL: meso.link,
                issued: meso.issued,
                validStart: meso.validStart,
                validEnd: meso.validEnd,
                areasAffected: meso.areasAffected,
                summary: meso.summary,
                concerning: meso.concerning,
                watchProbability: meso.watchProbability,
                watchProbabilityText: meso.watchProbabilityText,
                threats: meso.threats.map {
                    MesoscaleDiscussionThreats(
                        peakWindMPH: $0.peakWindMPH,
                        hailRangeInches: $0.hailRangeInches,
                        tornadoStrength: $0.tornadoStrength
                    )
                },
                coordinates: meso.coordinates.map {
                    MesoscaleDiscussionCoordinate(latitude: $0.latitude, longitude: $0.longitude)
                }
            )
        }
        return ArcusMesoQueryResponse(value: payloads, source: .live)
    }

    func getMeso(productID: String) async throws -> ArcusMesoQueryResponse<MesoscaleDiscussionPayload>? {
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

actor MesoMapDataCallCounter {
    private(set) var count = 0

    func record() { count += 1 }
    func snapshot() -> Int { count }
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

actor IndexedReloadGate {
    private var started: Set<Int> = []
    private var startWaiters: [Int: CheckedContinuation<Void, Never>] = [:]
    private var releaseWaiters: [Int: CheckedContinuation<Void, Never>] = [:]
    private var released: Set<Int> = []

    func run(_ index: Int) async {
        started.insert(index)
        startWaiters.removeValue(forKey: index)?.resume()
        if released.remove(index) != nil { return }
        await withCheckedContinuation { releaseWaiters[index] = $0 }
    }

    func waitUntilStarted(_ index: Int) async {
        guard started.contains(index) == false else { return }
        await withCheckedContinuation { startWaiters[index] = $0 }
    }

    func release(_ index: Int) {
        if let continuation = releaseWaiters.removeValue(forKey: index) {
            continuation.resume()
        } else {
            released.insert(index)
        }
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
