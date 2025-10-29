import Testing
@testable import SkyAware
import Foundation

@Suite("WatchParser")
struct WatchParserTests {
    let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()
    
    func dateComponents(hour: Int, minute: Int, day: Int, month: Int, year: Int) -> DateComponents {
        DateComponents(calendar: utcCalendar, timeZone: utcCalendar.timeZone, year: year, month: month, day: day, hour: hour, minute: minute)
    }
    
    func dateFromComponents(_ comps: DateComponents) -> Date {
        guard let date = utcCalendar.date(from: comps) else {
            fatalError("Failed to create date from components: \(comps)")
        }
        return date
    }

    // MARK: Valid Date Parsing Tests
    @Test
    func normalSameDay() throws {
        // 1:30 to 6:00 on same day, issued at 1:30 same day
        let issued = dateFromComponents(dateComponents(hour: 1, minute: 30, day: 24, month: 9, year: 2025))
        let text = "WW 620 SEVERE TSTM AR 240130Z - 240600Z"
        let result = WatchParser.parseValid(text, issued: issued)
        
        let (start, end) = try #require(result)
        // Expected start 2025-09-24 01:30, end 2025-09-24 06:00 UTC
        let expectedStart = dateFromComponents(dateComponents(hour: 1, minute: 30, day: 24, month: 9, year: 2025))
        let expectedEnd = dateFromComponents(dateComponents(hour: 6, minute: 0, day: 24, month: 9, year: 2025))
        
        #expect(start == expectedStart)
        #expect(end == expectedEnd)
    }

    @Test
    func overnightRollover() throws {
        // 2200 to 0200 next day, issued before start time on same day
        let issued = dateFromComponents(dateComponents(hour: 21, minute: 0, day: 10, month: 9, year: 2025))
        let text = "WW 620 SEVERE TSTM AR 102200Z - 110200Z"
        let result = WatchParser.parseValid(text, issued: issued)
        
        let (start, end) = try #require(result)
        // Expected start 2025-09-10 22:00, end 2025-09-11 02:00 UTC
        let expectedStart = dateFromComponents(dateComponents(hour: 22, minute: 0, day: 10, month: 9, year: 2025))
        let expectedEnd = dateFromComponents(dateComponents(hour: 2, minute: 0, day: 11, month: 9, year: 2025))

        #expect(start == expectedStart)
        #expect(end == expectedEnd)
    }

    @Test
    func endBeforeStartRollover() throws {
        // 0300 to 0200 (end before start), issued after start time: rollover end to next day
        let issued = dateFromComponents(dateComponents(hour: 4, minute: 0, day: 15, month: 7, year: 2025))
        let text = "WW 620 SEVERE TSTM AR 150300Z - 160200Z"
        let result = WatchParser.parseValid(text, issued: issued)
        
        let (start, end) = try #require(result)
        // Expected start 2025-07-15 03:00, end 2025-07-16 02:00 UTC
        let expectedStart = dateFromComponents(dateComponents(hour: 3, minute: 0, day: 15, month: 7, year: 2025))
        let expectedEnd = dateFromComponents(dateComponents(hour: 2, minute: 0, day: 16, month: 7, year: 2025))

        #expect(start == expectedStart)
        #expect(end == expectedEnd)
    }
    
    @Test
    func noMatchReturnsNil_validDateParsing() {
        let issued = dateFromComponents(dateComponents(hour: 12, minute: 0, day: 1, month: 1, year: 2025))
        let text = "No valid time range here"
        let result = WatchParser.parseValid(text, issued: issued)
        #expect(result == nil)
    }
    
    @Test
    func endOfYearRollover() throws {
        // 2300 to 0100, issued on Dec 31 before start 
        let issued = dateFromComponents(dateComponents(hour: 22, minute: 0, day: 31, month: 12, year: 2025))
        let text = "WW 620 SEVERE TSTM AR 312300Z - 010100Z"
        let result = WatchParser.parseValid(text, issued: issued)
        
        let (start, end) = try #require(result)
        // Expected start 2025-12-31 23:00, end 2026-01-01 01:00 UTC
        let expectedStart = dateFromComponents(dateComponents(hour: 23, minute: 0, day: 31, month: 12, year: 2025))
        let expectedEnd = dateFromComponents(dateComponents(hour: 1, minute: 0, day: 1, month: 1, year: 2026))
        
        #expect(start == expectedStart)
        #expect(end == expectedEnd)
    }
    
    
    // MARK: Parse Watch Number Tests
    @Test
    func parsesThreeDigitWatchNumber() throws {
        try assertParse("https://example.com/path/ww123.html", equals: 123)
    }

    @Test
    func parsesFourDigitWatchNumber() throws {
        try assertParse("https://example.com/path/ww1234.html", equals: 1234)
    }

    @Test
    func parsesLeadingZeros() throws {
        try assertParse("https://example.com/path/ww0123.html", equals: 123)
    }

    @Test
    func parsesZeroWhenAllZeros() throws {
        try assertParse("https://example.com/path/ww000.html", equals: 0)
    }

    @Test
    func rejectsTooFewDigits() throws {
        try assertParse("https://example.com/path/ww12.html", equals: nil)
        try assertParse("https://example.com/path/ww9.html", equals: nil)
    }

    @Test
    func rejectsTooManyDigits() throws {
        // Regex requires exactly 3 or 4 digits before .html, so this should not match
        try assertParse("https://example.com/path/ww12345.html", equals: nil)
    }

    @Test
    func parsesWithQueryAndFragment() throws {
        // Pattern is not anchored to the end, so query/fragment should still allow a match
        try assertParse("https://example.com/path/ww123.html?foo=bar#frag", equals: 123)
    }

    @Test
    func rejectsUppercaseVariants() throws {
        // Case-sensitive: uppercase WW or .HTML should not match
        try assertParse("https://example.com/path/WW123.html", equals: nil)
        try assertParse("https://example.com/path/ww123.HTML", equals: nil)
    }

    @Test
    func rejectsDifferentExtension() throws {
        try assertParse("https://example.com/path/ww123.htm", equals: nil)
        try assertParse("https://example.com/path/ww123.shtml", equals: nil)
    }

    @Test
    func firstOccurrenceWhenMultipleMatches() throws {
        // Should return the first match found in the URL string
        try assertParse("https://example.com/ww123.html/other/ww456.html", equals: 123)
    }

    @Test
    func noMatchReturnsNil_WatchNumber() throws {
        try assertParse("https://example.com/no-watch-here.html", equals: nil)
    }
    
    // Helper to reduce repetition across test cases
    private func assertParse(_ urlString: String, equals expected: Int?) throws {
        let url = try #require(URL(string: urlString))
        let result = WatchParser.parseWatchNumber(from: url)
        if let expected = expected {
            #expect(result == expected)
        } else {
            #expect(result == nil)
        }
    }
}
