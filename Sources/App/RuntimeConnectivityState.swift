//
//  RuntimeConnectivityState.swift
//  SkyAware
//
//  Created by Codex on 4/17/26.
//

import Foundation
import Network
import Observation

enum GeneralPathAvailability: Equatable, Sendable {
    case unknown
    case available
    case unavailable
}

enum ArcusSignalAvailability: Equatable, Sendable {
    case unknown
    case reachable
    case unavailable
}

protocol NetworkPathMonitoring: AnyObject {
    func setUpdateHandler(_ handler: @escaping @Sendable (Bool) -> Void)
    func start(queue: DispatchQueue)
    func cancel()
}

final class SystemNetworkPathMonitor: NetworkPathMonitoring {
    private let monitor: NWPathMonitor

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
    }

    func setUpdateHandler(_ handler: @escaping @Sendable (Bool) -> Void) {
        monitor.pathUpdateHandler = { path in
            handler(path.status == .satisfied)
        }
    }

    func start(queue: DispatchQueue) {
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
    }
}

protocol ArcusSignalReachabilityReporting: Sendable {
    func markReachable() async
    func markUnavailable() async
}

struct NoOpArcusSignalReachabilityReporter: ArcusSignalReachabilityReporting {
    func markReachable() async {}
    func markUnavailable() async {}
}

actor ArcusSignalReachabilityTracker: ArcusSignalReachabilityReporting {
    private let onAvailabilityChange: @Sendable (ArcusSignalAvailability) async -> Void

    init(
        onAvailabilityChange: @escaping @Sendable (ArcusSignalAvailability) async -> Void
    ) {
        self.onAvailabilityChange = onAvailabilityChange
    }

    func markReachable() async {
        await onAvailabilityChange(.reachable)
    }

    func markUnavailable() async {
        await onAvailabilityChange(.unavailable)
    }
}

@MainActor
@Observable
final class RuntimeConnectivityState {
    @ObservationIgnored
    private let pathMonitorFactory: () -> any NetworkPathMonitoring
    @ObservationIgnored
    private let monitorQueue: DispatchQueue
    @ObservationIgnored
    private var pathMonitor: (any NetworkPathMonitoring)?
    @ObservationIgnored
    private var isMonitoring = false

    private(set) var generalPathAvailability: GeneralPathAvailability = .unknown
    private(set) var arcusSignalAvailability: ArcusSignalAvailability = .unknown

    var isOffline: Bool {
        generalPathAvailability == .unavailable ||
        arcusSignalAvailability == .unavailable
    }

    init(
        pathMonitorFactory: @escaping () -> any NetworkPathMonitoring = { SystemNetworkPathMonitor() },
        monitorQueue: DispatchQueue = DispatchQueue(label: "com.skyaware.runtime-connectivity")
    ) {
        self.pathMonitorFactory = pathMonitorFactory
        self.monitorQueue = monitorQueue
    }

    func startMonitoringIfNeeded() {
        guard isMonitoring == false else { return }

        let monitor = pathMonitorFactory()
        monitor.setUpdateHandler { [weak self] isSatisfied in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.updateGeneralPathAvailability(isSatisfied: isSatisfied)
            }
        }
        monitor.start(queue: monitorQueue)

        pathMonitor = monitor
        isMonitoring = true
    }

    func updateGeneralPathAvailability(isSatisfied: Bool) {
        let nextValue: GeneralPathAvailability = isSatisfied ? .available : .unavailable
        guard generalPathAvailability != nextValue else { return }
        generalPathAvailability = nextValue
    }

    func updateArcusSignalAvailability(_ availability: ArcusSignalAvailability) {
        guard arcusSignalAvailability != availability else { return }
        arcusSignalAvailability = availability
    }
}

extension RuntimeConnectivityState {
    @MainActor
    static var preview: RuntimeConnectivityState {
        let state = RuntimeConnectivityState(pathMonitorFactory: { PreviewNetworkPathMonitor() })
        state.updateGeneralPathAvailability(isSatisfied: true)
        state.updateArcusSignalAvailability(.reachable)
        return state
    }
}

private final class PreviewNetworkPathMonitor: NetworkPathMonitoring {
    func setUpdateHandler(_ handler: @escaping @Sendable (Bool) -> Void) {}
    func start(queue: DispatchQueue) {}
    func cancel() {}
}
