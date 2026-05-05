import Foundation

enum WidgetSnapshotStoreLoadResult: Equatable, Sendable {
    case snapshot(WidgetSnapshot)
    case missing
    case corrupt
}

struct WidgetSnapshotStore {
    static let defaultAppGroupIdentifier = "group.com.skyaware.app"

    private let fileManager: FileManager
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

        self.fileManager = fileManager
        self.directoryURL = containerURL
        self.fileName = fileName
    }

    init(
        fileManager: FileManager = .default,
        directoryURL: URL,
        fileName: String = "widget-snapshot.json"
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL
        self.fileName = fileName
    }

    func write(_ snapshot: WidgetSnapshot) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: snapshotURL, options: [.atomic])
    }

    func load() -> WidgetSnapshotStoreLoadResult {
        guard fileManager.fileExists(atPath: snapshotURL.path) else {
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
