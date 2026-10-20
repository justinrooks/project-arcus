import Foundation

@MainActor
enum AppReviewRequestSchedule {
    static let delay = Duration.seconds(2)

    typealias Sleeper = @MainActor (Duration) async throws -> Void

    static func makeTask(
        appVersion: String,
        ledger: AppReviewRequestLedger,
        sleeper: @escaping Sleeper = { try await Task.sleep(for: $0) },
        isStillEligible: @escaping @MainActor () -> Bool,
        requestReview: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            do {
                try await sleeper(delay)
            } catch {
                return
            }
            guard !Task.isCancelled, isStillEligible() else { return }

            ledger.recordAttempted(appVersion: appVersion)
            requestReview()
        }
    }
}
