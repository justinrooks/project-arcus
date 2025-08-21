//
//  SpcFetcher.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/19/25.
//

import Foundation
import SwiftData

@ModelActor
actor SpcFetcher {
    func get(_ key: String) throws -> FeedCache? {
        try fetchCache(for: key)
    }
    
    // Upsert with minimal branching and no duplicated field assignments
    func upsert(_ key: String, applying patch: FeedCachePatch) throws {
        let row = try fetchCache(for: key) ?? {
            let r = FeedCache(feedKey: key)
            modelContext.insert(r)
            
            return r
        }()
        
        apply(patch, to: row)
        row.updatedAt = .now
        
        try modelContext.save()
    }
    
    // Fetch newest row for a given key (newest by updatedAt)
    private func fetchCache(for key: String) throws -> FeedCache? {
        let descriptor = FetchDescriptor<FeedCache>(
            predicate: #Predicate { $0.feedKey == key }//,
//            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }
        
    // Apply a patch onto an existing row
    private func apply(_ patch: FeedCachePatch, to row: FeedCache) {
        row.etag = patch.etag
        row.lastModified = patch.lastModified
        row.lastSuccessAt = patch.lastSuccessAt
        row.nextPlannedAt = patch.nextPlannedAt
        row.body = patch.body
    }
}
