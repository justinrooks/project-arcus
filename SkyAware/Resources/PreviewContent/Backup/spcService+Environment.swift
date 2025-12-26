//
//  spcService+Environment.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/25/25.
//

import SwiftUI
import CoreLocation
import SwiftData

//struct MissingError: Error {}

// Crash loudly in DEBUG if you forgot to inject.
//private struct EmptyRiskQuerying: SpcRiskQuerying {
//    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel {
//        assertionFailure("⚠️ SpcService not injected into environment"); throw MissingError()
//    }
//    
//    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat {
//        assertionFailure("⚠️ SpcService not injected into environment"); throw MissingError()
//    }
//    func getActiveMesos(at time: Date, for point: CLLocationCoordinate2D) async throws -> [MdDTO] {
//        assertionFailure("⚠️ SpcService not injected into environment"); throw MissingError()
//    }
//}
//
//private struct EmptySyncing: SpcSyncing {
//    func sync() async {
//        assertionFailure("⚠️ SpcService not injected into environment")
//    }
//    
//    func syncMapProducts() async {
//        assertionFailure("⚠️ SpcService not injected into environment")
//    }
//    
//    func syncTextProducts() async {
//        assertionFailure("⚠️ SpcService not injected into environment")
//    }
//    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO? {
//        assertionFailure(" NOT INJECTED "); throw MissingError()
//    }
//}
//
//private struct EmptyMapData: SpcMapData {
//    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
//        assertionFailure(" Not injected "); throw MissingError()
//    }
//    func getStormRiskMapData() async throws -> [StormRiskDTO] {assertionFailure("NOT INJECTED"); throw MissingError()}
//    func getMesoMapData() async throws -> [MdDTO] { assertionFailure("NOT INJECTED"); throw MissingError() }
//}

//private struct EmptyFreshness: SpcFreshnessPublishing {
//    // MARK: Freshness APIs
//    // 1) Layer-scope: “what’s the latest ISSUE among what we’re showing?”
//    func latestIssue(for product: GeoJSONProduct) async throws -> Date? { assertionFailure("NOT INJECTED"); throw MissingError() }
//    func latestIssue(for product: RssProduct) async throws -> Date? { assertionFailure("NOT INJECTED"); throw MissingError() }
//
//    // 2) Location-scope: “what’s the ISSUE of the feature that applies here?”
//    func latestIssue(for product: GeoJSONProduct, at coord: CLLocationCoordinate2D) async throws -> Date? { assertionFailure("NOT INJECTED"); throw MissingError() }
//    func latestIssue(for product: RssProduct, at coord: CLLocationCoordinate2D) async throws -> Date? { assertionFailure("NOT INJECTED"); throw MissingError() }
//    
//    func convectiveIssueUpdates() async -> AsyncStream<Date> {
//        AsyncStream<Date> { continuation in
//            // Emit a fake initial value
//            continuation.yield(Date())
//            // Optionally emit another update a few seconds later (useful for preview)
//            Task {
//                try? await Task.sleep(for: .seconds(3))
//                continuation.yield(Date().addingTimeInterval(60 * 30)) // “30m later”
//                continuation.finish()
//            }
//        }
//    }
//}
//
//private struct EmptyOutlookQuerying: SpcOutlookQuerying {
//    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO? {
//        assertionFailure("NOT INJECTED"); throw MissingError()
//    }
//    
//    func getConvectiveOutlooks() async throws -> [ConvectiveOutlookDTO] {
//        assertionFailure("NOT INJECTED"); throw MissingError()
//    }
//}
//
//private struct EmptyNwsRiskQuerying: NwsRiskQuerying {
//    func getActiveWatches(for point: CLLocationCoordinate2D) async throws -> [WatchDTO] {
//        assertionFailure("NOT INJECTED"); throw MissingError()
//    }
//}
//
//private struct EmptyNwsSyncing: NwsSyncing {
//    func fetchPointMetadata(for point: CLLocationCoordinate2D) async {
//        assertionFailure("⚠️ NwsSyncing not injected into environment")
//    }
//    
//    func sync(for point: CLLocationCoordinate2D) async {
//        assertionFailure("⚠️ NwsSyncing not injected into environment")
//    }
//}

//private struct MissingSpcService: SpcService {
//    // MARK: Freshness APIs
//    // 1) Layer-scope: “what’s the latest ISSUE among what we’re showing?”
//    func latestIssue(for product: GeoJSONProduct) async throws -> Date? { assertionFailure("NOT INJECTED"); throw MissingError() }
//    func latestIssue(for product: RssProduct) async throws -> Date? { assertionFailure("NOT INJECTED"); throw MissingError() }
//
//    // 2) Location-scope: “what’s the ISSUE of the feature that applies here?”
//    func latestIssue(for product: GeoJSONProduct, at coord: CLLocationCoordinate2D) async throws -> Date? { assertionFailure("NOT INJECTED"); throw MissingError() }
//    func latestIssue(for product: RssProduct, at coord: CLLocationCoordinate2D) async throws -> Date? { assertionFailure("NOT INJECTED"); throw MissingError() }
//    
//    func convectiveIssueUpdates() async -> AsyncStream<Date> {
//        AsyncStream<Date> { continuation in
//            // Emit a fake initial value
//            continuation.yield(Date())
//            // Optionally emit another update a few seconds later (useful for preview)
//            Task {
//                try? await Task.sleep(for: .seconds(3))
//                continuation.yield(Date().addingTimeInterval(60 * 30)) // “30m later”
//                continuation.finish()
//            }
//        }
//    }
//    
//}

extension EnvironmentValues {
//    @Entry var spcService: any SpcService = MissingSpcService()
//    @Entry var spcFreshness: any SpcFreshnessPublishing = EmptyFreshness()
//    @Entry var riskQuery: any SpcRiskQuerying = EmptyRiskQuerying()
//    @Entry var spcSync: any SpcSyncing = EmptySyncing()
//    @Entry var mapData: any SpcMapData = EmptyMapData()
//    @Entry var outlookQuery: any SpcOutlookQuerying = EmptyOutlookQuerying()
    
//    @Entry var nwsRiskQuery: any NwsRiskQuerying = EmptyNwsRiskQuerying()
//    @Entry var nwsSyncing: any NwsSyncing = EmptyNwsSyncing()
}
