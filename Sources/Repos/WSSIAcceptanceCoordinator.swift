import Foundation

enum WSSIAcceptanceError: Error, Equatable { case superseded }

/// State owned exclusively by the persistence actor. There is no cross-actor check-to-save gap.
struct WSSIAcceptanceCoordinator {
    struct Attempt: Sendable, Equatable {
        let id: UInt64
        let scope: WSSIScope
        let selection: UUID
    }
    private var sequence: UInt64 = 0
    var started = false
    var selection = UUID()
    var selectedScope: WSSIScope?
    var attempts: [Attempt] = []

    mutating func admit(scope: WSSIScope) throws -> Attempt {
        guard sequence < UInt64.max else { throw WSSISnapshotError.capacityExceeded }
        sequence += 1
        let attempt = Attempt(id: sequence, scope: scope, selection: selection)
        attempts.removeAll { $0.scope == scope }
        attempts.append(attempt)
        return attempt
    }

    mutating func finish(_ attempt: Attempt) { attempts.removeAll { $0 == attempt } }
}

struct WSSIAcceptedCoverage: Sendable {
    let selectedScope: WSSIScope?
    let snapshots: [WSSICachedSnapshot]
}

extension WSSISnapshotStore {
    /// Startup is lazy but synchronous: every public coordinator entry prunes before observing/admitting work.
    private func startAcceptance(at now: Date) throws {
        guard !acceptance.started else { return }
        try prune(now: now)
        acceptance.selectedScope = try read().first(where: { $0.selectedAt != .distantPast })?.snapshot.scope
        acceptance.started = true
    }

    /// Call on location intent, independently of refresh success or completion order.
    func selectCoverage(_ scope: WSSIScope?, at now: Date = .now) throws {
        try startAcceptance(at: now)
        if let scope { try selectRetainedScope(scope, now: now) }
        acceptance.selection = UUID()
        acceptance.selectedScope = scope
    }

    func acceptedCoverage(at now: Date = .now) throws -> WSSIAcceptedCoverage {
        try startAcceptance(at: now)
        return WSSIAcceptedCoverage(selectedScope: acceptance.selectedScope, snapshots: try read())
    }

    /// Acquisition runs outside the actor; admission and final authority checks remain co-isolated with save.
    func refreshCoverage(scope: WSSIScope, client: WSSIClient,
                         date: @Sendable () -> Date = { Date() }) async throws -> WSSICachedSnapshot {
        try startAcceptance(at: date())
        let attempt = try acceptance.admit(scope: scope)
        defer { acceptance.finish(attempt) }
        let snapshot = try await client.acquireVerified(scope: scope, date: date)
        try Task.checkCancellation()
        guard acceptance.attempts.contains(attempt) else { throw WSSIAcceptanceError.superseded }
        let selects = attempt.selection == acceptance.selection && acceptance.selectedScope == scope
        // No await between the authority check and the existing synchronous atomic persistence seam.
        return try replace(with: snapshot, select: selects, now: date())
    }
}
