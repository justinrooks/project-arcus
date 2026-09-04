//
//  BgHealthStore.swift
//  SkyAware
//

import Foundation
import OSLog
import SwiftData

struct BgRunFinalization: Sendable {
    let endedAt: Date
    let outcome: BgRunOutcome
    let didNotify: Bool
    let reasonNoNotify: String?
    let budgetSecUsed: Int
    let desiredNextRunAt: Date
    let cadence: Int
    let cadenceReason: String?
    let active: Duration
    let uploadDrainDuration: Duration?
    let uploadDrainOutcome: BgPhaseOutcome?
    let ingestionDuration: Duration?
    let ingestionOutcome: BgPhaseOutcome?
}

struct BgSchedulingOutcomes: Sendable, Equatable {
    let fallback: BgSchedulingOutcome?
    let authoritative: BgSchedulingOutcome?
}

@ModelActor
actor BgHealthStore {
    private let logger = Logger.backgroundOrchestrator

    func start(runId: String, startedAt: Date) throws {
        let descriptor = FetchDescriptor<BgRunSnapshot>(predicate: #Predicate { $0.runId == runId })
        guard try modelContext.fetch(descriptor).isEmpty else {
            return
        }

        modelContext.insert(BgRunSnapshot(runId: runId, startedAt: startedAt))
        try modelContext.save()
    }

    func finalize(runId: String, with finalization: BgRunFinalization) throws {
        guard let snapshot = try snapshot(for: runId) else {
            logger.error("Unable to finalize missing background diagnostic run")
            return
        }

        snapshot.endedAt = finalization.endedAt
        snapshot.outcomeRaw = finalization.outcome.rawValue
        snapshot.outcomeCode = finalization.outcome == .success ? 0 : 2
        snapshot.didNotify = finalization.didNotify
        snapshot.reasonNoNotify = finalization.reasonNoNotify
        snapshot.budgetSecUsed = finalization.budgetSecUsed
        snapshot.nextScheduledAt = finalization.desiredNextRunAt
        snapshot.cadence = finalization.cadence
        snapshot.cadenceReason = finalization.cadenceReason
        snapshot.activeSeconds = finalization.active.components.seconds
        snapshot.uploadDrainDurationSeconds = finalization.uploadDrainDuration?.components.seconds
        snapshot.uploadDrainOutcomeRaw = finalization.uploadDrainOutcome?.rawValue
        snapshot.ingestionDurationSeconds = finalization.ingestionDuration?.components.seconds
        snapshot.ingestionOutcomeRaw = finalization.ingestionOutcome?.rawValue
        try modelContext.save()
    }

    func recordUploadDrain(
        runId: String,
        duration: Duration,
        outcome: BgPhaseOutcome
    ) throws {
        guard let snapshot = try snapshot(for: runId) else {
            logger.error("Unable to record upload-drain phase for missing background diagnostic run")
            return
        }

        snapshot.uploadDrainDurationSeconds = duration.components.seconds
        snapshot.uploadDrainOutcomeRaw = outcome.rawValue
        try modelContext.save()
    }

    func recordIngestion(
        runId: String,
        duration: Duration,
        outcome: BgPhaseOutcome
    ) throws {
        guard let snapshot = try snapshot(for: runId) else {
            logger.error("Unable to record ingestion phase for missing background diagnostic run")
            return
        }

        snapshot.ingestionDurationSeconds = duration.components.seconds
        snapshot.ingestionOutcomeRaw = outcome.rawValue
        try modelContext.save()
    }

    func recordScheduling(
        runId: String,
        phase: BgSchedulingPhase,
        outcome: BgSchedulingOutcome
    ) throws {
        guard let snapshot = try snapshot(for: runId) else {
            logger.error("Unable to record scheduling for missing background diagnostic run")
            return
        }

        switch phase {
        case .fallback:
            snapshot.fallbackSchedulingOutcomeRaw = outcome.rawValue
        case .authoritative:
            snapshot.authoritativeSchedulingOutcomeRaw = outcome.rawValue
        }
        try modelContext.save()
    }

    func schedulingOutcomes(for runId: String) throws -> BgSchedulingOutcomes? {
        guard let snapshot = try snapshot(for: runId) else { return nil }
        return .init(
            fallback: snapshot.fallbackSchedulingOutcome,
            authoritative: snapshot.authoritativeSchedulingOutcome
        )
    }

    func latest() throws -> BgRunSnapshot? {
        var descriptor = FetchDescriptor<BgRunSnapshot>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func recent(limit: Int = 10) throws -> [BgRunSnapshot] {
        var descriptor = FetchDescriptor<BgRunSnapshot>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func purge(olderThan days: Int = 14, keepLast minKeep: Int = 200, now: Date = .now) throws {
        let all = try modelContext.fetch(FetchDescriptor<BgRunSnapshot>())
        guard all.count > minKeep else { return }

        let cutoff = Calendar(identifier: .gregorian).date(byAdding: .day, value: -days, to: now)!
        let doomed = all
            .sorted { $0.startedAt > $1.startedAt }
            .dropFirst(minKeep)
            .filter { $0.startedAt < cutoff }

        doomed.forEach { modelContext.delete($0) }
        if !doomed.isEmpty {
            try modelContext.save()
        }
    }

    private func snapshot(for runId: String) throws -> BgRunSnapshot? {
        let descriptor = FetchDescriptor<BgRunSnapshot>(predicate: #Predicate { $0.runId == runId })
        return try modelContext.fetch(descriptor).first
    }
}
