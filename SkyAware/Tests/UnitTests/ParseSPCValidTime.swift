//
//  ParseSPCValidTime.swift
//  SkyAwareTests
//
//  Created by Justin Rooks on 11/11/25.
//

import Foundation
import Testing

@Suite("String.parseSPCValidTime(relativeTo:) — SPC DDHHmm → UTC")
struct ParseSPCValidTime_ExtensionTests {

    // MARK: Helpers

    private func ymdhmsUTC(_ date: Date) -> (Int, Int, Int, Int, Int, Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .utc
        let c = cal.dateComponents(in: .utc, from: date)
        return (c.year!, c.month!, c.day!, c.hour!, c.minute!, c.second!)
    }

    private func utcDate(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 0, _ mm: Int = 0, _ ss: Int = 0) -> Date {
        var comps = DateComponents()
        comps.calendar = {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = .utc
            return c
        }()
        comps.year = y; comps.month = m; comps.day = d
        comps.hour = hh; comps.minute = mm; comps.second = ss
        return comps.calendar!.date(from: comps)!
    }

    // MARK: Happy path

    @Test("Parses same-day DDHHmm within same month (UTC)")
    func parsesSameDaySameMonth() throws {
        let issue = utcDate(2025, 11, 10, 18)
        let result = try #require("102359".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(result) == (2025, 11, 10, 23, 59, 0))
    }

    @Test("Parses next day (no rollover) when DD > issue day")
    func parsesNextDaySameMonth() throws {
        let issue = utcDate(2025, 11, 10, 12)
        let result = try #require("112300".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(result) == (2025, 11, 11, 23, 0, 0))
    }

    @Test("Parses when DD == issue day (no rollover)")
    func parsesEqualDayNoRollover() throws {
        let issue = utcDate(2025, 11, 15, 7)
        let result = try #require("150000".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(result) == (2025, 11, 15, 0, 0, 0))
    }

    @Test("Parses with leading zeros in DDHHmm")
    func parsesLeadingZeros() throws {
        let issue = utcDate(2025, 11, 5)
        let result = try #require("050745".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(result) == (2025, 11, 5, 7, 45, 0))
    }

    // MARK: Month rollover

    @Test("Rollover: issue on 31st, DD = 01 → next month")
    func monthRollover_31stTo01() throws {
        let issue = utcDate(2025, 1, 31, 23)
        let result = try #require("010100".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(result) == (2025, 2, 1, 1, 0, 0))
    }

    @Test("Rollover: 30-day month to next month")
    func monthRollover_30DayMonth() throws {
        let issue = utcDate(2025, 4, 30, 10) // April
        let result = try #require("010000".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(result) == (2025, 5, 1, 0, 0, 0))
    }

    // MARK: Year rollover

    @Test("Rollover: December → January (next year)")
    func yearRollover_DecemberToJanuary() throws {
        let issue = utcDate(2025, 12, 31, 18)
        let result = try #require("010000".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(result) == (2026, 1, 1, 0, 0, 0))
    }

    // MARK: February behavior (leap vs non-leap)

    @Test("Non-leap year: DD=29 normalizes to March 1")
    func februaryNonLeap_Normalizes() throws {
        // 2025 is non-leap. Calendar normalization should push to Mar 1.
        let issue = utcDate(2025, 2, 20, 12)
        let result = try #require("290100".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(result) == (2025, 3, 1, 1, 0, 0))
    }

    @Test("Leap year: DD=29 remains Feb 29")
    func februaryLeap_Stays() throws {
        let issue = utcDate(2024, 2, 20, 12)
        let result = try #require("290100".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(result) == (2024, 2, 29, 1, 0, 0))
    }

    // MARK: Input validation

    @Test("Rejects wrong length (must be 6 chars DDHHmm)")
    func rejectsWrongLength() {
        let issue = utcDate(2025, 11, 10)
        #expect("10123".parseSPCValidTime(relativeTo: issue) == nil)   // 5 chars
        #expect("1001234".parseSPCValidTime(relativeTo: issue) == nil) // 7 chars
        #expect("".parseSPCValidTime(relativeTo: issue) == nil)
    }

    @Test("Rejects non-digit content")
    func rejectsNonDigits() {
        let issue = utcDate(2025, 11, 10)
        #expect("10a123".parseSPCValidTime(relativeTo: issue) == nil)
        #expect("ABCD12".parseSPCValidTime(relativeTo: issue) == nil)
        #expect("12!@34".parseSPCValidTime(relativeTo: issue) == nil)
    }

    // MARK: Time bounds

    @Test("Parses 00:00 and 23:59")
    func parsesMidnightAndLastMinute() throws {
        let issue = utcDate(2025, 11, 10)

        let midnight = try #require("100000".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(midnight) == (2025, 11, 10, 0, 0, 0))

        let lastMinute = try #require("102359".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(lastMinute) == (2025, 11, 10, 23, 59, 0))
    }

    // MARK: Rollover rule (only when DD < issueDay)

    @Test("Rollover occurs only when parsed day < issue day")
    func rolloverGuardBehavior() throws {
        let issue = utcDate(2025, 8, 20)

        // Day 19 < 20 → next month
        let d19 = try #require("190800".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(d19) == (2025, 9, 19, 8, 0, 0))

        // Day 20 == 20 → same month
        let d20 = try #require("200800".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(d20) == (2025, 8, 20, 8, 0, 0))

        // Day 21 > 20 → same month
        let d21 = try #require("210800".parseSPCValidTime(relativeTo: issue))
        #expect(ymdhmsUTC(d21) == (2025, 8, 21, 8, 0, 0))
    }

    // MARK: UTC handling

    @Test("Output components are evaluated in UTC")
    func outputIsUTC() throws {
        let issue = utcDate(2025, 6, 15, 22)
        let result = try #require("160500".parseSPCValidTime(relativeTo: issue))
        let (_, _, _, hh, mm, _) = ymdhmsUTC(result)
        #expect(hh == 5 && mm == 0)
    }
}
