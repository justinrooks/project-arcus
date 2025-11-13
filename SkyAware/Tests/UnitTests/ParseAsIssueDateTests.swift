//
//  ParseAsIssueDateTests.swift
//  SkyAwareTests
//
//  Created by Justin Rooks on 11/11/25.
//

import Foundation
import Testing

// MARK: - Assumption
// Your extension looks like:
// extension String {
//     /// Parses "0651 PM CST Sat Nov 08 2025" (or CDT) and returns the UTC Date.
//     func parseIssuedDate() -> Date? { ... }
// }

@Suite("String.parseIssuedDate → UTC (SPC-issued timestamp)")
struct ParseIssuedDate_ExtensionTests {

    // MARK: Helpers

    private func ymdhmUTC(_ date: Date) -> (y: Int, m: Int, d: Int, hh: Int, mm: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .utc
        let c = cal.dateComponents(in: .utc, from: date)
        return (c.year!, c.month!, c.day!, c.hour!, c.minute!)
    }

    // MARK: Baseline (CST → UTC-6)

    @Test("CST parses and normalizes to UTC")
    func parsesCSTAndConvertsToUTC() throws {
        let utc = try #require("0651 PM CST Sat Nov 08 2025".parseAsIssuedDate())
        #expect(ymdhmUTC(utc) == (2025, 11, 9, 0, 51)) // 18:51 -0600 → 00:51Z
    }

    @Test("CST case-insensitive")
    func parsesCSTCaseInsensitive() throws {
        let utc = try #require("0651 PM cst Sat Nov 08 2025".parseAsIssuedDate())
        #expect(ymdhmUTC(utc) == (2025, 11, 9, 0, 51))
    }

    // MARK: Daylight time (CDT → UTC-5)

    @Test("CDT parses and normalizes to UTC")
    func parsesCDTAndConvertsToUTC() throws {
        let utc = try #require("0651 PM CDT Sat Jun 14 2025".parseAsIssuedDate())
        #expect(ymdhmUTC(utc) == (2025, 6, 14, 23, 51)) // 18:51 -0500 → 23:51Z
    }

    @Test("CDT case-insensitive")
    func parsesCDTCaseInsensitive() throws {
        let utc = try #require("0651 PM cdt Sat Jun 14 2025".parseAsIssuedDate())
        #expect(ymdhmUTC(utc) == (2025, 6, 14, 23, 51))
    }

    // MARK: UTC boundary rollovers

    @Test("Month rollover at UTC boundary (CDT → next month)")
    func monthRolloverAtUTCBoundary_CDT() throws {
        // 23:30 CDT (UTC-5) on Jun 30 → +5h → Jul 1 04:30Z
        let utc = try #require("1130 PM CDT Mon Jun 30 2025".parseAsIssuedDate())
        #expect(ymdhmUTC(utc) == (2025, 7, 1, 4, 30))
    }

    @Test("Year rollover at UTC boundary (CST → next year)")
    func yearRolloverAtUTCBoundary_CST() throws {
        // 23:30 CST (UTC-6) on Dec 31 → +6h → Jan 1 05:30Z
        let utc = try #require("1130 PM CST Wed Dec 31 2025".parseAsIssuedDate())
        #expect(ymdhmUTC(utc) == (2026, 1, 1, 5, 30))
    }

    // MARK: AM/PM boundaries

    @Test("12:00 AM and 12:00 PM handling (CST)")
    func midnightAndNoonBoundariesCST() throws {
        // 12:00 AM → 00:00 -0600 → 06:00Z
        do {
            let utc = try #require("1200 AM CST Sun Jan 05 2025".parseAsIssuedDate())
            #expect(ymdhmUTC(utc) == (2025, 1, 5, 6, 0))
        }
        // 12:00 PM → 12:00 -0600 → 18:00Z
        do {
            let utc = try #require("1200 PM CST Sun Jan 05 2025".parseAsIssuedDate())
            #expect(ymdhmUTC(utc) == (2025, 1, 5, 18, 0))
        }
    }

    // MARK: Spacing + single-digit day

    @Test("Single-digit day and typical spacing")
    func singleDigitDayAndSpacing() throws {
        // Single-digit day should parse with same format
        let utc = try #require("0105 AM CDT Tue Jul 7 2025".parseAsIssuedDate())
        #expect(ymdhmUTC(utc) == (2025, 7, 7, 6, 5)) // 01:05 -0500 → 06:05Z
    }

    // MARK: Guardrails / invalids

    @Test("Rejects missing time zone")
    func rejectsMissingZone() {
        #expect("0651 PM Sat Nov 08 2025".parseAsIssuedDate() == nil)
    }

    @Test("Rejects invalid times")
    func rejectsInvalidTimes() {
        #expect("2401 AM CST Sat Nov 08 2025".parseAsIssuedDate() == nil) // 24:01 invalid for 12h clock
        #expect("1260 PM CST Sat Nov 08 2025".parseAsIssuedDate() == nil) // minute 60 invalid
    }

    @Test("Avoids ACST false positives")
    func avoidsACSTFalsePositive() {
        // If you key off \bCST\b/\bCDT\b, this should fail to parse.
        #expect("0651 PM ACST Sat Nov 08 2025".parseAsIssuedDate() == nil)
    }
}
