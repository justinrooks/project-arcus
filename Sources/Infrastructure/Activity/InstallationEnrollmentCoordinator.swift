import ArcusCore
import Foundation
import Security

// Errors deliberately contain neither request bodies nor credentials.
enum InstallationEnrollmentError: Error, Equatable {
    case persistenceUnavailable
    case invalidIdentity
    case invalidCredential
    case insecureEndpoint
    case rejected(Int)
    case invalidAcknowledgment
}

/// One authority shared by foreground, background, location and preference writers.
/// The Keychain record is written before enrollment and retains the same secret on retry.
actor InstallationEnrollmentCoordinator {
    static let shared = InstallationEnrollmentCoordinator()

    struct Record: Codable, Sendable {
        let installationId: String
        let credential: String
        var enrolledOrigin: String?
    }

    private let installationId: @Sendable () async throws -> String
    private let read: @Sendable () throws -> Record?
    private let write: @Sendable (Record) throws -> Void
    private let generate: @Sendable () throws -> String
    private let enrollmentWaiterDidJoin: @Sendable () -> Void
    private var inFlight: Task<Record, Error>?

    init(
        installationId: @escaping @Sendable () async throws -> String = {
            try await InstallationIdentityStore.shared.durableInstallationId()
        },
        read: @escaping @Sendable () throws -> Record? = { try InstallationCredentialKeychain.read() },
        write: @escaping @Sendable (Record) throws -> Void = { try InstallationCredentialKeychain.write($0) },
        generate: @escaping @Sendable () throws -> String = { try InstallationCredentialKeychain.generate() },
        enrollmentWaiterDidJoin: @escaping @Sendable () -> Void = {}
    ) {
        self.installationId = installationId
        self.read = read
        self.write = write
        self.generate = generate
        self.enrollmentWaiterDidJoin = enrollmentWaiterDidJoin
    }

    func credential(for requestedId: String, baseURL: URL, http: HTTPClient) async throws -> String {
        try Task.checkCancellation()
        guard baseURL.scheme?.lowercased() == "https", let host = baseURL.host,
              baseURL.user == nil, baseURL.password == nil else {
            throw InstallationEnrollmentError.insecureEndpoint
        }
        guard try await installationId() == requestedId else {
            throw InstallationEnrollmentError.invalidIdentity
        }
        let origin = "https://\(host.lowercased()):\(baseURL.port ?? 443)"
        let record: Record
        if let inFlight {
            enrollmentWaiterDidJoin()
            record = try await inFlight.value
        } else {
            // Shared enrollment survives cancellation of an individual waiter. Keep ownership
            // until the operation unwinds, so a second caller cannot start a competing claim.
            let task = Task { try await self.enroll(baseURL: baseURL, origin: origin, http: http) }
            inFlight = task
            defer { inFlight = nil }
            record = try await task.value
        }
        try Task.checkCancellation()
        guard record.installationId == requestedId, record.enrolledOrigin == origin else {
            throw InstallationEnrollmentError.invalidIdentity
        }
        return record.credential
    }

    private func enroll(baseURL: URL, origin: String, http: HTTPClient) async throws -> Record {
        let id = try await installationId()
        guard UUID(uuidString: id) != nil else { throw InstallationEnrollmentError.invalidIdentity }
        var record: Record
        if let existing = try read() {
            guard existing.installationId == id else { throw InstallationEnrollmentError.invalidIdentity }
            record = existing
        } else {
            record = Record(installationId: id, credential: try generate())
            try write(record)
        }
        // Validate persisted material before using it as a header, including after restart.
        guard record.credential.count == 43,
              record.credential.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else {
            throw InstallationEnrollmentError.invalidCredential
        }
        if let enrolledOrigin = record.enrolledOrigin {
            guard enrolledOrigin == origin else { throw InstallationEnrollmentError.invalidIdentity }
            return record
        }
        guard let url = ArcusSignalConfiguration.url(from: baseURL, path: ArcusSignalConfiguration.enrollmentPath) else {
            throw InstallationEnrollmentError.insecureEndpoint
        }
        try write(record)
        let body = try JSONEncoder().encode(InstallationEnrollmentRequest(installationId: id, credential: record.credential))
        let response = try await http.post(url, headers: [
            "User-Agent": HTTPRequestHeaders.userAgent(),
            "Accept": "application/json",
            "Content-Type": "application/json"
        ], body: body)
        guard response.status == 200 else { throw InstallationEnrollmentError.rejected(response.status) }
        guard let data = response.data,
              let accepted = try? JSONDecoder().decode(InstallationEnrollmentAcceptedResponse.self, from: data),
              accepted.status == "accepted" else { throw InstallationEnrollmentError.invalidAcknowledgment }
        record.enrolledOrigin = origin
        try write(record)
        return record
    }
}

enum InstallationCredentialKeychain {
    static let account = "installationCredential.v2"

    static func query(service: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func read(service: String = InstallationIdentityStore.keychainService) throws -> InstallationEnrollmentCoordinator.Record? {
        var query = query(service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            var marker = self.query(service: service)
            marker[kSecAttrAccount as String] = "installationCredentialCreated.v2"
            let markerStatus = SecItemCopyMatching(marker as CFDictionary, nil)
            guard markerStatus == errSecItemNotFound else {
                throw InstallationEnrollmentError.persistenceUnavailable
            }
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw InstallationEnrollmentError.persistenceUnavailable
        }
        // Corrupt or inaccessible data must never be treated as a missing credential.
        guard let record = try? JSONDecoder().decode(InstallationEnrollmentCoordinator.Record.self, from: data) else {
            throw InstallationEnrollmentError.persistenceUnavailable
        }
        return record
    }

    static func write(_ record: InstallationEnrollmentCoordinator.Record,
                      service: String = InstallationIdentityStore.keychainService) throws {
        let query = query(service: service)
        let data = try JSONEncoder().encode(record)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status != errSecSuccess {
            guard status == errSecItemNotFound else { throw InstallationEnrollmentError.persistenceUnavailable }
            var addition = query
            addition[kSecValueData as String] = data
            addition[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(addition as CFDictionary, nil) == errSecSuccess else {
                throw InstallationEnrollmentError.persistenceUnavailable
            }
        }
        // A separate durable marker distinguishes credential loss from an unclaimed legacy ID.
        // Both writes must succeed before any enrollment request can leave the process.
        var marker = query
        marker[kSecAttrAccount as String] = "installationCredentialCreated.v2"
        marker[kSecValueData as String] = Data(record.installationId.utf8)
        marker[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let markerStatus = SecItemAdd(marker as CFDictionary, nil)
        guard markerStatus == errSecSuccess || markerStatus == errSecDuplicateItem else {
            throw InstallationEnrollmentError.persistenceUnavailable
        }
    }

    static func generate() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw InstallationEnrollmentError.persistenceUnavailable
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
