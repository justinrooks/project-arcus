//
//  CadencePolicy.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/25/25.
//

import Foundation
import OSLog

enum Cadence: Sendable, Equatable {
    case short
    case normal
    case long

    var label: String {
        switch self {
        case .short:
            "short(20m)"
        case .normal:
            "normal(40m)"
        case .long:
            "long(60m)"
        }
    }

    var minutes: Int {
        switch self {
        case .short:
            20
        case .normal:
            40
        case .long:
            60
        }
    }
}

struct CadenceResult: Sendable, Equatable {
    var cadence: Cadence
    var reason: String
}

struct CadenceContext: Sendable {
    let categorical: StormRiskLevel
    let inMeso: Bool
    let inAlert: Bool
}

struct CadencePolicy: Sendable {
    private let logger = Logger.backgroundCadencePolicy
    
    /// Decides the cadence based on evaluation of context. Rules are processed top to
    /// bottom, and short circuit for meso/watch, categorical
    /// - Parameter ctx: cadence context
    /// - Returns: a cadence result
    func decide(for ctx: CadenceContext) -> CadenceResult {
        logger.debug("Deciding cadence from context")
        // Check in meso or watch return short and short circuit.
        if ctx.inAlert || ctx.inMeso {
            let sources = [ctx.inAlert ? "watch" : nil, ctx.inMeso ? "meso" : nil].compactMap { $0 }.joined(separator: ",")
            let r = CadenceResult(cadence: .short, reason: "gate=\(sources)")
            logger.notice("cadence=\(r.cadence.label, privacy: .public) reason=\(r.reason, privacy: .public)")
            return r
        }

        logger.debug("Checking categorical risk")
        switch ctx.categorical {
        case .allClear:
            let r = CadenceResult(cadence: .long, reason: "gate=categorical: \(ctx.categorical.abbreviation)")
            logger.notice("cadence=\(r.cadence.label, privacy: .public) reason=\(r.reason, privacy: .public)")
            return r
        case .thunderstorm:
            let r = CadenceResult(cadence: .normal, reason: "gate=categorical: \(ctx.categorical.abbreviation)")
            logger.notice("cadence=\(r.cadence.label, privacy: .public) reason=\(r.reason, privacy: .public)")
            return r
        case .marginal, .slight, .enhanced, .moderate, .high:
            let r = CadenceResult(cadence: .short, reason: "gate=categorical: \(ctx.categorical.abbreviation)")
            logger.notice("cadence=\(r.cadence.label, privacy: .public) reason=\(r.reason, privacy: .public)")
            return r
        }
    }
}
