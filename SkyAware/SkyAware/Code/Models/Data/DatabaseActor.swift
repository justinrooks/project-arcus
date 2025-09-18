//
//  DatabaseActor.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/12/25.
//

import Foundation
import SwiftData

//@available(iOS 17, *)
@ModelActor
actor DatabaseActor: Sendable {
    private var ctx: ModelContext { modelExecutor.modelContext }
        
    func upsertConvectiveOutlooks(_ outlooks: [ConvectiveOutlookDTO]) async throws {
        _ = try outlooks.map {
            guard let m = ConvectiveOutlook(from: $0) else { throw OtherErrors.contextSaveError }
            ctx.insert(m)
        }
        
        try ctx.save()
    }
    
    func upsertMesos(_ md: [MdDTO]) async throws {
        _ = try md.map {
            guard let m = MD(from: $0) else { throw OtherErrors.contextSaveError }
            ctx.insert(m)
        }
        
        try ctx.save()
    }

    func upsertWatches(_ watches: [WatchDTO]) async throws {
        _ = try watches.map {
            guard let w = WatchModel(from: $0) else { throw OtherErrors.contextSaveError }
            ctx.insert(w)
        }
        
        try ctx.save()
    }
    
    func upsertStormRisk(_ risks: [StormRiskDTO]) async throws {
        _ = try risks.map {
            guard let w = StormRisk(from: $0) else { throw OtherErrors.contextSaveError }
            ctx.insert(w)
        }
        
        try ctx.save()
    }
    
    func upsertHailRisk(_ risks: [SevereRiskDTO]) async throws {
        _ = try risks.map {
            guard let w = SevereRisk(from: $0) else { throw OtherErrors.contextSaveError }
            ctx.insert(w)
        }
        
        try ctx.save()
    }
    
    func upsertWindRisk(_ risks: [SevereRiskDTO]) async throws {
        _ = try risks.map {
            guard let w = SevereRisk(from: $0) else { throw OtherErrors.contextSaveError }
            ctx.insert(w)
        }
        
        try ctx.save()
    }
    
    func upsertTornadoRisk(_ risks: [SevereRiskDTO]) async throws {
        _ = try risks.map {
            guard let w = SevereRisk(from: $0) else { throw OtherErrors.contextSaveError }
            ctx.insert(w)
        }
        
        try ctx.save()
    }
    
//    func create<T: PersistentModel>(todo: [T]) throws {
//        _ = todo.map { ctx.insert($0) }
//        try ctx.save()
//    }
//    
//    func getAll<T: PersistentModel>() throws -> [T]? {
//        let fetchDescriptor = FetchDescriptor<T>()
//        return try? ctx.fetch(fetchDescriptor)
//    }
//    
    func fetchConvectiveOutlooks() throws -> [ConvectiveOutlookDTO] {
        let fetchDescriptor = FetchDescriptor<ConvectiveOutlook>()
        let outlooks: [ConvectiveOutlook] = try ctx.fetch(fetchDescriptor)
        let dto = outlooks.map { ConvectiveOutlookDTO(title: $0.title,
                                                     link: $0.link,
                                                     published: $0.published,
                                                     summary: $0.summary,
                                                     day: $0.day,
                                                     riskLevel: $0.riskLevel) }
        return dto
    }
}
