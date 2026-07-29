//
//  BgRunSnapshot.swift
//  SkyAware
//

import Foundation
import SwiftData

enum BgRunOutcome: String, CaseIterable, Sendable {
    case success
    case skipped
    case failed
    case cancelled
    case expired
}

enum BgPhaseOutcome: String, Sendable {
    case completed
    case skipped
    case failed
    case cancelled
    case expired
    case drained
    case remaining
}

enum BgSchedulingOutcome: String, Sendable {
    case submitted
    case preservedExisting
    case preservedImmediate
    case submissionFailed
    case restoredPrevious
    case restorationFailed

    var preservesSuccessor: Bool {
        switch self {
        case .submitted, .preservedExisting, .preservedImmediate, .restoredPrevious:
            true
        case .submissionFailed, .restorationFailed:
            false
        }
    }
}

enum BgSchedulingPhase: Sendable {
    case fallback
    case authoritative
}

@Model
final class BgRunSnapshot {
    @Attribute(.unique) var runId: String
    var startedAt: Date
    var endedAt: Date?

    // Retained for existing stores. New diagnostics use outcomeRaw.
    var outcomeCode: Int = 2
    var outcomeRaw: String?
    var didNotify: Bool = false
    var reasonNoNotify: String?
    var budgetSecUsed: Int = 0
    /// The app's desired cadence date, not confirmation that iOS will launch the task then.
    var nextScheduledAt: Date?
    var cadence: Int = 0
    var cadenceReason: String?
    var activeSeconds: Int64 = 0

    var uploadDrainDurationSeconds: Int64?
    var uploadDrainOutcomeRaw: String?
    var ingestionDurationSeconds: Int64?
    var ingestionOutcomeRaw: String?
    var fallbackSchedulingOutcomeRaw: String?
    var authoritativeSchedulingOutcomeRaw: String?

    init(runId: String, startedAt: Date) {
        self.runId = runId
        self.startedAt = startedAt
    }

    var outcome: BgRunOutcome? {
        if let outcomeRaw {
            return BgRunOutcome(rawValue: outcomeRaw)
        }

        guard endedAt != nil else { return nil }
        return outcomeCode == 0 ? .success : .failed
    }

    var uploadDrainOutcome: BgPhaseOutcome? {
        uploadDrainOutcomeRaw.flatMap(BgPhaseOutcome.init(rawValue:))
    }

    var ingestionOutcome: BgPhaseOutcome? {
        ingestionOutcomeRaw.flatMap(BgPhaseOutcome.init(rawValue:))
    }

    var fallbackSchedulingOutcome: BgSchedulingOutcome? {
        fallbackSchedulingOutcomeRaw.flatMap(BgSchedulingOutcome.init(rawValue:))
    }

    var authoritativeSchedulingOutcome: BgSchedulingOutcome? {
        authoritativeSchedulingOutcomeRaw.flatMap(BgSchedulingOutcome.init(rawValue:))
    }

    var isComplete: Bool {
        endedAt != nil && outcome != nil
    }

    var durationSec: Double? {
        endedAt?.timeIntervalSince(startedAt)
    }
}
