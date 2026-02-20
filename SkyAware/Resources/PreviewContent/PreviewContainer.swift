//
//  PreviewContainer.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/13/25.
//

import Foundation
import SwiftData
import CoreLocation

struct Preview {
    let container: ModelContainer
    let outlookRepo: ConvectiveOutlookRepo
    let stormRiskRepo: StormRiskRepo
    let severeRiskRepo: SevereRiskRepo
    let mesoRepo: MesoRepo
    let watchRepo: WatchRepo
    //let provider: SpcService
    
    init(
        _ models: any PersistentModel.Type ...) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(models)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Error creating preview model container")
        }
        
        self.outlookRepo    = ConvectiveOutlookRepo(modelContainer: container)
        self.mesoRepo       = MesoRepo(modelContainer: container)
        self.watchRepo      = WatchRepo(modelContainer: container)
        self.stormRiskRepo  = StormRiskRepo(modelContainer: container)
        self.severeRiskRepo = SevereRiskRepo(modelContainer: container)
        
//        self.provider = MockSpcService(storm: stormRisk, severe: severeRisk)
//        let loc = LocationManager()

    }
    @MainActor
    func addExamples(_ examples: [any PersistentModel]) {
        Task { @MainActor in
            examples.forEach { ex in
                container.mainContext.insert(ex)
            }
        }
    }
}


extension MockSpcService: SpcSyncing {
    func sync() async {}
    func syncTextProducts() async {}
    func syncMapProducts() async {}
    func syncConvectiveOutlooks() async {}
    func syncMesoscaleDiscussions() async {}
}

extension MockSpcService: SpcRiskQuerying {
    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel { self.stormRisk }
    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat { self.severeRisk }
    func getActiveMesos(at time: Date, for point: CLLocationCoordinate2D) async throws -> [MdDTO] { [] }
    func getFireRisk(for point: CLLocationCoordinate2D) async throws -> FireRiskLevel {
        .extreme
    }
}

extension MockSpcService: SpcFreshnessPublishing {
    // MARK: Freshness APIs
    // 1) Layer-scope: “what’s the latest ISSUE among what we’re showing?”
    func latestIssue(for product: GeoJSONProduct) async throws -> Date? { .now }
    func latestIssue(for product: RssProduct) async throws -> Date? { .now }

    // 2) Location-scope: “what’s the ISSUE of the feature that applies here?”
    func latestIssue(for product: GeoJSONProduct, at coord: CLLocationCoordinate2D) async throws -> Date? { .now }
    func latestIssue(for product: RssProduct, at coord: CLLocationCoordinate2D) async throws -> Date? { .now }
    
    func convectiveIssueUpdates() async -> AsyncStream<Date> {
        AsyncStream<Date> { continuation in
            // Emit a fake initial value
            continuation.yield(Date())
            // Optionally emit another update a few seconds later (useful for preview)
            Task {
                try? await Task.sleep(for: .seconds(3))
                continuation.yield(Date().addingTimeInterval(60 * 30)) // “30m later”
                continuation.finish()
            }
        }
    }
}

extension MockSpcService: SpcOutlookQuerying {
    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO? {
        ConvectiveOutlook.sampleOutlookDtos.last!
    }
    
    func getConvectiveOutlooks() async throws -> [ConvectiveOutlookDTO] {
        ConvectiveOutlook.sampleOutlookDtos
    }
}

extension MockSpcService: SpcCleanup {
    func cleanup(daysToKeep: Int) async {}
}

extension MockSpcService: SpcMapData {
    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] { [] }
    func getStormRiskMapData() async throws -> [StormRiskDTO] {[StormRiskDTO]()}
    func getMesoMapData() async throws -> [MdDTO] { [MdDTO]() }
    func getFireRisk() async throws -> [FireRiskDTO] {
        []
    }
}

struct MockSpcService {
    let stormRisk: StormRiskLevel
    let severeRisk: SevereWeatherThreat
    
    init(storm: StormRiskLevel, severe: SevereWeatherThreat){
        self.stormRisk = storm
        self.severeRisk = severe
    }
}
