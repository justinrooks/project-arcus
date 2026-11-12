import Foundation
import OSLog

/// Independent foreground work: never awaited by the Home ingestion result or admitted by background plans.
actor WSSIForegroundIngestion {
    enum Outcome: String, Sendable { case disabled, background, busy, fresh, accepted, rejected, failed }
    private let store: WSSISnapshotStore
    private let client: WSSIClient
    private let enabled: @Sendable () -> Bool
    private let date: @Sendable () -> Date
    private let observe: @Sendable (Outcome) -> Void
    private var task: Task<Void, Never>?
    private var running = false
    private var pending: WSSIScope?
    private var attempts: [(WSSIScope, Date)] = []
    private var requestedScope: WSSIScope?

    init(store: WSSISnapshotStore, client: WSSIClient,
         enabled: @escaping @Sendable () -> Bool = { false },
         date: @escaping @Sendable () -> Date = { Date() },
         observe: @escaping @Sendable (Outcome) -> Void = {
             Logger.appHomeRefresh.info("WSSI foreground outcome=\($0.rawValue, privacy: .public)")
         }) {
        self.store = store
        self.client = client
        self.enabled = enabled
        self.date = date
        self.observe = observe
    }

    func admit(scope: WSSIScope, foreground: Bool) async {
        guard foreground else { observe(.background); return }
        guard enabled() else { observe(.disabled); return }
        let changesSelection = requestedScope != scope
        requestedScope = scope
        if running {
            if changesSelection {
                pending = scope
                do { try await store.selectCoverage(scope, at: date()) }
                catch { observe(.failed) }
            }
            observe(.busy)
            return
        }
        running = true
        let now = date()
        do {
            if changesSelection { try await store.selectCoverage(scope, at: now) }
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

    func assessment(at point: Coordinate2D, time: Date) async throws -> WSSIAssessment {
        let coverage = try await store.acceptedCoverage(at: date())
        let snapshot = (coverage.snapshots.first {
            let scope = $0.snapshot.scope
            return point.latitude >= scope.south && point.latitude <= scope.north
                && point.longitude >= scope.west && point.longitude <= scope.east
        } ?? coverage.snapshots.first)?.snapshot
        let layers = try snapshot.map { snapshot in
            try snapshot.layers.compactMap { try $0.assessmentLayer(in: snapshot.scope) }
        } ?? []
        return try WSSIAssessment.evaluate(layers: layers, at: point, time: time)
    }
}
