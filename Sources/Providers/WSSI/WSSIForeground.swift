import Foundation
import SwiftData
import Synchronization

final class WinterImpactsAdmission: Sendable {
    private let state: Mutex<(enabled: Bool, revision: UInt64)>
    init(enabled: Bool) { state = Mutex((enabled, 0)) }
    func update(_ enabled: Bool) { state.withLock { $0 = (enabled, $0.revision &+ 1) } }
    func snapshot() -> (enabled: Bool, revision: UInt64) { state.withLock { $0 } }
}

/// Shared choice state for Settings and future onboarding and discovery surfaces.
struct WinterImpactsPreference {
    static let enabledKey = "winterImpactsEnabled"
    static let discoveryDismissedKey = "winterImpactsDiscoveryDismissed"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) { self.defaults = defaults }

    var choice: Bool? { defaults.object(forKey: Self.enabledKey) as? Bool }
    var isEnabled: Bool { choice ?? false }
    var discoveryDismissed: Bool { defaults.bool(forKey: Self.discoveryDismissedKey) }

    fileprivate func setChoice(_ enabled: Bool) { defaults.set(enabled, forKey: Self.enabledKey) }
    func dismissDiscovery() { defaults.set(true, forKey: Self.discoveryDismissedKey) }
}

@MainActor
struct WinterImpactsRuntime {
    let service: WSSIForeground?
    let preference: WinterImpactsPreferenceController

    init(
        defaults: UserDefaults,
        origin: URL?,
        container: ModelContainer,
        makeClient: (URL) -> ForgeWSSIClient = { ForgeWSSIClient(origin: $0) },
        currentLocation: @escaping @MainActor @Sendable () async -> WSSIAcceptedAssessment.Location?
    ) {
        let enabled = WinterImpactsPreference(defaults: defaults).isEnabled
        let admission = WinterImpactsAdmission(enabled: enabled)
        let service = origin.map {
            WSSIForeground(client: makeClient($0), container: container, enabled: enabled, preferenceAdmission: admission, currentLocation: currentLocation)
        }
        self.service = service
        preference = WinterImpactsPreferenceController(defaults: defaults, service: service, admission: admission)
    }
}

/// Serializes explicit user choices so a rapid disable cannot be lost.
@MainActor
final class WinterImpactsPreferenceController {
    let preference: WinterImpactsPreference
    private let service: WSSIForeground?
    private var pending: Task<Void, Never>?
    private var generation: UInt64 = 0
    private let admission: WinterImpactsAdmission?

    init(defaults: UserDefaults, service: WSSIForeground?, admission: WinterImpactsAdmission? = nil) {
        preference = WinterImpactsPreference(defaults: defaults)
        self.service = service
        self.admission = admission
    }

    func setChoice(_ enabled: Bool) {
        let changed = preference.isEnabled != enabled
        preference.setChoice(enabled)
        guard changed else { return }
        admission?.update(enabled)
        let revision = admission?.snapshot().revision
        generation &+= 1
        let command = generation
        let previous = pending
        let service = service
        pending = Task {
            await previous?.value
            if enabled && command != generation { return }
            await service?.setEnabled(enabled, preferenceRevision: revision)
            if enabled && command == generation { await service?.offerRefresh() }
        }
    }

    func waitForPendingChanges() async { await pending?.value }
}

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
    private let preferenceAdmission: WinterImpactsAdmission?
    private let currentLocation: @MainActor @Sendable () async -> WSSIAcceptedAssessment.Location?
    private let waitForBackgroundDeadline: @Sendable (ContinuousClock.Instant) async throws -> Void

    // Lazy initialization on this actor keeps SwiftData's serial executor off the main queue.
    private lazy var sync = WSSISync(
        client: client,
        store: WSSIAcceptedStore(modelContainer: container, save: save)
    )
    private var enabled: Bool
    private var appliedPreferenceRevision: UInt64 = 0
    private var admission = UUID()
    private var refreshStatus: WSSIAcceptedAssessment.RefreshStatus = .notAttempted
    private var refreshOutcomeGeneration: UInt64 = 0
    private var task: Task<Void, Never>?
    private var isBackgroundRefresh = false
    private var offeredWhileCancelling = false

    init(
        client: ForgeWSSIClient,
        container: ModelContainer,
        enabled: Bool = false,
        preferenceAdmission: WinterImpactsAdmission? = nil,
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
        self.preferenceAdmission = preferenceAdmission
        self.currentLocation = currentLocation
        self.waitForBackgroundDeadline = waitForBackgroundDeadline
    }

    func setEnabled(_ value: Bool, preferenceRevision: UInt64? = nil) {
        if let preferenceRevision { appliedPreferenceRevision = preferenceRevision }
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
        guard enabled, preferenceIsCurrent else { return }
        if let task {
            if isBackgroundRefresh { task.cancel() }
            offeredWhileCancelling = task.isCancelled
            return
        }
        startRefresh(background: nil)
    }

    func refreshInBackground(using budget: BackgroundRefreshBudget) async {
        guard enabled, preferenceIsCurrent, task == nil, !Task.isCancelled, ContinuousClock.now < budget.workDeadline else { return }
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
        let preferenceRevision = preferenceAdmission?.snapshot().revision
        let refresh = Task {
            let outcome = await BackgroundRefreshExecutionContext.$current.withValue(context) {
                await HTTPExecutionMode.$current.withValue(context == nil ? .foreground : .background) {
                    await sync.refresh(enabled: !Task.isCancelled && preferenceIsCurrent && preferenceRevision == preferenceAdmission?.snapshot().revision)
                }
            }
            let withinBudget = context.map { ContinuousClock.now < $0.budget.workDeadline } ?? true
            if admitted == admission, preferenceRevision == preferenceAdmission?.snapshot().revision, !Task.isCancelled, withinBudget {
                switch outcome {
                case .reconciled(_, let slots): publishRefreshStatus(.reconciled(slots))
                case .manifestFailed(let failure, _): publishRefreshStatus(.manifestFailed(failure))
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

    private func publishRefreshStatus(_ status: WSSIAcceptedAssessment.RefreshStatus) {
        refreshStatus = status
        refreshOutcomeGeneration &+= 1
    }

    private var preferenceIsCurrent: Bool {
        guard let state = preferenceAdmission?.snapshot() else { return true }
        return state.enabled && state.revision == appliedPreferenceRevision
    }

    #if DEBUG
    func waitForRefresh() async {
        while let task { await task.value }
    }
    #endif

    func assessment(at time: Date) async throws -> WSSIAcceptedAssessment? {
        let preferenceSnapshot = preferenceAdmission?.snapshot()
        guard enabled, preferenceSnapshot.map({ $0.enabled && $0.revision == appliedPreferenceRevision }) ?? true else { return nil }
        let admitted = admission
        let preferenceRevision = preferenceSnapshot?.revision
        guard let location = await currentLocation(), admitted == admission,
              preferenceRevision == preferenceAdmission?.snapshot().revision else { return nil }
        let status = refreshStatus
        let outcomeGeneration = refreshOutcomeGeneration
        // Use a fresh context against the committed store. A suspended writer may hold uncommitted models.
        let reader = WSSIAcceptedStore(modelContainer: container)
        let periods = try await reader.assess(location.point, at: time)
        let latest = await currentLocation()
        guard admitted == admission, preferenceRevision == preferenceAdmission?.snapshot().revision, latest == location, outcomeGeneration == refreshOutcomeGeneration else { return nil }
        try Task.checkCancellation()
        return .init(location: location, periods: periods, refreshStatus: status)
    }

    func geometry(
        product: WSSIProduct, day: Int, revision: UUID, at time: Date
    ) async throws -> WSSIAcceptedGeometry? {
        let preferenceSnapshot = preferenceAdmission?.snapshot()
        guard enabled, preferenceSnapshot.map({ $0.enabled && $0.revision == appliedPreferenceRevision }) ?? true else { return nil }
        let admitted = admission
        let preferenceRevision = preferenceSnapshot?.revision
        let reader = WSSIAcceptedStore(modelContainer: container)
        let result = try await reader.geometry(product: product, day: day, revision: revision, at: time)
        guard admitted == admission, preferenceRevision == preferenceAdmission?.snapshot().revision else { return nil }
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
