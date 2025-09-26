//
//  PreviewContainer.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/13/25.
//

import Foundation
import SwiftData

struct Preview {
    let container: ModelContainer
    let outlookRepo: ConvectiveOutlookRepo
    let stormRiskRepo: StormRiskRepo
    let severeRiskRepo: SevereRiskRepo
    let mesoRepo: MesoRepo
    let watchRepo: WatchRepo
//    let provider: SpcProviderV1
    
    init(_ models: any PersistentModel.Type ...) {
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
        
//        let loc = LocationManager()
//        
//        self.provider = SpcProviderV1(outlookRepo: self.outlookRepo,
//                                 mesoRepo: self.mesoRepo,
//                                 watchRepo: self.watchRepo,
//                                 stormRiskRepo: self.stormRiskRepo,
//                                 severeRiskRepo: self.severeRiskRepo,
//                                 locationManager: loc)
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
