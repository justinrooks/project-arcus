import Foundation
import SwiftData

@MainActor
enum TestStore {
    private static var containers: [String: ModelContainer] = [:]

    static func container(for models: [any PersistentModel.Type]) throws -> ModelContainer {
        let key = models.map { String(describing: $0) }.sorted().joined(separator: "+")
        if let existing = containers[key] {
            return existing
        }
        let schema = Schema(models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        containers[key] = container
        return container
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
