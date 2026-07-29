//
//  BgRunSnapshotSamples.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/2/25.
//

import Foundation

extension BgRunSnapshot {
    private static func add(
        _ deltaMinutes: Int,
        outcome: BgRunOutcome?,
        didNotify: Bool,
        nextOffsetMin: Int,
        reason: String? = nil
    ) -> BgRunSnapshot {
        let now = Date()
        let start = now.addingTimeInterval(TimeInterval(-(deltaMinutes * 60 + 10)))
        let end   = now.addingTimeInterval(TimeInterval(-deltaMinutes * 60))
        let snapshot = BgRunSnapshot(runId: "demo-\(UUID().uuidString.prefix(6))", startedAt: start)
        snapshot.endedAt = outcome == nil ? nil : end
        snapshot.outcomeRaw = outcome?.rawValue
        snapshot.didNotify = didNotify
        snapshot.reasonNoNotify = reason
        snapshot.budgetSecUsed = 12
        snapshot.nextScheduledAt = now.addingTimeInterval(TimeInterval(nextOffsetMin * 60))
        snapshot.cadence = 20
        snapshot.cadenceReason = "Demo cadence"
        snapshot.activeSeconds = 12
        snapshot.uploadDrainDurationSeconds = 2
        snapshot.uploadDrainOutcomeRaw = BgPhaseOutcome.drained.rawValue
        snapshot.ingestionDurationSeconds = 8
        snapshot.ingestionOutcomeRaw = outcome == .expired ? BgPhaseOutcome.expired.rawValue : BgPhaseOutcome.completed.rawValue
        snapshot.fallbackSchedulingOutcomeRaw = BgSchedulingOutcome.submitted.rawValue
        snapshot.authoritativeSchedulingOutcomeRaw = outcome == .failed
            ? BgSchedulingOutcome.submissionFailed.rawValue
            : BgSchedulingOutcome.submitted.rawValue
        return snapshot
    }
    
    static var sampleRuns: [BgRunSnapshot] {
        var result: [BgRunSnapshot] = []
        result.append(
            add(5, outcome: .success, didNotify: true, nextOffsetMin: 55)
        )
        result.append(
            add(72, outcome: .skipped, didNotify: false, nextOffsetMin: -10, reason: "No change since last issue")
        )
        result.append(
            add(185, outcome: .failed, didNotify: false, nextOffsetMin: -90, reason: "Network error")
            )
        
        return result
    }
}
