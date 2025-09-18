//
//  WatchRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import SwiftData
import OSLog

@ModelActor
actor WatchRepo {
    private var context: ModelContext { modelExecutor.modelContext }
    private let logger = Logger.watchRepo
    
    func refreshWatches() async throws {
        let client = SpcClient()
        let items = try await client.fetchWatchItems()
        
        // Filters out some odd contents
        let watches = items
            .filter {
                guard let t = $0.title else { return false }
                return t.contains("Watch") && !t.contains("Status Reports")
            }
            .compactMap { makeWatchDto(from: $0) }
        
        try await upsertWatches(watches)
        logger.debug("Parsed \(watches.count) watch\(watches.count > 1 ? "es" : "") from SPC")
    }
    
    private func makeWatchDto(from rssItem: Item) -> WatchDTO? {
        guard
            let title = rssItem.title,
            let linkString = rssItem.link,
            let link = URL(string: linkString),
            let pubDateString = rssItem.pubDate,
            let summary = rssItem.description,
            let published = DateFormatter.rfc822.date(from: pubDateString)
        else { return nil }
        
        return WatchDTO(
            title: title,
            link: link,
            issued: published,
            summary: summary
        )
    }
    
    private func upsertWatches(_ watches: [WatchDTO]) async throws {
        _ = try watches.map {
            guard let w = WatchModel(from: $0) else { throw OtherErrors.contextSaveError }
            context.insert(w)
        }
        
        try context.save()
    }
}
