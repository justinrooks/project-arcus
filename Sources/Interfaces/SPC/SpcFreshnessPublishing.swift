//
//  SpcFreshnessPublishing.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import Foundation
import CoreLocation

protocol SpcFreshnessPublishing: Sendable {
    
    // MARK: Freshness APIs
    // 1) Layer-scope: “what’s the latest ISSUE among what we’re showing?”
    func latestIssue(for product: GeoJSONProduct) async throws -> Date?
    func latestIssue(for product: RssProduct) async throws -> Date?

    // 2) Location-scope: “what’s the ISSUE of the feature that applies here?”
    func latestIssue(for product: GeoJSONProduct, at coord: CLLocationCoordinate2D) async throws -> Date?
    func latestIssue(for product: RssProduct, at coord: CLLocationCoordinate2D) async throws -> Date?

    // MARK: Streams
    // SIMPLE: convective-only freshness (seed + stream)
    func convectiveIssueUpdates() async -> AsyncStream<Date>
    
    // Optional: a unifying signal if you want push instead of polling
//    func issueUpdates(for product: GeoJSONProduct) -> AsyncStream<Date>
//    func issueUpdates(for product: RssProduct) -> AsyncStream<Date>
}
