import Foundation
import OSLog
import Synchronization

/// One ephemeral current-observation trace; never a persisted location history.
enum LocationEnrichmentDiagnostics {
    private struct Trace: Sendable {
        let snapshot: LocationSnapshot
        let id = UUID()
        let started = ContinuousClock.now
        var source = "unknown"
        var networkSource = "unknown"
    }

    private static let current = Mutex<Trace?>(nil)
    @TaskLocal static var pointTrace: UUID?

    static func begin(_ snapshot: LocationSnapshot) {
        let trace = Trace(snapshot: snapshot)
        current.withLock { $0 = trace }
        record("accepted", token: trace.id)
    }

    static func token(coordinate: Coordinate2D, capturedAt: Date?) -> UUID? {
        current.withLock {
            guard let trace = $0, trace.snapshot.coordinates.latitude == coordinate.latitude,
                  trace.snapshot.coordinates.longitude == coordinate.longitude,
                  capturedAt == trace.snapshot.timestamp else { return nil }
            return trace.id
        }
    }

    static func token(h3: Int64?, capturedAt: Date) -> UUID? {
        current.withLock {
            guard let trace = $0, trace.snapshot.h3Cell == h3,
                  trace.snapshot.timestamp == capturedAt else { return nil }
            return trace.id
        }
    }

    static func shape(county: String?, forecast: String?, fire: String?) -> String {
        let present = [county, forecast, fire].filter {
            $0?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }.count
        return present == 3 ? "complete" : (present == 0 ? "h3_only" : "partial")
    }

    static func record(_ stage: String, token: UUID?, source: String? = nil,
                       networkSource: String? = nil, shape: String = "unknown") {
        guard let token else { return }
        let trace = current.withLock { value -> Trace? in
            guard var trace = value, trace.id == token else { return nil }
            if let source { trace.source = source }
            if let networkSource { trace.networkSource = networkSource }
            value = trace
            return trace
        }
        guard let trace else { return }
        let elapsed = (ContinuousClock.now - trace.started).components
        let milliseconds = Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
        Logger.locationProvider.info(
            "Enrichment trace=\(trace.id.uuidString, privacy: .public) stage=\(stage, privacy: .public) elapsed_ms=\(milliseconds, privacy: .public) source=\(trace.source, privacy: .public) network=\(trace.networkSource, privacy: .public) shape=\(shape, privacy: .public)"
        )
    }
}
