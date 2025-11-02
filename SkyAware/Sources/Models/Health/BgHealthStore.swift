//
//  BgHealthStore.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/22/25.
//

import Foundation
import SwiftData
import CoreLocation
import OSLog

@ModelActor
actor BgHealthStore {
    private let logger = Logger.orchestrator
    
    func record(
        runId: String,
        startedAt: Date,
        endedAt: Date,
        outcomeCode: Int,
        didNotify: Bool,
        reasonNoNotify: String?,
        budgetSecUsed: Int,
        nextScheduledAt: Date,
        cadence: Int,
        cadenceReason: String?,
        active: Duration
    ) throws {
        let snap = BgRunSnapshot(
            runId: runId,
            startedAt: startedAt,
            endedAt: endedAt,
            outcomeCode: outcomeCode,
            didNotify: didNotify,
            reasonNoNotify: reasonNoNotify,
            budgetSecUsed: budgetSecUsed,
            nextScheduledAt: nextScheduledAt,
            cadence: cadence,
            cadenceReason: cadenceReason,
            active: active
        )
        
        modelContext.insert(snap)
        try modelContext.save()
    }
    
    func latest() throws -> BgRunSnapshot? {
        var d = FetchDescriptor<BgRunSnapshot>(sortBy: [SortDescriptor(\.endedAt, order: .reverse)])
        d.fetchLimit = 1
        return try modelContext.fetch(d).first
    }
    
    func recent(limit: Int = 10) throws -> [BgRunSnapshot] {
        var d = FetchDescriptor<BgRunSnapshot>(sortBy: [SortDescriptor(\.endedAt, order: .reverse)])
        d.fetchLimit = limit
        return try modelContext.fetch(d)
    }
    
    func purge(olderThan days: Int = 14, keepLast minKeep: Int = 200, now: Date = .now) throws {
        let all = try modelContext.fetch(FetchDescriptor<BgRunSnapshot>())
        guard all.count > minKeep else { return }
        
        let cutoff = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -days, to: now)!
        let doomed = all
            .sorted { $0.endedAt > $1.endedAt }
            .dropFirst(minKeep)
            .filter { $0.endedAt < cutoff }
        
        doomed.forEach { modelContext.delete($0) }
        if !doomed.isEmpty { try modelContext.save() }
    }
}
