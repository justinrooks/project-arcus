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
    
    func insertConvectiveOutlooks(_ outlook:[Item]) async throws {
        _ = try outlook.map {
            guard let ol = ConvectiveOutlook(from: $0) else { throw OtherErrors.contextSaveError }
            ctx.insert(ol)
        }
        
        try ctx.save()
    }
    
    func create<T: PersistentModel>(todo: [T]) throws {
        _ = todo.map { ctx.insert($0) }
        try ctx.save()
    }
    
    func getAll<T: PersistentModel>() throws -> [T]? {
        let fetchDescriptor = FetchDescriptor<T>()
        return try? ctx.fetch(fetchDescriptor)
    }
    
    func fetchConvectiveOutlooks() throws -> [ConvectiveOutlookDTO] {
        let fetchDescriptor = FetchDescriptor<ConvectiveOutlook>()
        let outlooks: [ConvectiveOutlook] = try ctx.fetch(fetchDescriptor)
        let dto = outlooks.map { ConvectiveOutlookDTO(id: $0.id,
                                                     title: $0.title,
                                                     link: $0.link,
                                                     published: $0.published,
                                                     summary: $0.summary,
                                                     day: $0.day,
                                                     riskLevel: $0.riskLevel) }
        return dto
    }
}
