import Foundation
import OSLog

/// Independent WSSI ownership. Foreground work stays off Home; scheduled work uses only leftover budget.
actor WSSIForegroundIngestion {
    enum Outcome: String, Sendable { case disabled, background, busy, fresh, attempted, accepted, rejected, failed, backoff, deferredFeasibility, deadline, cancelled, inapplicable }
    private let store: WSSISnapshotStore
    private let client: WSSIClient
    private let enabled: @Sendable () -> Bool
    private let backgroundAcquisitionEnabled: Bool
    private let date: @Sendable () -> Date
    private let selectCoverage: @Sendable (WSSIScope?, Date) async throws -> Void
    private let observe: @Sendable (Outcome) -> Void
    private var task: Task<Void, Never>?
    private var running = false
    private var pending: WSSIScope?
    private var attempts: [(WSSIScope, Date)] = []
    private var requestedScope: WSSIScope?
    private var locationIntent = UUID()

    init(store: WSSISnapshotStore, client: WSSIClient,
         enabled: @escaping @Sendable () -> Bool = { false },
         backgroundAcquisitionEnabled: Bool = false,
         date: @escaping @Sendable () -> Date = { Date() },
         selectCoverage: (@Sendable (WSSIScope?, Date) async throws -> Void)? = nil,
         observe: @escaping @Sendable (Outcome) -> Void = {
             Logger.appHomeRefresh.info("WSSI ingestion outcome=\($0.rawValue, privacy: .public)")
         }) {
        self.store = store
        self.client = client
        self.enabled = enabled
        self.backgroundAcquisitionEnabled = backgroundAcquisitionEnabled
        self.date = date
        self.observe = observe
        self.selectCoverage = selectCoverage ?? { try await store.selectCoverage($0, at: $1) }
    }

    func admit(at point: Coordinate2D, foreground: Bool) async {
        guard foreground else { observe(.background); return }
        guard enabled() else { observe(.disabled); return }
        let intent = UUID()
        locationIntent = intent
        guard let fallback = WSSISourceApplicability.scope(at: point) else {
            requestedScope = nil
            pending = nil
            // Fence completion authority without discarding accepted data or cancelling its retention.
            do { try await selectCoverage(nil, date()) }
            catch { observe(.failed) }
            observe(.inapplicable)
            return
        }
        do {
            let scope = try await reusableScope(at: point) ?? fallback
            guard locationIntent == intent else { return }
            await admit(scope: scope, foreground: foreground)
        } catch { observe(.failed) }
    }

    private func reusableScope(at point: Coordinate2D) async throws -> WSSIScope? {
        // Read retained evidence first, then inspect current actor intent after the suspension.
        let now = date()
        let coverage = try await store.acceptedCoverage(at: now)
        if running, let requestedScope,
           WSSISourceApplicability.safelyContains(point, in: requestedScope) { return requestedScope }
        return coverage.snapshots.first {
            now >= $0.snapshot.verifiedAt && now.timeIntervalSince($0.snapshot.verifiedAt) < 7200
                && $0.snapshot.layers.allSatisfy { $0.validTo.map { $0 > now } ?? true }
                && WSSISourceApplicability.safelyContains(point, in: $0.snapshot.scope)
        }?.snapshot.scope
    }

    func admit(scope: WSSIScope, foreground: Bool) async {
        guard foreground else { observe(.background); return }
        guard enabled() else { observe(.disabled); return }
        let changesSelection = requestedScope != scope
        requestedScope = scope
        if running {
            if changesSelection {
                pending = scope
                do { try await selectCoverage(scope, date()) }
                catch { observe(.failed) }
            }
            observe(.busy)
            return
        }
        running = true
        let now = date()
        do {
            if changesSelection { try await selectCoverage(scope, now) }
            let coverage = try await store.acceptedCoverage(at: now)
            // A newer location intent may arrive during either store suspension.
            guard requestedScope == scope else { await finish(); return }
            if coverage.selectedScope == scope,
               let cached = coverage.snapshots.first(where: { $0.snapshot.scope == scope }),
               now >= cached.snapshot.verifiedAt,
               now.timeIntervalSince(cached.snapshot.verifiedAt) < 2 * 3600,
               cached.snapshot.layers.allSatisfy({ $0.validTo.map { $0 > now } ?? true }) {
                observe(.fresh)
                await finish()
                return
            }
        } catch { observe(.failed); await finish(); return }
        // Attempt cadence bounds failed-source traffic without asserting forecast validity.
        if let timestamp = attempts.first(where: { $0.0 == scope })?.1,
           now >= timestamp, now.timeIntervalSince(timestamp) < 2 * 3600 {
            observe(.backoff)
            await finish()
            return
        }
        attempts.removeAll { $0.0 == scope }
        attempts.append((scope, now))
        if attempts.count > 2 { attempts.removeFirst() }
        observe(.attempted)
        task = Task {
            do {
                _ = try await store.refreshCoverage(scope: scope, client: client, date: date)
                observe(.accepted)
            } catch is WSSISnapshotError { observe(.rejected)
            } catch is WSSIAcceptanceError { observe(.rejected)
            } catch { observe(.failed) }
            await finish()
        }
    }

    /// Awaited only after higher-priority background responsibilities finish. No task escapes this run.
    func refreshBackground(scope: WSSIScope, context: BackgroundRefreshExecutionContext,
                           waitUntil: @escaping @Sendable (ContinuousClock.Instant) async throws -> Void = {
                               try await ContinuousClock().sleep(until: $0)
                           }) async {
        guard enabled() else { observe(.disabled); return }
        guard !Task.isCancelled else { observe(.cancelled); return }
        // WSSI-01 measured 10.102s of pages for one scan; acceptance needs two plus inventories.
        // Defer before taking shared ownership so a background skip cannot consume foreground admission.
        guard backgroundAcquisitionEnabled else { observe(.deferredFeasibility); return }
        guard context.budget.admission(for: .seconds(6), at: .now, isCancelled: false) == .admitted,
              await !context.deadlineState.exceeded() else { observe(.deadline); return }
        guard !running else { observe(.busy); return }
        running = true // Reserve before the first store suspension; foreground shares this owner.
        let now = date()
        do {
            let coverage = try await store.acceptedCoverage(at: now)
            if let cached = coverage.snapshots.first(where: { $0.snapshot.scope == scope }),
               now >= cached.snapshot.verifiedAt,
               now.timeIntervalSince(cached.snapshot.verifiedAt) < 2 * 3600,
               cached.snapshot.layers.allSatisfy({ $0.validTo.map { $0 > now } ?? true }) {
                observe(.fresh)
            } else if let attempted = attempts.first(where: { $0.0 == scope })?.1,
                      now >= attempted, now.timeIntervalSince(attempted) < 2 * 3600 {
                observe(.backoff) // Source-failure backoff, independent of accepted forecast validity.
            } else {
                guard context.budget.admission(for: .seconds(6), at: .now, isCancelled: Task.isCancelled) == .admitted else {
                    observe(Task.isCancelled ? .cancelled : .deadline)
                    await finish()
                    return
                }
                attempts.removeAll { $0.0 == scope }
                attempts.append((scope, now))
                if attempts.count > 2 { attempts.removeFirst() }
                // Keep the existing unconditional two-scan stability proof; never synthesize a 304 proof.
                let store = store, client = client, date = date
                let deadline = min(context.budget.workDeadline - .seconds(1), ContinuousClock.now + .seconds(5))
                let outcome = try await withThrowingTaskGroup(of: Outcome.self) { group in
                    group.addTask {
                        _ = try await store.refreshCoverage(scope: scope, client: client, date: date)
                        return .accepted
                    }
                    group.addTask {
                        try await waitUntil(deadline)
                        try Task.checkCancellation()
                        return .deadline
                    }
                    defer { group.cancelAll() }
                    return try await group.next() ?? .cancelled
                }
                observe(outcome)
            }
        } catch is CancellationError { observe(.cancelled)
        } catch is WSSISnapshotError { observe(.rejected)
        } catch is WSSIAcceptanceError { observe(.rejected)
        } catch { observe(.failed) }
        await finish()
    }

    func refreshBackground(location: LocationSnapshot, context: BackgroundRefreshExecutionContext) async {
        guard enabled() else { observe(.disabled); return }
        let point = location.coordinates
        let age = date().timeIntervalSince(location.timestamp)
        // Reuse the established scheduled-location age tolerance and shared CONUS applicability.
        guard age.isFinite, age >= 0, age <= BackgroundLocationContextReusePolicy.maximumReuseAge,
              location.accuracy > 0, location.accuracy <= BackgroundLocationContextReusePolicy.maximumHorizontalAccuracy,
              let scope = WSSISourceApplicability.scope(at:
                .init(latitude: point.latitude, longitude: point.longitude)) else {
            observe(.inapplicable); return
        }
        // Avoid canonical storage work when this best-effort run cannot acquire anything.
        // The scope entry point rechecks these gates after the lookup suspension.
        guard !Task.isCancelled else { observe(.cancelled); return }
        guard backgroundAcquisitionEnabled else { observe(.deferredFeasibility); return }
        guard context.budget.admission(for: .seconds(6), at: .now, isCancelled: false) == .admitted,
              await !context.deadlineState.exceeded() else { observe(.deadline); return }
        let intent = locationIntent
        do {
            let selected = try await reusableScope(at: .init(latitude: point.latitude, longitude: point.longitude)) ?? scope
            guard locationIntent == intent else { observe(.busy); return }
            await refreshBackground(scope: selected, context: context)
        } catch { observe(.failed) }
    }

    private func finish() async {
        task = nil
        running = false
        if let next = pending {
            pending = nil
            await admit(scope: next, foreground: true)
        }
    }

    func waitForIdle() async { while let current = task { await current.value } }

    struct QueryResult: Sendable {
        enum Coverage: Sendable { case notLoaded, outsideCoverage, covered }
        let coverage: Coverage
        /// Preserves every accepted layer state, source dates, verification and commit provenance.
        /// Nil outside coverage: a noncontaining snapshot is never used as evidence for the point.
        let accepted: WSSICachedSnapshot?
        let assessment: WSSIAssessment
    }

    func assessment(at point: Coordinate2D, time: Date) async throws -> QueryResult {
        // An accepted regional query (even all-empty) is not evidence of provider applicability.
        guard WSSISourceApplicability.contains(point) else {
            return QueryResult(coverage: .outsideCoverage, accepted: nil,
                assessment: try WSSIAssessment.evaluate(layers: [], at: point, time: time))
        }
        let coverage = try await store.acceptedCoverage(at: date())
        let accepted = coverage.snapshots.first {
            let scope = $0.snapshot.scope
            return point.latitude >= scope.south && point.latitude <= scope.north
                && point.longitude >= scope.west && point.longitude <= scope.east
        }
        let layers = try accepted.map { cached in
            try cached.snapshot.layers.compactMap { try $0.assessmentLayer(in: cached.snapshot.scope) }
        } ?? []
        return QueryResult(coverage: accepted != nil ? .covered
            : coverage.snapshots.isEmpty ? .notLoaded : .outsideCoverage,
            accepted: accepted, assessment: try WSSIAssessment.evaluate(layers: layers, at: point, time: time))
    }
}
