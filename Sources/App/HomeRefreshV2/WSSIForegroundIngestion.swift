import Foundation
import OSLog

/// Independent foreground work: never awaited by the Home ingestion result or admitted by background plans.
actor WSSIForegroundIngestion {
    enum Outcome: String, Sendable { case disabled, background, busy, fresh, accepted, rejected, failed }
    private let store: WSSISnapshotStore
    private let client: WSSIClient
    private let enabled: @Sendable () -> Bool
    private let date: @Sendable () -> Date
    private let selectCoverage: @Sendable (WSSIScope, Date) async throws -> Void
    private let observe: @Sendable (Outcome) -> Void
    private var task: Task<Void, Never>?
    private var running = false
    private var pending: WSSIScope?
    private var attempts: [(WSSIScope, Date)] = []
    private var requestedScope: WSSIScope?

    init(store: WSSISnapshotStore, client: WSSIClient,
         enabled: @escaping @Sendable () -> Bool = { false },
         date: @escaping @Sendable () -> Date = { Date() },
         selectCoverage: (@Sendable (WSSIScope, Date) async throws -> Void)? = nil,
         observe: @escaping @Sendable (Outcome) -> Void = {
             Logger.appHomeRefresh.info("WSSI foreground outcome=\($0.rawValue, privacy: .public)")
         }) {
        self.store = store
        self.client = client
        self.enabled = enabled
        self.date = date
        self.observe = observe
        self.selectCoverage = selectCoverage ?? { try await store.selectCoverage($0, at: $1) }
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
        } catch { observe(.failed); await finish(); return }
        // Attempt cadence bounds failed-source traffic without asserting forecast validity.
        if let timestamp = attempts.first(where: { $0.0 == scope })?.1,
           now >= timestamp, now.timeIntervalSince(timestamp) < 2 * 3600 {
            observe(.fresh)
            await finish()
            return
        }
        attempts.removeAll { $0.0 == scope }
        attempts.append((scope, now))
        if attempts.count > 2 { attempts.removeFirst() }
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
