//
//  BgRunSnapshot.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/22/25.
//

import Foundation
import SwiftData

@Model
final class BgRunSnapshot {
    @Attribute(.unique) var runId: String
    var startedAt: Date
    var endedAt: Date
    var outcomeCode: Int
    var didNotify: Bool
    var reasonNoNotify: String?
    var budgetSecUsed: Int
    var nextScheduledAt: Date
    var cadence: Int
    var cadenceReason: String?
    
    init(
        runId: String,
        startedAt: Date,
        endedAt: Date,
        outcomeCode: Int,
        didNotify: Bool,
        reasonNoNotify: String? = nil,
        budgetSecUsed: Int,
        nextScheduledAt: Date,
        cadence: Int,
        cadenceReason: String? = nil
    ) {
        self.runId = runId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.outcomeCode = outcomeCode
        self.didNotify = didNotify
        self.reasonNoNotify = reasonNoNotify
        self.budgetSecUsed = budgetSecUsed
        self.nextScheduledAt = nextScheduledAt
        self.cadence = cadence
        self.cadenceReason = cadenceReason
    }
    
    var durationSec: Double { endedAt.timeIntervalSince(startedAt) }
}
