//
//  CadencePolicy.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/25/25.
//

import Foundation
import OSLog

enum CadenceAdjust { case tighten, loosen }

enum Cadence: Sendable, Equatable {
    case short(Int), normal(Int), long(Int)
    
    var label: String {
      switch self { case .short(let m): "short(\(m)m)"; case .normal(let m): "normal(\(m)m)"; case .long(let m): "long(\(m)m)" }
    }
}

extension Cadence {
    static let defaultShort = 20
    static let defaultNormal = 40
    static let defaultLong = 60
    
    func adjusted(_ a: CadenceAdjust) -> Cadence {
        switch (a, self) {
        case (.tighten, .long):   return .normal(Self.defaultNormal)
        case (.tighten, .normal): return .short(Self.defaultShort)
        case (.tighten, .short):  return .short(Self.defaultShort)
        case (.loosen,  .short):  return .normal(Self.defaultNormal)
        case (.loosen,  .normal): return .long(Self.defaultLong)
        case (.loosen,  .long):   return .long(Self.defaultLong)
        }
    }
    
    
    /// Convenience function to retrieve the minutes saved with the cadence
    /// - Returns: minutes as Int
    func getMinutes() -> Int {
        switch self {
        case .short(let m):  m
        case .normal(let m): m
        case .long(let m):   m
        }
    }
}

struct CadenceResult: Sendable, Equatable {
    var cadence: Cadence
    var reason: String
}

struct CadenceContext: Sendable {
    let now: Date
    let categorical: StormRiskLevel
    let recentlyChangedLocation: Bool
    let inMeso: Bool
    let inWatch: Bool
}

struct CadencePolicy: Sendable {
    private let logger = Logger.cadencePolicy
    
    /// Decides the cadence based on evaluation of context. Rules are processed top to
    /// bottom, and short circuit for meso/watch, categorical
    /// - Parameter ctx: cadence context
    /// - Returns: a cadence result
    func decide(for ctx: CadenceContext) -> CadenceResult {
        logger.debug("Deciding cadence from context")
        // Check in meso or watch return short and short circuit
        if ctx.inWatch || ctx.inMeso {
            let sources = [ctx.inWatch ? "watch" : nil, ctx.inMeso ? "meso" : nil].compactMap { $0 }.joined(separator: ",")
            let r = CadenceResult(cadence: .short(Cadence.defaultShort), reason: "gate=\(sources)")
            logger.notice("cadence=\(r.cadence.label, privacy: .public) reason=\(r.reason, privacy: .public)")
            return r
        }
        
        // Only going to check categorical storm risk, as its linked to severe.
        // Tornado, wind, hail don't happen without elevated categorical risk
        // This makes rule reading easier. No reason to add complexity when
        // not necessary.
        
        // check categorical evaluate level, short circuit return
        logger.debug("Checking categorical risk")
        var base: CadenceResult
        switch ctx.categorical {
        case .allClear, .thunderstorm, .marginal: // 60
            base = .init(
                cadence: .long(Cadence.defaultLong),
                reason: "gate=categorical: \(ctx.categorical.abbreviation)"
            )
        case .slight, .enhanced: // 40
            base = .init(
                cadence: .normal(Cadence.defaultNormal),
                reason: "gate=categorical: \(ctx.categorical.abbreviation)"
            )
        case .moderate, .high: // 20
            base = .init(
                cadence: .short(Cadence.defaultShort),
                reason: "gate=categorical: \(ctx.categorical.abbreviation)"
            )
        }
        
        // if we make it here, apply any nudges and then return
        
        if ctx.recentlyChangedLocation {
            let from = base.cadence
            let to = base.cadence.adjusted(.tighten)
            base.cadence = to
            base.reason = [base.reason, "nudge=move \(from.label)->\(to.label)"]
                .compactMap { $0 }.joined(separator: " ")
        }
        
        return base
    }
}
