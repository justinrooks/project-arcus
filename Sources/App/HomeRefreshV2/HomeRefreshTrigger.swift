//
//  HomeRefreshTrigger.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

enum HomeRefreshTrigger: String, Sendable, Equatable {
    case bootstrap
    case foregroundPrime
    case foregroundActivate
    case manualRefresh
    case sessionTick
    case foregroundLocationChange
    case backgroundRefresh
    case backgroundLocationChange
    case remoteHotAlertReceived
    case remoteHotAlertOpened
}

struct HomeRemoteAlertContext: Sendable, Equatable {
    let alertID: String
    let revisionSent: Date?

    init(alertID: String, revisionSent: Date? = nil) {
        self.alertID = alertID
        self.revisionSent = revisionSent
    }
}

struct HomeIngestionRequest: Sendable, Equatable {
    let trigger: HomeRefreshTrigger
    let locationContext: LocationContext?
    let remoteAlertContext: HomeRemoteAlertContext?

    init(
        trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) {
        self.trigger = trigger
        self.locationContext = locationContext
        self.remoteAlertContext = remoteAlertContext
    }
}

struct HomeIngestionLane: OptionSet, Sendable {
    let rawValue: Int

    static let hotAlerts = HomeIngestionLane(rawValue: 1 << 0)
    static let slowProducts = HomeIngestionLane(rawValue: 1 << 1)
    static let weather = HomeIngestionLane(rawValue: 1 << 2)

    static let all: HomeIngestionLane = [.hotAlerts, .slowProducts, .weather]
}

struct HomeIngestionProvenance: OptionSet, Sendable {
    let rawValue: Int

    static let bootstrap = HomeIngestionProvenance(rawValue: 1 << 0)
    static let foregroundActivate = HomeIngestionProvenance(rawValue: 1 << 1)
    static let manualRefresh = HomeIngestionProvenance(rawValue: 1 << 2)
    static let sessionTick = HomeIngestionProvenance(rawValue: 1 << 3)
    static let locationChange = HomeIngestionProvenance(rawValue: 1 << 4)
    static let background = HomeIngestionProvenance(rawValue: 1 << 5)
    static let remoteHotAlertReceived = HomeIngestionProvenance(rawValue: 1 << 6)
    static let remoteHotAlertOpened = HomeIngestionProvenance(rawValue: 1 << 7)
}

enum HomeIngestionLocationRequest: Sendable, Equatable {
    case currentPrepared
    case prepare(requiresFreshLocation: Bool, showsAuthorizationPrompt: Bool)
    case explicit(LocationContext)

    func merged(with other: Self) -> Self {
        if strength == other.strength {
            return other
        }
        return strength > other.strength ? self : other
    }

    func satisfies(_ other: Self) -> Bool {
        switch (self, other) {
        case (.explicit(let lhs), .explicit(let rhs)):
            return lhs == rhs
        case (.explicit, .currentPrepared), (.explicit, .prepare):
            return true
        case (.prepare(let lhsFresh, let lhsPrompt), .prepare(let rhsFresh, let rhsPrompt)):
            let satisfiesFresh = lhsFresh || !rhsFresh
            let satisfiesPrompt = lhsPrompt || !rhsPrompt
            return satisfiesFresh && satisfiesPrompt
        case (.prepare, .currentPrepared):
            return true
        case (.currentPrepared, .currentPrepared):
            return true
        default:
            return false
        }
    }

    private var strength: Int {
        switch self {
        case .currentPrepared:
            return 0
        case .prepare(false, false):
            return 1
        case .prepare(true, false):
            return 2
        case .prepare(false, true):
            return 3
        case .prepare(true, true):
            return 4
        case .explicit:
            return 5
        }
    }
}

struct HomeIngestionPlan: Sendable, Equatable {
    var lanes: HomeIngestionLane
    var forcedLanes: HomeIngestionLane
    var locationRequest: HomeIngestionLocationRequest
    var provenance: HomeIngestionProvenance
    var remoteAlertContext: HomeRemoteAlertContext?
    var isLocationBearing: Bool

    init(request: HomeIngestionRequest) {
        switch request.trigger {
        case .bootstrap:
            lanes = .all
            forcedLanes = .all
            locationRequest = .prepare(requiresFreshLocation: true, showsAuthorizationPrompt: true)
            provenance = .bootstrap
            isLocationBearing = false
        case .foregroundPrime:
            lanes = [.hotAlerts]
            forcedLanes = [.hotAlerts]
            locationRequest = .prepare(requiresFreshLocation: true, showsAuthorizationPrompt: true)
            provenance = .foregroundActivate
            isLocationBearing = false
        case .foregroundActivate:
            lanes = .all
            forcedLanes = []
            locationRequest = .prepare(requiresFreshLocation: true, showsAuthorizationPrompt: true)
            provenance = .foregroundActivate
            isLocationBearing = false
        case .manualRefresh:
            lanes = .all
            forcedLanes = .all
            locationRequest = .prepare(requiresFreshLocation: true, showsAuthorizationPrompt: false)
            provenance = .manualRefresh
            isLocationBearing = false
        case .sessionTick:
            lanes = [.hotAlerts]
            forcedLanes = []
            locationRequest = .currentPrepared
            provenance = .sessionTick
            isLocationBearing = false
        case .foregroundLocationChange:
            lanes = .all
            forcedLanes = [.hotAlerts, .weather]
            locationRequest = .currentPrepared
            provenance = [.foregroundActivate, .locationChange]
            isLocationBearing = true
        case .backgroundRefresh:
            lanes = .all
            forcedLanes = [.hotAlerts]
            locationRequest = .prepare(requiresFreshLocation: true, showsAuthorizationPrompt: false)
            provenance = .background
            isLocationBearing = false
        case .backgroundLocationChange:
            lanes = .all
            forcedLanes = [.hotAlerts, .weather]
            locationRequest = .currentPrepared
            provenance = [.background, .locationChange]
            isLocationBearing = true
        case .remoteHotAlertReceived:
            lanes = [.hotAlerts]
            forcedLanes = [.hotAlerts]
            locationRequest = .currentPrepared
            provenance = [.background, .remoteHotAlertReceived]
            isLocationBearing = false
        case .remoteHotAlertOpened:
            lanes = [.hotAlerts]
            forcedLanes = [.hotAlerts]
            locationRequest = .currentPrepared
            provenance = [.foregroundActivate, .remoteHotAlertOpened]
            isLocationBearing = false
        }

        if let locationContext = request.locationContext {
            locationRequest = .explicit(locationContext)
            isLocationBearing = true
        }

        remoteAlertContext = request.remoteAlertContext
        lanes.insert(.hotAlerts)
        forcedLanes.formIntersection(lanes)
    }

    mutating func merge(with newer: Self) {
        lanes.formUnion(newer.lanes)
        lanes.insert(.hotAlerts)
        forcedLanes.formUnion(newer.forcedLanes)
        forcedLanes.formIntersection(lanes)
        provenance.formUnion(newer.provenance)

        if newer.isLocationBearing {
            locationRequest = newer.locationRequest
            isLocationBearing = true
        } else {
            locationRequest = locationRequest.merged(with: newer.locationRequest)
        }

        if let remoteAlertContext = newer.remoteAlertContext {
            self.remoteAlertContext = remoteAlertContext
        }
    }

    func merged(with newer: Self) -> Self {
        var plan = self
        plan.merge(with: newer)
        return plan
    }

    func satisfies(_ request: Self) -> Bool {
        covers(lanes, request.lanes) &&
        covers(forcedLanes, request.forcedLanes) &&
        locationRequest.satisfies(request.locationRequest)
    }

    private func covers(_ lhs: HomeIngestionLane, _ rhs: HomeIngestionLane) -> Bool {
        lhs.intersection(rhs) == rhs
    }
}

extension HomeRefreshTrigger {
    var logName: String { rawValue }
}

extension HomeIngestionLane {
    var logDescription: String {
        if isEmpty {
            return "none"
        }

        var values: [String] = []
        if contains(.hotAlerts) {
            values.append("hotAlerts")
        }
        if contains(.slowProducts) {
            values.append("slowProducts")
        }
        if contains(.weather) {
            values.append("weather")
        }
        return values.joined(separator: ",")
    }
}

extension HomeIngestionProvenance {
    var logDescription: String {
        if isEmpty {
            return "none"
        }

        var values: [String] = []
        if contains(.bootstrap) {
            values.append("bootstrap")
        }
        if contains(.foregroundActivate) {
            values.append("foregroundActivate")
        }
        if contains(.manualRefresh) {
            values.append("manualRefresh")
        }
        if contains(.sessionTick) {
            values.append("sessionTick")
        }
        if contains(.locationChange) {
            values.append("locationChange")
        }
        if contains(.background) {
            values.append("background")
        }
        if contains(.remoteHotAlertReceived) {
            values.append("remoteHotAlertReceived")
        }
        if contains(.remoteHotAlertOpened) {
            values.append("remoteHotAlertOpened")
        }
        return values.joined(separator: ",")
    }
}

extension HomeIngestionLocationRequest {
    var logDescription: String {
        switch self {
        case .currentPrepared:
            return "currentPrepared"
        case .prepare(let requiresFreshLocation, let showsAuthorizationPrompt):
            return "prepare(fresh=\(requiresFreshLocation),prompt=\(showsAuthorizationPrompt))"
        case .explicit:
            return "explicit"
        }
    }
}

extension HomeIngestionPlan {
    var logDescription: String {
        "lanes=\(lanes.logDescription) " +
        "forced=\(forcedLanes.logDescription) " +
        "locationRequest=\(locationRequest.logDescription) " +
        "provenance=\(provenance.logDescription) " +
        "remoteAlert=\(remoteAlertContext != nil)"
    }
}
