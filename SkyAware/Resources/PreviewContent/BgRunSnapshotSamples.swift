//
//  BgRunSnapshotSamples.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/2/25.
//

import Foundation

extension BgRunSnapshot {
    private static func add(_ deltaMinutes: Int, outcome: Int, didNotify: Bool, nextOffsetMin: Int, reason: String? = nil) -> BgRunSnapshot {
        let now = Date()
        let start = now.addingTimeInterval(TimeInterval(-(deltaMinutes * 60 + 10)))
        let end   = now.addingTimeInterval(TimeInterval(-deltaMinutes * 60))
        return .init(
            runId: "demo-\(UUID().uuidString.prefix(6))",
            startedAt: start,
            endedAt: end,
            outcomeCode: outcome,
            didNotify: didNotify,
            reasonNoNotify: reason,
            budgetSecUsed: Int.random(in: 6...18),
            nextScheduledAt: now.addingTimeInterval(TimeInterval(nextOffsetMin * 60)),
            cadence: 20,
            cadenceReason: "Demo cadence",
            active: .seconds(5)
        )
    }
    
    static var sampleRuns: [BgRunSnapshot] {
        var result: [BgRunSnapshot] = []
        result.append(
            add(5, outcome: 0, didNotify: true,  nextOffsetMin: 55)
        )
        result.append(
            add(72, outcome: 1, didNotify: false, nextOffsetMin: -10, reason: "No change since last issue")
        )
        result.append(
            add(185, outcome: 2, didNotify: false, nextOffsetMin: -90, reason: "Network error")
            )
        
        return result
    }
}
