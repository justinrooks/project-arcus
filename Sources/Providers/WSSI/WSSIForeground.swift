import Foundation
import SwiftData

struct WSSIAcceptedAssessment: Sendable {
    struct Location: Equatable, Sendable {
        let point: Coordinate2D
        let h3Cell: Int64

        init(point: Coordinate2D, h3Cell: Int64) {
            self.point = point
            self.h3Cell = h3Cell
        }

        init?(_ observation: LocationSnapshot) {
            guard let h3Cell = observation.h3Cell else { return nil }
            self.init(point: .init(observation.coordinates), h3Cell: h3Cell)
        }
    }

    struct Period: Sendable {
        let assessment: WSSIPointAssessment
        let coverage: WSSICoverage
    }

    let location: Location
    let periods: [Period]
}

protocol WSSIAssessmentReading: Sendable {
    func assessment(at time: Date) async throws -> WSSIAcceptedAssessment?
}

struct WSSIAcceptedGeometry: Sendable {
    let geometry: WSSIFeatureCollection
    let revision: WSSIAcceptedRevision
    let validity: WSSIValidity
}

protocol WSSIGeometryReading: Sendable {
    func geometry(product: WSSIProduct, day: Int, revision: UUID, at time: Date) async throws -> WSSIAcceptedGeometry?
}

actor WSSIForeground: WSSIAssessmentReading, WSSIGeometryReading {
    private let container: ModelContainer
    private let save: @Sendable (ModelContext) throws -> Void
    private let client: ForgeWSSIClient
    private let currentLocation: @MainActor @Sendable () async -> WSSIAcceptedAssessment.Location?

    // Lazy initialization on this actor keeps SwiftData's serial executor off the main queue.
    private lazy var sync = WSSISync(
        client: client,
        store: WSSIAcceptedStore(modelContainer: container, save: save)
    )
    private var enabled = false
    private var admission = UUID()
    private var task: Task<Void, Never>?
    private var offeredWhileCancelling = false

    init(
        client: ForgeWSSIClient,
        container: ModelContainer,
        save: @escaping @Sendable (ModelContext) throws -> Void = { try $0.save() },
        currentLocation: @escaping @MainActor @Sendable () async -> WSSIAcceptedAssessment.Location?
    ) {
        self.client = client
        self.container = container
        self.save = save
        self.currentLocation = currentLocation
    }

    func setEnabled(_ value: Bool) {
        guard enabled != value else { return }
        enabled = value
        admission = UUID()
        if !value {
            offeredWhileCancelling = false
            task?.cancel()
        }
    }

    func offerRefresh() {
        guard enabled else { return }
        if let task {
            offeredWhileCancelling = task.isCancelled
            return
        }
        task = Task {
            _ = await HTTPExecutionMode.$current.withValue(.foreground) {
                await sync.refresh(enabled: !Task.isCancelled)
            }
            task = nil
            if offeredWhileCancelling {
                offeredWhileCancelling = false
                offerRefresh()
            }
        }
    }

    #if DEBUG
    func waitForRefresh() async { await task?.value }
    #endif

    func assessment(at time: Date) async throws -> WSSIAcceptedAssessment? {
        guard enabled else { return nil }
        let admitted = admission
        guard let location = await currentLocation(), admitted == admission else { return nil }
        // Use a fresh context against the committed store. A suspended writer may hold uncommitted models.
        let reader = WSSIAcceptedStore(modelContainer: container)
        let periods = try await reader.assess(location.point, at: time)
        let latest = await currentLocation()
        guard admitted == admission, latest == location else { return nil }
        try Task.checkCancellation()
        return .init(location: location, periods: periods)
    }

    func geometry(
        product: WSSIProduct, day: Int, revision: UUID, at time: Date
    ) async throws -> WSSIAcceptedGeometry? {
        guard enabled else { return nil }
        let admitted = admission
        let reader = WSSIAcceptedStore(modelContainer: container)
        let result = try await reader.geometry(product: product, day: day, revision: revision, at: time)
        guard admitted == admission else { return nil }
        try Task.checkCancellation()
        return result
    }
}

private extension WSSIAcceptedStore {
    func assess(_ point: Coordinate2D, at time: Date) throws -> [WSSIAcceptedAssessment.Period] {
        assert(!Thread.isMainThread)
        let advertised = try manifest()?.document.datasets ?? []
        return try WSSIProduct.allCases.flatMap { product in
            try (1...3).map { day in
                try Task.checkCancellation()
                let accepted = try slot(product: product, day: day)
                let status = advertised.first { $0.product == product && $0.day == day }
                let entry = WSSIManifestEntry(
                    product: product, day: day, validity: accepted?.validity(at: time) ?? .neverAccepted,
                    sourceStatus: status?.sourceStatus ?? .unknown, pollHealth: status?.pollHealth ?? .unknown,
                    coverage: accepted?.coverage ?? .unknown, accepted: accepted?.revision
                )
                let assessment = try WSSIPointAssessment.evaluate(entry: entry, point: point, at: time) {
                    accepted?.geometry
                }
                return .init(assessment: assessment, coverage: entry.coverage)
            }
        }
    }

    func geometry(
        product: WSSIProduct, day: Int, revision: UUID, at time: Date
    ) throws -> WSSIAcceptedGeometry? {
        assert(!Thread.isMainThread)
        try Task.checkCancellation()
        guard let slot = try slot(product: product, day: day), slot.revision.revision == revision,
              slot.validity(at: time) != .expired else { return nil }
        let entry = WSSIManifestEntry(
            product: product, day: day, validity: slot.validity(at: time),
            sourceStatus: .unknown, pollHealth: .unknown, coverage: slot.coverage, accepted: slot.revision
        )
        return .init(geometry: try WSSISourceDecoder.geometry(from: slot.geometry, for: entry),
                     revision: slot.revision, validity: entry.validity)
    }
}
