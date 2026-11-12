import Foundation
import SwiftData

/// Persistence only: callers must establish complete observed stability before replacement.
/// It is intentionally unwired from acquisition, Home, notifications, and background scheduling.
@ModelActor
actor WSSISnapshotStore {
    static let maximumPayloadBytes = 100_000_000
    var acceptance = WSSIAcceptanceCoordinator()

    func read() throws -> [WSSICachedSnapshot] { try contents().snapshots }

    func issuanceWatermarks() throws -> [WSSIIssuanceWatermark] { try contents().watermarks }

    /// `select` is supplied by the eventual location-selection authority, never inferred from completion time.
    func replace(
        with snapshot: WSSISnapshot, select: Bool, now: Date,
        byteLimit: Int = WSSISnapshotStore.maximumPayloadBytes, failureAfterMutation: Bool = false
    ) throws -> WSSICachedSnapshot {
        guard (1...Self.maximumPayloadBytes).contains(byteLimit) else {
            throw WSSISnapshotError.capacityExceeded
        }
        try snapshot.validate()
        guard now.timeIntervalSince1970.isFinite, now >= snapshot.verifiedAt else {
            throw WSSISnapshotError.invalidSnapshot
        }
        var next = try contents()
        let previous = next.snapshots.first { $0.snapshot.scope == snapshot.scope }
        for layer in snapshot.layers {
            if let issuedAt = layer.issuedAt {
                let watermark = next.watermarks.first(where: {
                    $0.product == layer.product && $0.period == layer.period
                })
                if let watermark, issuedAt < watermark.issuedAt { throw WSSISnapshotError.staleIssuance }
                if let old = previous?.snapshot.layers.first(where: {
                    $0.product == layer.product && $0.period == layer.period
                }) {
                    // Empty observations erase comparable geometry, not the known issuance fence.
                    if (old.issuedAt == issuedAt && old != layer) ||
                        (old.state == .observedEmpty && watermark?.issuedAt == issuedAt) {
                        throw WSSISnapshotError.conflictingIssuance
                    }
                }
                if let index = next.watermarks.firstIndex(where: {
                    $0.product == layer.product && $0.period == layer.period
                }) {
                    next.watermarks[index].issuedAt = issuedAt
                } else {
                    next.watermarks.append(.init(product: layer.product, period: layer.period, issuedAt: issuedAt))
                }
            }
        }
        let unchanged = previous.map {
            $0.snapshot.source == snapshot.source && snapshot.layers.allSatisfy($0.snapshot.layers.contains)
        } ?? false
        if !unchanged {
            guard next.revision < Int64.max else { throw WSSISnapshotError.capacityExceeded }
            next.revision += 1
        }
        let entry = WSSICachedSnapshot(snapshot: snapshot, revision: unchanged ? previous?.revision ?? next.revision : next.revision,
                                       committedAt: unchanged ? previous?.committedAt ?? now : now,
                                       selectedAt: select ? now : previous?.selectedAt ?? .distantPast)
        // A verified identical payload may refresh retrieval time without changing its content commit time.
        let previousIndex = next.snapshots.firstIndex { $0.snapshot.scope == snapshot.scope }
        next.snapshots.removeAll { $0.snapshot.scope == snapshot.scope }
        // Array order is selection recency, independent of wall-clock adjustments.
        next.snapshots.insert(entry, at: select ? 0 : min(previousIndex ?? next.snapshots.count, next.snapshots.count))
        next.snapshots = Array(next.snapshots.prefix(2))
        prune(&next, now: now)
        try next.validate()
        let payload = try boundedPayload(&next, byteLimit: byteLimit)
        guard next.snapshots.contains(where: { $0.snapshot.scope == snapshot.scope }) else {
            throw WSSISnapshotError.capacityExceeded
        }
        try persist(payload, failureAfterMutation: failureAfterMutation)
        return entry
    }

    /// Selection authority is supplied by the co-isolated coordinator, never by acquisition completion.
    func selectRetainedScope(_ scope: WSSIScope, now: Date, byteLimit: Int = WSSISnapshotStore.maximumPayloadBytes) throws {
        guard (1...Self.maximumPayloadBytes).contains(byteLimit) else { throw WSSISnapshotError.capacityExceeded }
        guard now.timeIntervalSince1970.isFinite else { throw WSSISnapshotError.invalidSnapshot }
        var next = try contents()
        guard let index = next.snapshots.firstIndex(where: { $0.snapshot.scope == scope }) else { return }
        var entry = next.snapshots.remove(at: index)
        entry.selectedAt = now
        next.snapshots.insert(entry, at: 0)
        try persist(boundedPayload(&next, byteLimit: byteLimit), failureAfterMutation: false)
    }

    func prune(now: Date) throws {
        guard now.timeIntervalSince1970.isFinite else { throw WSSISnapshotError.invalidSnapshot }
        var next = try contents()
        prune(&next, now: now)
        try persist(encode(next), failureAfterMutation: false)
    }

    private func prune(_ contents: inout WSSICacheContents, now: Date) {
        contents.snapshots.removeAll { entry in
            now.timeIntervalSince(entry.snapshot.verifiedAt) >= 86_400 &&
                !entry.snapshot.layers.contains { ($0.validTo ?? .distantPast) > now }
        }
    }

    private func contents() throws -> WSSICacheContents {
        let rows = try modelContext.fetch(FetchDescriptor<WSSICacheRecord>())
        guard rows.count <= 1 else { throw WSSISnapshotError.invalidSnapshot }
        guard let row = rows.first else { return WSSICacheContents() }
        guard row.formatVersion == 1, row.payload.count <= Self.maximumPayloadBytes else {
            throw WSSISnapshotError.invalidSnapshot
        }
        let decoded = try JSONDecoder().decode(WSSICacheContents.self, from: row.payload)
        try decoded.validate()
        return decoded
    }

    private func boundedPayload(_ next: inout WSSICacheContents, byteLimit: Int) throws -> Data {
        var payload = try encode(next)
        while payload.count > byteLimit && next.snapshots.count > 1 {
            next.snapshots.removeLast()
            payload = try encode(next)
        }
        guard payload.count <= byteLimit else { throw WSSISnapshotError.capacityExceeded }
        return payload
    }

    private func encode(_ contents: WSSICacheContents) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(contents)
    }

    private func persist(_ payload: Data, failureAfterMutation: Bool) throws {
        try Task.checkCancellation()
        do {
            let rows = try modelContext.fetch(FetchDescriptor<WSSICacheRecord>())
            if let row = rows.first { row.payload = payload } else {
                modelContext.insert(WSSICacheRecord(payload: payload))
            }
            if failureAfterMutation { throw WSSISnapshotError.injectedFailure }
            try Task.checkCancellation()
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
