//
//  RefreshPolicy.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/19/25.
//

import Foundation
import OSLog

struct RefreshPolicy: Sendable {
    private let logger = Logger.backgroundRefreshPolicy
    
    init() {}

    /// Compute the next run time in UTC (Zulu), with deterministic per-day minute jitter.
    /// - Parameters:
    ///   - now: current time (inject for testability)
    ///   - windowsUTC: issuance windows in "HHmm" Zulu (e.g., ["0600","1300","1630","2000"])
    ///   - jitterRangeMins: minute jitter range, applied once per day (e.g., 0...2)
    ///   - seed: stable seed to diversify jitter across identifiers (e.g., task id)
    func getNextRunTime(
        for cadence: Cadence,
        now: Date = .now,
        jitterRangeMins: ClosedRange<Int> = 0...2,
        seed: String = "com.skyaware.app.refresh"
    ) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)! // Zulu

        // Extract minutes from the provided cadence
        let minutes = cadence.getMinutes()
  
        // Exactly N minutes from now (no top-of-hour alignment)
        let target = cal.date(byAdding: .minute, value: minutes, to: now)!
        
        let jitterM = dailyJitterMinutes(seed: seed, now: now, range: jitterRangeMins, calendar: cal)
        let jittered = cal.date(byAdding: .minute, value: jitterM, to: target)!
        
        // Normalize seconds to :00 to avoid odd quantization
        return cal.date(bySetting: .second, value: 0, of: jittered)!
        
//        TOP OF THE HOUR LOGIC
//        let startOfThisHour = cal.dateInterval(of: .hour, for: now)!.start
//        let candidate1 = cal.date(byAdding: .minute, value: minutes, to: startOfThisHour)!
//        if candidate1 > now {
//            return cal.date(bySetting: .second, value: 0, of: candidate1)!
//        }
//
//        let startOfNextHour = cal.date(byAdding: .hour, value: 1, to: startOfThisHour)!
//        let candidate2 = cal.date(byAdding: .minute, value: minutes, to: startOfNextHour)!
//        return cal.date(bySetting: .second, value: 0, of: candidate2)!
    }
    
    /// Computes the next convective release from now. Convective outlooks are released 4 times per day.
    /// This will return you the next issuance window based on the windowsUTC property. Jitter is built in
    /// and there's an offset built on top of that as well.
    /// - Parameters:
    ///   - now: current time (inject for testability)
    ///   - windowsUTC: issuance windows in "HHmm" Zulu (e.g., ["0600","1300","1630","2000"])
    ///   - jitterRangeMins: minute jitter range, applied once per day (e.g., 0...2)
    ///   - seed: stable seed to diversify jitter across identifiers (e.g., task id)
    func getNextConvectiveRun(
        now: Date = .now,
        windowsUTC: [String] = ["0617", "1323", "1643", "2013"], // adjust as needed
        jitterRangeMins: ClosedRange<Int> = 0...2,
        seed: String = "com.skyaware.app.refresh"
    ) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)! // Zulu
        
        let todayStart = cal.startOfDay(for: now)
        let windows: [Date] = windowsUTC.compactMap { hm in
            guard let (h, m) = parseHHmm(hm) else { return nil }
            return cal.date(bySettingHour: h, minute: m, second: 0, of: todayStart)
        }.sorted()
        
        // First future window today, else tomorrow's first
        let base: Date = {
            if let next = windows.first(where: { $0 > now }) { return next }
            // roll to tomorrow's first window
            let tomorrow = cal.date(byAdding: .day, value: 1, to: todayStart)!
            let first = windows.first ?? cal.date(bySettingHour: 16, minute: 30, second: 0, of: tomorrow)! // fallback
            return cal.date(bySettingHour: cal.component(.hour, from: first),
                            minute: cal.component(.minute, from: first),
                            second: 0,
                            of: tomorrow)!
        }()
        
        // Deterministic, per-day jitter (minutes)
        let jitterM = dailyJitterMinutes(seed: seed, now: now, range: jitterRangeMins, calendar: cal)
        let jittered = cal.date(byAdding: .minute, value: jitterM, to: base)!
        
        // Normalize seconds to :00 so the system's minute granularity doesn't “quantize” you oddly
        return cal.date(bySetting: .second, value: 0, of: jittered)!
    }
    
    // MARK: - Helpers
    private func parseHHmm(_ s: String) -> (Int, Int)? {
        guard s.count == 4,
              let h = Int(s.prefix(2)),
              let m = Int(s.suffix(2)),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return (h, m)
    }
    
    private func dailyJitterMinutes(seed: String, now: Date, range: ClosedRange<Int>, calendar: Calendar) -> Int {
        // Stable per UTC day: YYYYMMDD + seed
        let comps = calendar.dateComponents(in: calendar.timeZone, from: calendar.startOfDay(for: now))
        let y = comps.year ?? 0, m = comps.month ?? 0, d = comps.day ?? 0
        let key = "\(seed)-\(y)\(String(format: "%02d", m))\(String(format: "%02d", d))"
        let h = abs(key.hashValue)
        return range.lowerBound + (h % (range.upperBound - range.lowerBound + 1))
    }
}
