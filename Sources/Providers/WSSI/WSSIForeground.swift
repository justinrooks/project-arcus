import Foundation
import SwiftData

struct WSSIAcceptedAssessment: Sendable {
    struct Location: Equatable, Sendable {
        let point: Coordinate2D
        let h3Cell: Int64
        let observedAt: Date

        init(point: Coordinate2D, h3Cell: Int64, observedAt: Date) {
            self.point = point
            self.h3Cell = h3Cell
            self.observedAt = observedAt
        }

        init?(_ observation: LocationSnapshot) {
            guard let h3Cell = observation.h3Cell else { return nil }
            self.init(point: .init(observation.coordinates), h3Cell: h3Cell, observedAt: observation.timestamp)
        }
    }

    struct Period: Sendable {
        let assessment: WSSIPointAssessment
        let coverage: WSSICoverage
    }

    enum RefreshStatus: Equatable, Sendable {
        case notAttempted
        case manifestFailed(WSSISync.Failure)
        case reconciled([WSSISync.SlotResult])
    }

    let location: Location
    let periods: [Period]
    /// The latest completed local refresh in this admission, independent of the accepted store.
    let refreshStatus: RefreshStatus
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
    private let waitForBackgroundDeadline: @Sendable (ContinuousClock.Instant) async throws -> Void

    // Lazy initialization on this actor keeps SwiftData's serial executor off the main queue.
    private lazy var sync = WSSISync(
        client: client,
        store: WSSIAcceptedStore(modelContainer: container, save: save)
    )
    private var enabled: Bool
    private var admission = UUID()
    private var refreshStatus: WSSIAcceptedAssessment.RefreshStatus = .notAttempted
    private var task: Task<Void, Never>?
    private var isBackgroundRefresh = false
    private var offeredWhileCancelling = false

    init(
        client: ForgeWSSIClient,
        container: ModelContainer,
        enabled: Bool = false,
        save: @escaping @Sendable (ModelContext) throws -> Void = { try $0.save() },
        waitForBackgroundDeadline: @escaping @Sendable (ContinuousClock.Instant) async throws -> Void = {
            try await ContinuousClock().sleep(until: $0)
        },
        currentLocation: @escaping @MainActor @Sendable () async -> WSSIAcceptedAssessment.Location?
    ) {
        self.client = client
        self.container = container
        self.save = save
        self.enabled = enabled
        self.currentLocation = currentLocation
        self.waitForBackgroundDeadline = waitForBackgroundDeadline
    }

    func setEnabled(_ value: Bool) {
        guard enabled != value else { return }
        enabled = value
        admission = UUID()
        if !value {
            refreshStatus = .notAttempted
            offeredWhileCancelling = false
            task?.cancel()
        }
    }

    func offerRefresh() {
        guard enabled else { return }
        if let task {
            if isBackgroundRefresh { task.cancel() }
            offeredWhileCancelling = task.isCancelled
            return
        }
        startRefresh(background: nil)
    }

    func refreshInBackground(using budget: BackgroundRefreshBudget) async {
        guard enabled, task == nil, !Task.isCancelled, ContinuousClock.now < budget.workDeadline else { return }
        let context = BackgroundRefreshExecutionContext(budget: budget)
        let refresh = startRefresh(background: context)
        let waitForBackgroundDeadline = waitForBackgroundDeadline
        await withTaskCancellationHandler {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await refresh.value }
                group.addTask {
                    do {
                        try await waitForBackgroundDeadline(budget.workDeadline)
                        try Task.checkCancellation()
                        refresh.cancel()
                    } catch {
                        // The refresh or the enclosing BG task finished first.
                    }
                }
                await group.next()
                group.cancelAll()
            }
        } onCancel: {
            refresh.cancel()
        }
    }

    @discardableResult
    private func startRefresh(background context: BackgroundRefreshExecutionContext?) -> Task<Void, Never> {
        isBackgroundRefresh = context != nil
        let admitted = admission
        let refresh = Task {
            let outcome = await BackgroundRefreshExecutionContext.$current.withValue(context) {
                await HTTPExecutionMode.$current.withValue(context == nil ? .foreground : .background) {
                    await sync.refresh(enabled: !Task.isCancelled)
                }
            }
            let withinBudget = context.map { ContinuousClock.now < $0.budget.workDeadline } ?? true
            if admitted == admission, !Task.isCancelled, withinBudget {
                switch outcome {
                case .reconciled(_, let slots): refreshStatus = .reconciled(slots)
                case .manifestFailed(let failure, _): refreshStatus = .manifestFailed(failure)
                case .disabled, .cancelled, .superseded: break
                }
            }
            task = nil
            isBackgroundRefresh = false
            if offeredWhileCancelling {
                offeredWhileCancelling = false
                offerRefresh()
            }
        }
        task = refresh
        return refresh
    }

    #if DEBUG
    func waitForRefresh() async { await task?.value }
    #endif

    func assessment(at time: Date) async throws -> WSSIAcceptedAssessment? {
        guard enabled else { return nil }
        let admitted = admission
        guard let location = await currentLocation(), admitted == admission else { return nil }
        let status = refreshStatus
        // Use a fresh context against the committed store. A suspended writer may hold uncommitted models.
        let reader = WSSIAcceptedStore(modelContainer: container)
        let periods = try await reader.assess(location.point, at: time)
        let latest = await currentLocation()
        guard admitted == admission, latest == location else { return nil }
        try Task.checkCancellation()
        return .init(location: location, periods: periods, refreshStatus: status)
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
