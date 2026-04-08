import Foundation
import SwiftData

@MainActor
enum TestStore {
    static func container(for models: [any PersistentModel.Type]) throws -> ModelContainer {
        let schema = Schema(models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // Return a fresh container per test call to prevent cross-suite state bleed
        // when Swift Testing executes suites in parallel.
        return try ModelContainer(for: schema, configurations: config)
    }

    static func reset<T: PersistentModel>(_ type: T.Type, in container: ModelContainer) throws {
        let context = ModelContext(container)
        let items = try context.fetch(FetchDescriptor<T>())
        for item in items {
            context.delete(item)
        }
        if items.isEmpty == false {
            try context.save()
        }
    }
}
