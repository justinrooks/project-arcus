import CoreData
import Foundation
import OSLog
import SwiftData

enum SkyAwarePersistenceSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static let models: [any PersistentModel.Type] = [
        ConvectiveOutlook.self,
        MD.self,
        StormRisk.self,
        SevereRisk.self,
        BgRunSnapshot.self,
        Watch.self,
        FireRisk.self,
        HomeProjection.self
    ]
}

enum SkyAwarePersistenceMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [SkyAwarePersistenceSchema.self]
    static let stages: [MigrationStage] = []
}

@MainActor
enum SkyAwarePersistentStoreBootstrap {
    enum Mode: Equatable, Sendable {
        case persistent
        case transient
    }

    struct Result: Sendable {
        let container: ModelContainer
        let mode: Mode
    }

    typealias ContainerFactory = @MainActor (
        _ schema: Schema,
        _ configuration: ModelConfiguration,
        _ migrationPlan: (any SchemaMigrationPlan.Type)?
    ) throws -> ModelContainer

    static let storeName = "SkyAware_Data_v3"
    static let storeFileName = "SkyAware_Data_v3.store"
    static let quarantineDirectoryName = "IncompatibleStores"
    static let quarantineRetentionInterval: TimeInterval = 7 * 24 * 60 * 60
    static let maximumRetainedQuarantines = 1

    static func open(
        schema: Schema,
        configuration: ModelConfiguration,
        migrationPlan: (any SchemaMigrationPlan.Type)? = nil,
        isProtectedDataAvailable: Bool,
        fileManager: FileManager = .default,
        logger: Logger = .appMain,
        now: Date = .now,
        makeContainer: ContainerFactory? = nil
    ) throws -> Result {
        let factory = makeContainer ?? { schema, configuration, migrationPlan in
            try ModelContainer(
                for: schema,
                migrationPlan: migrationPlan,
                configurations: configuration
            )
        }

        do {
            // Core Data defaults to protection until first unlock, so a locked device can
            // still open this store. Let the store operation establish availability.
            let container = try factory(schema, configuration, migrationPlan)
            maintainQuarantines(
                for: configuration.url,
                fileManager: fileManager,
                logger: logger,
                now: now
            )
            return Result(container: container, mode: .persistent)
        } catch let initialError {
            let storeURL = configuration.url

            // Never interpret a lock/access failure (or an unknown open error) as corruption.
            guard isProtectedDataAvailable,
                  storeFiles(at: storeURL, fileManager: fileManager).isEmpty == false,
                  hasRecoveryEvidence(for: initialError, at: storeURL) else {
                logger.error(
                    "Persistent SwiftData unavailable; preserving cache and using transient storage. error=\(String(describing: initialError), privacy: .public)"
                )
                return try transientResult(
                    schema: schema,
                    migrationPlan: migrationPlan,
                    factory: factory
                )
            }

            let backupURL: URL
            do {
                backupURL = try quarantineStore(at: storeURL, fileManager: fileManager)
                logger.error(
                    "Quarantined unreadable SwiftData cache backup=\(backupURL.lastPathComponent, privacy: .public) error=\(String(describing: initialError), privacy: .public)"
                )
            } catch {
                logger.error(
                    "Could not quarantine unreadable SwiftData cache; using transient storage. openError=\(String(describing: initialError), privacy: .public) quarantineError=\(String(describing: error), privacy: .public)"
                )
                return try transientResult(
                    schema: schema,
                    migrationPlan: migrationPlan,
                    factory: factory
                )
            }

            do {
                let container = try factory(schema, configuration, migrationPlan)
                maintainQuarantines(
                    for: configuration.url,
                    retaining: backupURL,
                    fileManager: fileManager,
                    logger: logger,
                    now: now
                )
                logger.notice(
                    "Recovered persistent SwiftData cache"
                )
                return Result(container: container, mode: .persistent)
            } catch let retryError {
                logger.error(
                    "Persistent SwiftData recovery failed; using transient storage. initialError=\(String(describing: initialError), privacy: .public) retryError=\(String(describing: retryError), privacy: .public)"
                )
                return try transientResult(
                    schema: schema,
                    migrationPlan: migrationPlan,
                    factory: factory
                )
            }
        }
    }

    static func storeURL(applicationSupportDirectory: URL = .applicationSupportDirectory) -> URL {
        applicationSupportDirectory.appendingPathComponent(storeFileName, isDirectory: false)
    }

    private static func hasRecoveryEvidence(for error: any Error, at storeURL: URL) -> Bool {
        if isIncompatibleOrCorrupt(error as NSError) { return true }
        guard error as? SwiftDataError == .loadIssueModelContainer else { return false }

        // SwiftData can hide the underlying Core Data error. Read metadata without opening
        // a writable store to distinguish a corrupt file from unavailable storage.
        do {
            _ = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: [NSReadOnlyPersistentStoreOption: true]
            )
            return false
        } catch {
            return isIncompatibleOrCorrupt(error as NSError)
        }
    }

    private static func isIncompatibleOrCorrupt(_ error: NSError) -> Bool {
        // Prefer the underlying cause: a wrapper must not hide a permission or I/O failure.
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isIncompatibleOrCorrupt(underlying)
        }
        if error.domain == NSSQLiteErrorDomain {
            // SQLite primary result codes: SQLITE_CORRUPT and SQLITE_NOTADB.
            return [11, 26].contains(error.code & 0xff)
        }
        if error.domain == NSCocoaErrorDomain,
           let sqliteCode = error.userInfo[NSSQLiteErrorDomain] as? Int {
            return [11, 26].contains(sqliteCode & 0xff)
        }
        return error.domain == NSCocoaErrorDomain && [
            NSFileReadCorruptFileError,
            NSPersistentStoreIncompatibleVersionHashError,
            NSMigrationMissingSourceModelError
        ].contains(error.code)
    }

    private static func transientResult(
        schema: Schema,
        migrationPlan: (any SchemaMigrationPlan.Type)?,
        factory: ContainerFactory
    ) throws -> Result {
        let configuration = ModelConfiguration(
            "\(storeName)_Transient",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try factory(schema, configuration, migrationPlan)
        return Result(container: container, mode: .transient)
    }

    static func quarantineRootURL(for storeURL: URL) -> URL {
        storeURL.deletingLastPathComponent()
            .appendingPathComponent(quarantineDirectoryName, isDirectory: true)
    }

    private static func storeFiles(at storeURL: URL, fileManager: FileManager) -> [URL] {
        [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ].filter { fileManager.fileExists(atPath: $0.path) }
    }

    static func quarantineStore(
        at storeURL: URL,
        fileManager: FileManager,
        moveItem: ((URL, URL) throws -> Void)? = nil
    ) throws -> URL {
        let rootURL = quarantineRootURL(for: storeURL)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try excludeFromBackup(rootURL)

        let backupURL = rootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: false)
        do {
            try excludeFromBackup(backupURL)
        } catch {
            try? fileManager.removeItem(at: backupURL)
            throw error
        }

        let move = moveItem ?? { sourceURL, destinationURL in
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        }
        var movedFiles: [(source: URL, destination: URL)] = []
        do {
            for sourceURL in storeFiles(at: storeURL, fileManager: fileManager) {
                let destinationURL = backupURL.appendingPathComponent(sourceURL.lastPathComponent)
                try move(sourceURL, destinationURL)
                movedFiles.append((sourceURL, destinationURL))
            }
            return backupURL
        } catch let moveError {
            var rollbackErrors: [any Error] = []
            for movedFile in movedFiles.reversed() {
                do {
                    try move(movedFile.destination, movedFile.source)
                } catch {
                    rollbackErrors.append(error)
                }
            }
            guard rollbackErrors.isEmpty else {
                throw QuarantineError(
                    moveError: moveError,
                    rollbackErrors: rollbackErrors,
                    backupURL: backupURL
                )
            }
            try? fileManager.removeItem(at: backupURL)
            throw moveError
        }
    }

    private static func maintainQuarantines(
        for storeURL: URL,
        retaining retainedBackupURL: URL? = nil,
        fileManager: FileManager,
        logger: Logger,
        now: Date
    ) {
        do {
            try pruneQuarantines(
                for: storeURL,
                retaining: retainedBackupURL,
                fileManager: fileManager,
                now: now
            )
        } catch {
            logger.error(
                "Could not maintain quarantined SwiftData caches: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    static func pruneQuarantines(
        for storeURL: URL,
        retaining retainedBackupURL: URL? = nil,
        fileManager: FileManager,
        now: Date
    ) throws {
        let rootURL = quarantineRootURL(for: storeURL)
        guard fileManager.fileExists(atPath: rootURL.path) else { return }

        try excludeFromBackup(rootURL)
        let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey, .isDirectoryKey]
        let candidates = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ).compactMap { url -> (url: URL, modifiedAt: Date)? in
            let values = try url.resourceValues(forKeys: resourceKeys)
            guard values.isDirectory == true else { return nil }
            try excludeFromBackup(url)
            return (url, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.modifiedAt > $1.modifiedAt }

        var retainedCount = candidates.contains { $0.url == retainedBackupURL } ? 1 : 0
        for candidate in candidates {
            if candidate.url == retainedBackupURL {
                continue
            }

            let isExpired = now.timeIntervalSince(candidate.modifiedAt) > quarantineRetentionInterval
            if isExpired || retainedCount >= maximumRetainedQuarantines {
                try fileManager.removeItem(at: candidate.url)
            } else {
                retainedCount += 1
            }
        }
    }

    private static func excludeFromBackup(_ url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutableURL.setResourceValues(values)
    }
}

extension SkyAwarePersistentStoreBootstrap {
    struct QuarantineError: LocalizedError {
        let moveError: any Error
        let rollbackErrors: [any Error]
        let backupURL: URL

        var errorDescription: String? {
            "SwiftData cache quarantine failed and rollback was incomplete. Preserved files remain at " +
            "\(backupURL.lastPathComponent). Move error: \(moveError). " +
            "Rollback errors: \(rollbackErrors.map(String.init(describing:)).joined(separator: "; "))."
        }
    }
}
