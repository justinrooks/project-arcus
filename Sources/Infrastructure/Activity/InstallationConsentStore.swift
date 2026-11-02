import ArcusCore
import CoreLocation
import Foundation
import OSLog
import Security
import Synchronization
import UIKit

/// Consent revisions and local evidence validity. AppStorage and Core Location remain the authorities.
actor InstallationConsentStore {
    static let shared = InstallationConsentStore()
    static let recordKey = "installationConsent.v3"

    struct Record: Codable, Equatable, Sendable {
        let installationId: String
        let revision: Int64
        let consent: DeviceConsentSnapshotV3
        var conflictRequiresRecovery: Bool?
    }

    enum Failure: Error, Equatable {
        case unavailable, identityMismatch, overflow, inconsistentAcknowledgment, consentConflictRequiresRecovery, rejected(Int)
    }

    nonisolated private let evidenceFence: LocationEvidenceFence
    private let accuracy: @Sendable () -> CLAccuracyAuthorization
    private let now: @Sendable () -> Date
    private let defaults: UserDefaults
    private let settings: @Sendable () -> DeviceConsentSnapshotV3
    private let markerExists: @Sendable () throws -> Bool
    private let createMarker: @Sendable () throws -> Void
    private let flush: (@Sendable () -> Bool)?
    private var restrictiveSubscription: Bool?
    private var latestOwnershipRequest: UUID?
    private var consentConflictDetected = false

    init(
        suiteName: String = "com.justinrooks.skyaware",
        settings: @escaping @Sendable () -> DeviceConsentSnapshotV3 = { InstallationConsentStore.readSettings() },
        markerExists: @escaping @Sendable () throws -> Bool = { try ConsentStateMarker.exists() },
        createMarker: @escaping @Sendable () throws -> Void = { try ConsentStateMarker.create() },
        flush: (@Sendable () -> Bool)? = nil,
        accuracy: @escaping @Sendable () -> CLAccuracyAuthorization = { CLLocationManager().accuracyAuthorization },
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.settings = settings
        self.markerExists = markerExists
        self.createMarker = createMarker
        self.flush = flush
        self.accuracy = accuracy
        self.now = now
        let fence = LocationEvidenceFence(suiteName: suiteName, flush: flush)
        self.evidenceFence = fence
        // Restore with fresh evidence even if permission changed and changed back while terminated.
        _ = try? fence.capturePreferenceIntent()
        _ = try? fence.reconcile(state: Self.evidenceState(settings(), accuracy()), at: now(), invalidate: true)
    }

    nonisolated var hasPendingPreferenceIntent: Bool { evidenceFence.hasPendingPreferenceIntent }

    nonisolated func savedLocationEvidenceCutoff() throws -> Date {
        try evidenceFence.read()
    }

    nonisolated func invalidateLocationEvidence(at date: Date) throws {
        var failure: (any Error)?
        do { try evidenceFence.capturePreferenceIntent() } catch { failure = error }
        do { _ = try evidenceFence.reconcile(state: Self.evidenceState(settings(), accuracy()), at: date, invalidate: true) }
        catch { failure = error }
        if let failure { throw failure }
    }

    func locationEvidenceCutoff(installationId: String) throws -> Date {
        let record = try current(installationId: installationId)
        return try evidenceFence.reconcile(state: Self.evidenceState(record.consent, accuracy()), at: now())
    }

    private nonisolated static func evidenceState(
        _ consent: DeviceConsentSnapshotV3, _ accuracy: CLAccuracyAuthorization
    ) -> String {
        "\(consent.locationSharingEnabled)|\(consent.locationAuthorization.rawValue)|\(accuracy.rawValue)"
    }

    func restrictSubscription() {
        restrictiveSubscription = !settings().isSubscribed
    }

    /// Captured synchronously from AppStorage writes, then delivered in user-intent order.
    func acceptSubscriptionIntent(installationId: String, enabled: Bool) throws {
        restrictiveSubscription = nil
        _ = try reconcile(installationId: installationId, subscriptionIntent: enabled)
    }

    func current(installationId: String) throws -> Record {
        try reconcile(installationId: installationId, subscriptionIntent: nil)
    }

    private func reconcile(installationId: String, subscriptionIntent: Bool?) throws -> Record {
        guard !consentConflictDetected else { throw Failure.consentConflictRequiresRecovery }
        guard UUID(uuidString: installationId) != nil else { throw Failure.identityMismatch }
        let raw = settings()
        var subscribed = raw.isSubscribed
        if var restriction = restrictiveSubscription {
            if !subscribed { restriction = true }
            if subscribed && restriction {
                restrictiveSubscription = nil
            } else {
                subscribed = false
                restrictiveSubscription = restriction
            }
        }
        let consent = DeviceConsentSnapshotV3(
            isSubscribed: subscriptionIntent ?? subscribed, mesoNotificationsEnabled: raw.mesoNotificationsEnabled,
            locationSharingEnabled: raw.locationSharingEnabled, locationAuthorization: raw.locationAuthorization
        )
        let previous: Record?
        if let data = defaults.data(forKey: Self.recordKey) {
            guard let decoded = try? JSONDecoder().decode(Record.self, from: data), decoded.revision > 0 else {
                throw Failure.unavailable
            }
            guard decoded.installationId == installationId else { throw Failure.identityMismatch }
            guard decoded.conflictRequiresRecovery != true else {
                consentConflictDetected = true
                throw Failure.consentConflictRequiresRecovery
            }
            previous = decoded
        } else {
            guard defaults.object(forKey: Self.recordKey) == nil, try !markerExists() else { throw Failure.unavailable }
            previous = nil
        }
        if let previous, previous.consent == consent {
            guard flush?() ?? defaults.synchronize() else { throw Failure.unavailable }
            try createMarker()
            return previous
        }
        guard previous?.revision != Int64.max else { throw Failure.overflow }
        let record = Record(installationId: installationId, revision: (previous?.revision ?? 0) + 1, consent: consent)
        try persist(record)
        // Written before any v3 handoff, including requests whose acknowledgment is lost.
        try createMarker()
        return record
    }

    private func persist(_ record: Record) throws {
        let data = try JSONEncoder().encode(record)
        defaults.set(data, forKey: Self.recordKey)
        guard flush?() ?? defaults.synchronize(), defaults.data(forKey: Self.recordKey) == data else {
            throw Failure.unavailable
        }
    }

    private func recordConsentConflict(installationId: String) throws {
        // Latch before persistence: even a failed flush must block this process.
        consentConflictDetected = true
        Logger.locationPushUploader.error("V3 consent conflict status=409; automatic device sync suspended pending explicit recovery")
        guard let data = defaults.data(forKey: Self.recordKey),
              var record = try? JSONDecoder().decode(Record.self, from: data),
              record.installationId == installationId, record.revision > 0 else {
            throw Failure.unavailable
        }
        record.conflictRequiresRecovery = true
        try persist(record)
    }

    /// Every admitted writer reconciles settings, including OS changes on foreground/background.
    /// Concurrent sends may overlap; matching durable revisions let Signal order them safely.
    func synchronize(installationId: String, baseURL: URL, http: HTTPClient, credential: String,
                     token: String? = nil,
                     checking: @escaping @Sendable () async throws -> String? = { nil }) async throws {
        let osVersion = await UIDevice.current.systemVersion
        while true {
            try Task.checkCancellation()
            let preparedToken = try await checking()
            let record = try current(installationId: installationId)
            let preferenceIntent = evidenceFence.pendingPreferenceIntent
            let currentToken = preparedToken ?? token ?? defaults.string(forKey: RemoteNotificationRegistrar.apnsDeviceTokenKey)
            let trimmedToken = currentToken?.trimmingCharacters(in: .whitespacesAndNewlines)
            let payload = try DevicePreferencesV3Payload(
                installationId: installationId, consentRevision: record.revision, consent: record.consent,
                apnsDeviceToken: trimmedToken?.isEmpty == false ? trimmedToken : nil,
                apnsEnvironment: Self.environment, platform: "iOS", osVersion: osVersion,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
            )
            let url = ArcusSignalConfiguration.url(from: baseURL, path: ArcusSignalConfiguration.devicePreferencesPath)!
            let ownershipRequest = UUID()
            latestOwnershipRequest = ownershipRequest
            let response = try await http.post(url, headers: [
                "Authorization": "Bearer \(credential)", "Content-Type": "application/json",
                "Accept": "application/json", "User-Agent": HTTPRequestHeaders.userAgent()
            ], body: JSONEncoder().encode(payload))
            if response.status == 409 {
                try recordConsentConflict(installationId: installationId)
                throw Failure.consentConflictRequiresRecovery
            }
            guard response.status == 200 else { throw Failure.rejected(response.status) }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let data = response.data,
                  let ack = try? decoder.decode(DevicePreferencesV3AcceptedResponse.self, from: data) else {
                throw Failure.inconsistentAcknowledgment
            }
            let latest = try current(installationId: installationId)
            guard ack.acceptedConsentRevision <= latest.revision else { throw Failure.inconsistentAcknowledgment }
            if latest.revision != record.revision { continue }
            guard ack.status != .stale, ack.acceptedConsentRevision == latest.revision else {
                throw Failure.inconsistentAcknowledgment
            }
            guard latestOwnershipRequest == ownershipRequest else { return }
            if let preferenceIntent { try? evidenceFence.acknowledgePreferenceIntent(preferenceIntent) }
            defaults.set(ack.serverOwnsMesoNotificationDelivery, forKey: HTTPDevicePreferenceSyncUploader.ownershipDefaultsKey)
            return
        }
    }

    nonisolated static var environment: DevicePreferencesV3Payload.APNsEnvironment {
        #if DEBUG
        .sandbox
        #else
        .prod
        #endif
    }

    nonisolated static func readSettings() -> DeviceConsentSnapshotV3 {
        let defaults = UserDefaults(suiteName: "com.justinrooks.skyaware")
        let authorization: DeviceConsentSnapshotV3.LocationAuthorization
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways: authorization = .always
        case .authorizedWhenInUse: authorization = .whenInUse
        case .denied: authorization = .denied
        case .restricted: authorization = .restricted
        case .notDetermined: authorization = .notDetermined
        @unknown default: authorization = .unknown
        }
        return DeviceConsentSnapshotV3(
            isSubscribed: defaults?.object(forKey: "serverNotificationEnabled") as? Bool ?? true,
            mesoNotificationsEnabled: defaults?.object(forKey: "mesoNotificationEnabled") as? Bool ?? true,
            locationSharingEnabled: defaults?.object(forKey: "sendL8ntoSignal") as? Bool ?? true,
            locationAuthorization: authorization
        )
    }
}

/// A primitive local marker, separate from the wire consent revision and location queue encoding.
/// One lock orders synchronous UI captures against actor reconciliation and disk reads.
private struct LocationEvidenceFence: Sendable {
    private static let lock = Mutex<Void>(())
    private static let key = "locationEvidenceFence.v1"
    private static let preferenceKey = "pendingDevicePreferenceIntent.v1"
    let suiteName: String
    let flush: (@Sendable () -> Bool)?

    var hasPendingPreferenceIntent: Bool {
        Self.lock.withLock { _ in
            (UserDefaults(suiteName: suiteName) ?? .standard).object(forKey: Self.preferenceKey) != nil
        }
    }

    var pendingPreferenceIntent: String? {
        Self.lock.withLock { _ in
            (UserDefaults(suiteName: suiteName) ?? .standard).string(forKey: Self.preferenceKey)
        }
    }

    func capturePreferenceIntent() throws {
        try Self.lock.withLock { _ in
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.set(UUID().uuidString, forKey: Self.preferenceKey)
            guard flush?() ?? defaults.synchronize() else { throw InstallationConsentStore.Failure.unavailable }
        }
    }

    func acknowledgePreferenceIntent(_ token: String) throws {
        try Self.lock.withLock { _ in
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            guard defaults.string(forKey: Self.preferenceKey) == token else { return }
            defaults.removeObject(forKey: Self.preferenceKey)
            guard flush?() ?? defaults.synchronize() else { throw InstallationConsentStore.Failure.unavailable }
        }
    }

    func read() throws -> Date {
        try Self.lock.withLock { _ in
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            guard let value = defaults.dictionary(forKey: Self.key),
                  let cutoff = value["cutoff"] as? Double, cutoff.isFinite,
                  value["state"] is String, flush?() ?? true else {
                throw InstallationConsentStore.Failure.unavailable
            }
            return Date(timeIntervalSince1970: cutoff)
        }
    }

    /// Explicit captures and state reconciliation share one monotonic cutoff.
    func reconcile(state: String, at date: Date, invalidate: Bool = false) throws -> Date {
        try Self.lock.withLock { _ in
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            let old = defaults.dictionary(forKey: Self.key)
            if defaults.object(forKey: Self.key) != nil {
                guard let old, let cutoff = old["cutoff"] as? Double, cutoff.isFinite,
                      old["state"] is String else { throw InstallationConsentStore.Failure.unavailable }
            }
            guard date.timeIntervalSince1970.isFinite else { throw InstallationConsentStore.Failure.unavailable }
            let changed = invalidate || (old?["state"] as? String) != state
            let previous = old?["cutoff"] as? Double
            let cutoff = changed || previous == nil
                ? max(previous ?? date.timeIntervalSince1970, date.timeIntervalSince1970)
                : (previous ?? date.timeIntervalSince1970)
            // Unchanged reads follow current()'s domain flush; only mutations require another disk write.
            if !changed, let previous {
                guard flush?() ?? true else { throw InstallationConsentStore.Failure.unavailable }
                return Date(timeIntervalSince1970: previous)
            }
            defaults.set(UUID().uuidString, forKey: Self.preferenceKey)
            let value: [String: Any] = ["cutoff": cutoff, "state": state]
            defaults.set(value, forKey: Self.key)
            guard flush?() ?? defaults.synchronize(),
                  defaults.dictionary(forKey: Self.key)?["cutoff"] as? Double == cutoff,
                  defaults.dictionary(forKey: Self.key)?["state"] as? String == state else {
                throw InstallationConsentStore.Failure.unavailable
            }
            return Date(timeIntervalSince1970: cutoff)
        }
    }
}

private enum ConsentStateMarker {
    static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: InstallationIdentityStore.keychainService,
         kSecAttrAccount as String: "installationConsentCreated.v3"]
    }

    static func exists() throws -> Bool {
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw InstallationConsentStore.Failure.unavailable
        }
        return status == errSecSuccess
    }

    static func create() throws {
        var addition = query
        addition[kSecValueData as String] = Data([1])
        addition[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(addition as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw InstallationConsentStore.Failure.unavailable
        }
    }
}
