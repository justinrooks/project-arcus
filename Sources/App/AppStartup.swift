import Observation
import OSLog
import UIKit

/// Owns the one transition from unavailable storage to a complete dependency graph.
@Observable
@MainActor
final class AppStartup {
    enum Status: Equatable {
        case waitingForProtectedData
        case unavailable
        case ready
    }

    private(set) var dependencies: Dependencies?
    private(set) var status: Status = .unavailable
    private(set) var failureDiagnostic: String?
    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var pendingNotificationOpen: HomeRemoteAlertContext?
    @ObservationIgnored private(set) var hasPresentedHome = false
    private let makeDependencies: () throws -> Dependencies
    private let protectedDataAvailable: () -> Bool
    private let onReady: (Dependencies) -> Void

    init(
        makeDependencies: @escaping () throws -> Dependencies,
        protectedDataAvailable: @escaping () -> Bool = { UIApplication.shared.isProtectedDataAvailable },
        onReady: @escaping (Dependencies) -> Void = { _ in }
    ) {
        self.makeDependencies = makeDependencies
        self.protectedDataAvailable = protectedDataAvailable
        self.onReady = onReady
    }

    @discardableResult
    func retry() -> Dependencies? {
        guard dependencies == nil, !isStarting else { return dependencies }
        // Construction is synchronous on the main actor, with no suspension between
        // checking readiness and installing the graph. Reentrant callbacks also join it.
        isStarting = true
        defer { isStarting = false }
        do {
            let dependencies = try makeDependencies()
            self.dependencies = dependencies
            onReady(dependencies)
            status = .ready
            failureDiagnostic = nil
            Logger.appMain.notice("Startup ready; persistence-dependent services installed")
        } catch {
            let isProtectedDataAvailable = protectedDataAvailable()
            status = isProtectedDataAvailable ? .unavailable : .waitingForProtectedData
            let failure = error as NSError
            // Error descriptions/userInfo may contain paths or private payloads. Keep only
            // domain/code evidence and the protection signal; locking alone is not the cause.
            var diagnostic = "store-open-failed domain=\(failure.domain) code=\(failure.code) protectedDataAvailable=\(isProtectedDataAvailable)"
            if let underlying = failure.userInfo[NSUnderlyingErrorKey] as? NSError {
                diagnostic += " underlyingDomain=\(underlying.domain) underlyingCode=\(underlying.code)"
            }
            failureDiagnostic = diagnostic
            Logger.appMain.error("Startup deferred: \(diagnostic, privacy: .public)")
        }
        return dependencies
    }

    func deferNotificationOpen(_ context: HomeRemoteAlertContext) {
        // Retain only the latest explicit navigation intent while storage is unavailable.
        pendingNotificationOpen = context
    }

    func markHomePresented() {
        guard dependencies != nil else { return }
        hasPresentedHome = true
    }

    func takePendingNotificationOpen() -> HomeRemoteAlertContext? {
        guard hasPresentedHome else { return nil }
        defer { pendingNotificationOpen = nil }
        return pendingNotificationOpen
    }
}
