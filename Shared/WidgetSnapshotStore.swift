import Foundation
import Synchronization

enum WidgetSnapshotStoreLoadResult: Equatable, Sendable {
    case snapshot(WidgetSnapshot)
    case missing
    case corrupt
}

struct WidgetSnapshotStore: Sendable {
    // The app has independent Home and remote coordinators writing the same file. The
    // extension only reads it; process-local fencing is sufficient because pending work
    // cannot survive app termination. Each destination keeps its fence across store copies.
    private final class PublicationState: Sendable {
        let lastOrder = Mutex<UInt64?>(nil)
    }
    private static let publicationStates = Mutex<[URL: PublicationState]>([:])

    static let defaultAppGroupIdentifier = "group.com.skyaware.app"

    private let directoryURL: URL
    private let fileName: String

    init(
        fileManager: FileManager = .default,
        appGroupIdentifier: String = WidgetSnapshotStore.defaultAppGroupIdentifier,
        fileName: String = "widget-snapshot.json"
    ) throws {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw StoreError.containerUnavailable(appGroupIdentifier)
        }

        self.directoryURL = containerURL
        self.fileName = fileName
    }

    init(
        fileManager: FileManager = .default,
        directoryURL: URL,
        fileName: String = "widget-snapshot.json"
    ) {
        _ = fileManager
        self.directoryURL = directoryURL
        self.fileName = fileName
    }

    @discardableResult
    func write(_ snapshot: WidgetSnapshot, publicationOrder: UInt64? = nil) throws -> Bool {
        let destination = snapshotURL.standardizedFileURL.resolvingSymlinksInPath()
        let state = Self.publicationStates.withLock { states in
            if let existing = states[destination] { return existing }
            let state = PublicationState()
            states[destination] = state
            return state
        }
        return try state.lastOrder.withLock { lastOrder in
            if let lastOrder, publicationOrder.map({ $0 < lastOrder }) ?? true { return false }
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: snapshotURL, options: [.atomic])
            lastOrder = publicationOrder
            return true
        }
    }

    func load() -> WidgetSnapshotStoreLoadResult {
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
            return .missing
        }

        do {
            let data = try Data(contentsOf: snapshotURL)
            let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
            return .snapshot(snapshot)
        } catch {
            return .corrupt
        }
    }

    private var snapshotURL: URL {
        directoryURL.appendingPathComponent(fileName, conformingTo: .json)
    }
}

extension WidgetSnapshotStore {
    enum StoreError: Error, Equatable {
        case containerUnavailable(String)
    }
}
