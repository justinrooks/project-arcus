//
//  ConvectiveOutlookRepoTests.swift
//  SkyAwareTests
//
//  Created by Justin Rooks on 11/12/25.
//

import Foundation
import Testing
import SwiftData
@testable import SkyAware

// MARK: - Test Doubles
private struct FakeSpcClient: SpcClient {
    enum Mode {
        case success(Data?)
        case failure(Error)
    }
    var mode: Mode
    func fetchRssData(for feed: RssProduct) async throws -> Data? {
        switch mode {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
    
    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data? {
        return nil
    }
}

private enum TestError: Error { case boom }

// MARK: - In-memory SwiftData helpers
@MainActor
private func makeInMemoryModelContainer() throws -> ModelContainer {
    let schema = Schema([
        ConvectiveOutlook.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: config)
}

// MARK: - Sample RSS payloads
private let sampleValidRSS: String = {
    // Two valid Convective Outlook items (Day 1, Day 2), one non-matching title, and one malformed item
    return """
    <rss version=\"2.0\">
      <channel>
        <title>SPC Products</title>
        <item>
          <title>Day 1 Convective Outlook</title>
          <link>https://www.spc.noaa.gov/products/outlook/day1otlk.html</link>
          <pubDate>Wed, 12 Nov 2025 12:00:00 GMT</pubDate>
          <description><![CDATA[
            ... ISSUED: 1200Z ... VALID UNTIL: 0000Z ... RISK: SLGT ... SUMMARY: Some summary for Day 1 ...
          ]]></description>
        </item>
        <item>
          <title>Day 2 Convective Outlook</title>
          <link>https://www.spc.noaa.gov/products/outlook/day2otlk.html</link>
          <pubDate>Wed, 12 Nov 2025 11:00:00 GMT</pubDate>
          <description><![CDATA[
            ... ISSUED: 1100Z ... VALID UNTIL: 2300Z ... RISK: MDT ... SUMMARY: Some summary for Day 2 ...
          ]]></description>
        </item>
        <item>
          <title>Some Other Product</title>
          <link>https://www.spc.noaa.gov/products/other.html</link>
          <pubDate>Wed, 12 Nov 2025 10:00:00 GMT</pubDate>
          <description>Other product not matching filter</description>
        </item>
        <item>
          <title>Day 3 Convective Outlook</title>
          <link>bad url</link>
          <pubDate>not a date</pubDate>
          <description>Malformed item should be dropped</description>
        </item>
      </channel>
    </rss>
    """
}()

private let sampleOnlyNonMatchingTitlesRSS: String = {
    return """
    <rss version=\"2.0\">
      <channel>
        <title>SPC Products</title>
        <item>
          <title>Day 1 Fire Weather Outlook</title>
          <link>https://example.com/fw</link>
          <pubDate>Wed, 12 Nov 2025 09:00:00 GMT</pubDate>
          <description>Not a convective outlook</description>
        </item>
      </channel>
    </rss>
    """
}()

private let sampleMalformedRSS: String = {
    return """
    <rss version=\"2.0\"><channel></channel></rss>
    """
}()

// MARK: - Tests
@Suite("ConvectiveOutlookRepo")
struct ConvectiveOutlookRepoTests {

    @Test("refresh inserts parsed outlooks and filters titles containing ' Convective Outlook'")
    func refresh_parsesAndUpserts() async throws {
        let container = try await MainActor.run { try makeInMemoryModelContainer() }
        let repo = ConvectiveOutlookRepo(modelContainer: container)

        let data = sampleValidRSS.data(using: .utf8)
        let client = FakeSpcClient(mode: .success(data))

        try await repo.refreshConvectiveOutlooks(using: client)

        // Verify we only stored the two matching items (Day 1 and Day 2)
        let allDay1 = try await repo.fetchConvectiveOutlooks(for: 1)
        let allDay2 = try await repo.fetchConvectiveOutlooks(for: 2)
        #expect(allDay1.count == 1)
        #expect(allDay2.count == 1)

        // Ensure fields are mapped
        let d1 = try #require(allDay1.first)
        #expect(d1.title.contains("Day 1"))
        #expect(d1.link.absoluteString.contains("day1"))
        #expect(d1.summary.isEmpty == false)
        #expect(d1.fullText.isEmpty == false)
        #expect(d1.day == 1)
        // Risk/issued/validUntil are parsed by OutlookParser; we just assert non-nil where applicable
        #expect(d1.issued != .distantPast)
        #expect(d1.validUntil != .distantPast)
    }

    @Test("refresh handles nil data without throwing and logs warning")
    func refresh_nilDataNoCrash() async throws {
        let container = try await MainActor.run { try makeInMemoryModelContainer() }
        let repo = ConvectiveOutlookRepo(modelContainer: container)

        let client = FakeSpcClient(mode: .success(nil))
        // Should not throw
        try await repo.refreshConvectiveOutlooks(using: client)

        // Nothing inserted
        let results = try await repo.fetchConvectiveOutlooks(for: 1)
        #expect(results.isEmpty)
    }

    @Test("refresh with malformed but parseable channel yields zero upserts")
    func refresh_malformedItemsFilteredOut() async throws {
        let container = try await MainActor.run { try makeInMemoryModelContainer() }
        let repo = ConvectiveOutlookRepo(modelContainer: container)

        let data = sampleOnlyNonMatchingTitlesRSS.data(using: .utf8)
        let client = FakeSpcClient(mode: .success(data))

        try await repo.refreshConvectiveOutlooks(using: client)

        // No items matched the title filter
        let d1 = try await repo.fetchConvectiveOutlooks(for: 1)
        let d2 = try await repo.fetchConvectiveOutlooks(for: 2)
        #expect(d1.isEmpty)
        #expect(d2.isEmpty)
    }

    @Test("current returns the most recently published outlook")
    @MainActor
    func current_returnsLatest() async throws {
        let container = try await MainActor.run { try makeInMemoryModelContainer() }
        let ctx = container.mainContext

        // Manually insert two items with different published dates
        let newer = ConvectiveOutlook(
            title: "Day 1 Convective Outlook",
            link: URL(string: "https://example.com/newer")!,
            published: Date().addingTimeInterval(3600),
            fullText: "...",
            summary: "newer",
            day: 1,
            riskLevel: "SLGT",
            issued: Date(),
            validUntil: Date()
        )
        let older = ConvectiveOutlook(
            title: "Day 2 Convective Outlook",
            link: URL(string: "https://example.com/older")!,
            published: Date().addingTimeInterval(-3600),
            fullText: "...",
            summary: "older",
            day: 2,
            riskLevel: "MRGL",
            issued: Date(),
            validUntil: Date()
        )
        ctx.insert(newer)
        ctx.insert(older)
        try ctx.save()

        let repo = ConvectiveOutlookRepo(modelContainer: container)
        let latest = try await repo.current()
        let dto = try #require(latest)
        #expect(dto.link.absoluteString.contains("newer"))
    }

    @Test("fetchConvectiveOutlooks(for:) filters by day and sorts by published desc")
    @MainActor
    func fetch_filtersAndSorts() async throws {
        let container = try await MainActor.run { try makeInMemoryModelContainer() }
        let ctx = container.mainContext

        let base = Date()
        let a = ConvectiveOutlook(title: "Day 1 Convective Outlook A",
                                  link: URL(string: "https://example.com/a")!,
                                  published: base.addingTimeInterval(100),
                                  fullText: "a",
                                  summary: "a",
                                  day: 1,
                                  riskLevel: nil,
                                  issued: base,
                                  validUntil: base)
        let b = ConvectiveOutlook(title: "Day 1 Convective Outlook B",
                                  link: URL(string: "https://example.com/b")!,
                                  published: base.addingTimeInterval(200),
                                  fullText: "b",
                                  summary: "b",
                                  day: 1,
                                  riskLevel: nil,
                                  issued: base,
                                  validUntil: base)
        let c = ConvectiveOutlook(title: "Day 2 Convective Outlook C",
                                  link: URL(string: "https://example.com/c")!,
                                  published: base.addingTimeInterval(300),
                                  fullText: "c",
                                  summary: "c",
                                  day: 2,
                                  riskLevel: nil,
                                  issued: base,
                                  validUntil: base)
        ctx.insert(a); ctx.insert(b); ctx.insert(c)
        try ctx.save()

        let repo = ConvectiveOutlookRepo(modelContainer: container)
        let day1 = try await repo.fetchConvectiveOutlooks(for: 1)
        #expect(day1.count == 2)
        #expect(day1[0].title.contains("B")) // newest first
        #expect(day1[1].title.contains("A"))

        let day2 = try await repo.fetchConvectiveOutlooks(for: 2)
        #expect(day2.count == 1)
        #expect(day2[0].title.contains("C"))
    }

    @Test("purge deletes items older than two days from reference date")
    @MainActor
    func purge_removesOldItems() async throws {
        let container = try await MainActor.run { try makeInMemoryModelContainer() }
        let ctx = container.mainContext

        let now = Date()
        let oldDate = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        let oldItem = ConvectiveOutlook(title: "Old Day 1 Convective Outlook",
                                        link: URL(string: "https://example.com/old")!,
                                        published: oldDate,
                                        fullText: "old",
                                        summary: "old",
                                        day: 1,
                                        riskLevel: nil,
                                        issued: oldDate,
                                        validUntil: oldDate)
        let recentItem = ConvectiveOutlook(title: "Recent Day 1 Convective Outlook",
                                           link: URL(string: "https://example.com/recent")!,
                                           published: recentDate,
                                           fullText: "recent",
                                           summary: "recent",
                                           day: 1,
                                           riskLevel: nil,
                                           issued: recentDate,
                                           validUntil: recentDate)
        ctx.insert(oldItem); ctx.insert(recentItem)
        try ctx.save()

        let repo = ConvectiveOutlookRepo(modelContainer: container)
        try await repo.purge(asOf: now)

        // Only the recent item should remain
        let remaining = try await repo.fetchConvectiveOutlooks(for: 1)
        #expect(remaining.count == 1)
        #expect(remaining[0].title.contains("Recent"))
    }
}
