//
//  RefreshPolicy.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/19/25.
//

import Foundation
import OSLog

enum Cadence: Sendable { case short(Int), normal(Int), long(Int) }

struct RefreshPolicy: Sendable {
    private let logger = Logger.refreshPolicy
    
    init() {}
    
    //    func getNextRunTime() -> Date? {
    ////        let calendar = Calendar.current
    //        var calendar = Calendar(identifier: .gregorian)
    //        calendar.timeZone = TimeZone(abbreviation: "UTC")!
    //        var dateComponents = DateComponents()
    //
    //        // Helper function to create a Date for a specific hour and minute today
    //        func createDate(hour: Int, minute: Int) -> Date {
    //            let today = Calendar.current.startOfDay(for: .now)
    //            dateComponents.hour = hour
    //            dateComponents.minute = minute
    //            // random seconds between 3-27
    //            let sec = Int.random(in: 3...27)
    //            dateComponents.second = sec
    //            return calendar.date(byAdding: dateComponents, to: today)!
    //        }
    //
    //        let scheduledTimes: [Date] = [
    //            createDate(hour: 7, minute: 23),   // 7:23 AM
    //            createDate(hour: 10, minute: 47), // 10:47 AM
    //            createDate(hour: 14, minute: 13), // 2:13 PM
    //            createDate(hour: 19, minute: 17)  // 7:17 PM
    //        ]
    //
    //        // 2. Get the current time
    //        let currentTime = Date()
    //        logger.debug("Current Time: \(currentTime.formatted(date: .omitted, time: .shortened))")
    //
    //        // 3. Find all times that are in the future
    //        let futureTimes = scheduledTimes.filter { $0 > currentTime }
    //
    //        // 4. From the future times, find the earliest one (which will be the "next" time)
    //        let nextTime = futureTimes.min { (date1, date2) in
    //            date1 < date2
    //        }
    //
    //        // 5. Print the result
    //        if let next = nextTime {
    //            logger.debug("The next scheduled time is: \(next.formatted(date: .omitted, time: .shortened))")
    //            var todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
    //            todayComponents.hour = calendar.component(.hour, from: next)
    //            todayComponents.minute = calendar.component(.minute, from: next)
    //            todayComponents.second = calendar.component(.second, from: next)
    //
    //            // Just a sample of setting one up for the next day.
    //            //            let today = Calendar.current.startOfDay(for: .now)
    //            //            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
    //            //            let amComponent = DateComponents(hour:8, minute: 15)
    //            //            let am = Calendar.current.date(byAdding: amComponent, to: tomorrow)
    //            //
    //
    //            return calendar.date(from: todayComponents)!
    //        } else {
    //            // If no future times are found, wrap around to the first time in the list
    //            // This assumes the `scheduledTimes` array is already sorted in ascending order.
    //            // If it's not sorted, you'd need to sort it first: `scheduledTimes.sorted().first`
    //            if let firstTimeOfNextCycle = scheduledTimes.first {
    //                let today = Calendar.current.startOfDay(for: .now)
    //                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
    //                let amComponent = calendar.dateComponents([.hour, .minute, .second], from: firstTimeOfNextCycle)
    //                let am = Calendar.current.date(byAdding: amComponent, to: tomorrow)
    //
    //                if let am {
    //                    logger.debug("All times for today have passed. The next scheduled time (wrapping around) is: \(am.formatted(date: .abbreviated, time: .shortened))")
    //                } else {
    //                    logger.warning("Error determining next scheduled runtime")
    //                }
    //
    //                return am
    //            } else {
    //                logger.warning("The list of scheduled times is empty.")
    //            }
    //        }
    //
    //        logger.warning("Should have a next time... investigate")
    //        return nil
    //    }
    func cadence(from runDate: Date, now: Date) -> Cadence {
        // Optional: collapse a date into a simple cadence for the Outcome
        let mins = Int(runDate.timeIntervalSince(now)/60)
        switch mins {
        case ..<30:  return .short(max(5, mins))
        case ..<90:  return .normal(mins)
        default:     return .long(mins)
        }
    }
    
    /// Compute the next run time in UTC (Zulu), with deterministic per-day minute jitter.
    /// - Parameters:
    ///   - now: current time (inject for testability)
    ///   - windowsUTC: issuance windows in "HHmm" Zulu (e.g., ["0600","1300","1630","2000"])
    ///   - jitterRangeMins: minute jitter range, applied once per day (e.g., 0...2)
    ///   - seed: stable seed to diversify jitter across identifiers (e.g., task id)
    func getNextRunTime(
        for cadence: Cadence,
        now: Date = .now
    ) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)! // Zulu

        // Offset by cadence
        let minutes: Int = switch cadence {
        case .short(let m):  m
        case .normal(let m): m
        case .long(let m):   m
        }
        
        let startOfThisHour = cal.dateInterval(of: .hour, for: now)!.start
        let candidate1 = cal.date(byAdding: .minute, value: minutes, to: startOfThisHour)!
        if candidate1 > now {
            return cal.date(bySetting: .second, value: 0, of: candidate1)!
        }

        let startOfNextHour = cal.date(byAdding: .hour, value: 1, to: startOfThisHour)!
        let candidate2 = cal.date(byAdding: .minute, value: minutes, to: startOfNextHour)!
        return cal.date(bySetting: .second, value: 0, of: candidate2)!
    }
    
//    /// Compute the next run time in UTC (Zulu), with deterministic per-day minute jitter.
//    /// - Parameters:
//    ///   - now: current time (inject for testability)
//    ///   - windowsUTC: issuance windows in "HHmm" Zulu (e.g., ["0600","1300","1630","2000"])
//    ///   - jitterRangeMins: minute jitter range, applied once per day (e.g., 0...2)
//    ///   - seed: stable seed to diversify jitter across identifiers (e.g., task id)
//    func getNextRunTime(
//        now: Date = .now,
//        windowsUTC: [String] = ["0617", "1323", "1643", "2013"], // adjust as needed
//        jitterRangeMins: ClosedRange<Int> = 0...2,
//        seed: String = "com.skyaware.app.refresh"
//    ) -> Date {
//        var cal = Calendar(identifier: .gregorian)
//        cal.timeZone = TimeZone(secondsFromGMT: 0)! // Zulu
//        
//        let todayStart = cal.startOfDay(for: now)
//        let windows: [Date] = windowsUTC.compactMap { hm in
//            guard let (h, m) = parseHHmm(hm) else { return nil }
//            return cal.date(bySettingHour: h, minute: m, second: 0, of: todayStart)
//        }.sorted()
//        
//        // First future window today, else tomorrow's first
//        let base: Date = {
//            if let next = windows.first(where: { $0 > now }) { return next }
//            // roll to tomorrow's first window
//            let tomorrow = cal.date(byAdding: .day, value: 1, to: todayStart)!
//            let first = windows.first ?? cal.date(bySettingHour: 16, minute: 30, second: 0, of: tomorrow)! // fallback
//            return cal.date(bySettingHour: cal.component(.hour, from: first),
//                            minute: cal.component(.minute, from: first),
//                            second: 0,
//                            of: tomorrow)!
//        }()
//        
//        // Deterministic, per-day jitter (minutes)
//        let jitterM = dailyJitterMinutes(seed: seed, now: now, range: jitterRangeMins, calendar: cal)
//        let jittered = cal.date(byAdding: .minute, value: jitterM, to: base)!
//        
//        // Normalize seconds to :00 so the system's minute granularity doesn't “quantize” you oddly
//        return cal.date(bySetting: .second, value: 0, of: jittered)!
//    }
    
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
