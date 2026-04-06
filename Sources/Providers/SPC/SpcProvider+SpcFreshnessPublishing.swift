//
//  SpcProvider+SpcFreshnessPublishing.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/1/25.
//

import Foundation
import CoreLocation

// MARK: SpcFreshnessPublishing
extension SpcProvider: SpcFreshnessPublishing {
    // 1) Layer-scope: “what’s the latest ISSUE among what we’re showing?”
    func latestIssue(for product: GeoJSONProduct) async throws -> Date? {
        return nil
    }
    
    func latestIssue(for product: RssProduct) async throws -> Date? {
        try await outlookRepo.current()?.published
    }

    // 2) Location-scope: “what’s the ISSUE of the feature that applies here?”
    func latestIssue(for product: GeoJSONProduct, at coord: CLLocationCoordinate2D) async throws -> Date? {
        return nil
    }
    
    func latestIssue(for product: RssProduct, at coord: CLLocationCoordinate2D) async throws -> Date? {
        return nil
    }
}
