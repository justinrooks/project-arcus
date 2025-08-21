//
//  CadencePlanner.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import Foundation

struct CadencePlanner {

    /// Main entry: compute plans for both feeds.
    func plan(for state: DerivedState, now: Date = .now) -> [CheckPlan] {
        let (outInt, outReason) = outlookInterval(state)
        let (mdInt,  mdReason)  = mdInterval(state)

        return [
            CheckPlan(feed: .outlookDay1,
                      interval: outInt,
                      earliestBeginDate: now.addingTimeInterval(outInt + jitter()),
                      reason: outReason),
            CheckPlan(feed: .meso,
                      interval: mdInt,
                      earliestBeginDate: now.addingTimeInterval(mdInt + jitter()),
                      reason: mdReason)
        ]
    }

    // MARK: Outlook cadence outside the explicit SPC windowing (handled by orchestrator)
    private func outlookInterval(_ s: DerivedState) -> (TimeInterval, String) {
        let base: TimeInterval
        switch s.riskTier {
        case .none:                 base = 3.5.hours
        case .slight:               base = 75.minutes
        case .enhanced:             base = 45.minutes
        case .moderate, .high:      base = 30.minutes
        }
        let relaxed = applyModifiers(base, s, label: "Outlook")
        return (relaxed.value, relaxed.reason)
    }

    // MARK: MD cadence with probability tightening
    private func mdInterval(_ s: DerivedState) -> (TimeInterval, String) {
        var base: TimeInterval
        switch (s.riskTier, s.md.hasActiveMD) {
        case (.none, false): base = 40.minutes
        case (.slight, _):   base = 12.minutes
        case (.enhanced, _),
             (.moderate, _),
             (.high, _):     base = 7.minutes
        case (.none, true):
            base = 40.0.minutes
        }

        // Tighten if watch prob ≥ 20%
        if s.md.watchProbBand != .lt20 {
            base = max(5.minutes, base * 0.7)
        }

        let relaxed = applyModifiers(base, s, label: "MD")
        return (relaxed.value, relaxed.reason)
    }

    // MARK: Modifiers (quiet hours + low power) with readable reasons
    private func applyModifiers(_ base: TimeInterval, _ s: DerivedState, label: String)
    -> (value: TimeInterval, reason: String) {
        var val = base
        var why: [String] = ["base \(label)=\(format(val)) @ \(s.riskTier)"]

        // Quiet hours relax only when ≤ Slight
        if s.quietHours, s.riskTier == .none || s.riskTier == .slight {
            val *= 1.6
            why.append("quiet-hours relax")
        }

        if s.lowPowerMode {
            val *= 1.4
            why.append("low-power relax")
        }

        if label == "MD" {
            why.append("prob=\(s.md.watchProbBand.description)")
        }

        return (val, why.joined(separator: " · "))
    }

    private func jitter() -> TimeInterval { Double.random(in: -180...180) } // ±3 min
    private func format(_ t: TimeInterval) -> String {
        let mins = Int(round(t / 60))
        return "\(mins)m"
    }
}
