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
    
    init(_ models: any PersistentModel.Type ...) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(models)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Error creating preview model container")
        }
    }
    
    func addExamples(_ examples: [any PersistentModel]) {
        Task { @MainActor in
            examples.forEach { ex in
                container.mainContext.insert(ex)
            }
        }
    }
}
