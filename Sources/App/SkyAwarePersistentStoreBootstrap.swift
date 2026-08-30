import Foundation
import OSLog
import SwiftData

@MainActor
enum SkyAwarePersistentStoreBootstrap {
    static let currentGeneration = 2
    static let generationKey = "skyAwarePersistentStoreGeneration"
    static let quarantineDirectoryName = "IncompatibleStores"
    static let quarantineRetentionInterval: TimeInterval = 7 * 24 * 60 * 60
    static let maximumRetainedQuarantines = 1

    static func open(
        schema: Schema,
        configuration: ModelConfiguration,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        logger: Logger = .appMain,
        now: Date = .now
    ) throws -> ModelContainer {
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            defaults.set(currentGeneration, forKey: generationKey)
            maintainQuarantines(
                for: configuration.url,
                fileManager: fileManager,
                logger: logger,
                now: now
            )
            return container
        } catch let initialError {
            let recordedGeneration = defaults.integer(forKey: generationKey)
            let storeURL = configuration.url
            guard recordedGeneration < currentGeneration,
                  storeFiles(at: storeURL, fileManager: fileManager).isEmpty == false else {
                throw initialError
            }

            let backupURL = try quarantineStore(at: storeURL, fileManager: fileManager)
            logger.error(
                "Quarantined incompatible SwiftData cache generation=\(recordedGeneration, privacy: .public) backup=\(backupURL.lastPathComponent, privacy: .public)"
            )

            do {
                let container = try ModelContainer(for: schema, configurations: configuration)
                defaults.set(currentGeneration, forKey: generationKey)
                maintainQuarantines(
                    for: configuration.url,
                    retaining: backupURL,
                    fileManager: fileManager,
                    logger: logger,
                    now: now
                )
                logger.notice(
                    "Recovered SwiftData cache with generation=\(currentGeneration, privacy: .public)"
                )
                return container
            } catch let retryError {
                throw RecoveryError(
                    initialError: initialError,
                    retryError: retryError,
                    backupURL: backupURL
                )
            }
        }
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
    struct RecoveryError: LocalizedError {
        let initialError: any Error
        let retryError: any Error
        let backupURL: URL

        var errorDescription: String? {
            "SwiftData cache recovery failed after preserving the incompatible store at " +
            "\(backupURL.lastPathComponent). Initial error: \(initialError). Retry error: \(retryError)."
        }
    }

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
