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
        case success(Data)
        case failure(Error)
    }
    var mode: Mode
    func fetchRssData(for feed: RssProduct) async throws -> Data {
        switch mode {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
    
    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data {
        throw SpcError.missingGeoJsonData
    }
}

private struct SourcedRssSpcClient: SpcClient {
    let response: HTTPResponse

    func fetchRssData(for feed: RssProduct) async throws -> Data {
        guard let data = response.data else { throw SpcError.missingData }
        return data
    }

    func fetchRssResponse(for feed: RssProduct) async throws -> HTTPResponse {
        response
    }

    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data {
        throw SpcError.missingGeoJsonData
    }
}

private struct LegacyGeoJSONSpcClient: SpcClient {
    let data: Data

    func fetchRssData(for product: RssProduct) async throws -> Data { data }
    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data { data }
}

private enum TestError: Error { case boom }

private let rssTestNow = Date.now
private func rssDate(_ hoursAgo: Double) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .gmt
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
    return formatter.string(from: rssTestNow.addingTimeInterval(-hoursAgo * 3600))
}

// MARK: - Sample RSS payloads
private let sampleValidRSS: String = {
    // Two valid Convective Outlook items (Day 1, Day 2) and one non-matching title.
    return """
    <rss version=\"2.0\">
      <channel>
        <title>SPC Products</title>
        <item>
          <title>Day 1 Convective Outlook</title>
          <link>https://www.spc.noaa.gov/products/outlook/day1otlk.html</link>
          <pubDate>\(rssDate(1))</pubDate>
          <description><![CDATA[
            ... ISSUED: 1200Z ... VALID UNTIL: 0000Z ... RISK: SLGT ... SUMMARY: Some summary for Day 1 ...
          ]]></description>
        </item>
        <item>
          <title>Day 2 Convective Outlook</title>
          <link>https://www.spc.noaa.gov/products/outlook/day2otlk.html</link>
          <pubDate>\(rssDate(2))</pubDate>
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

private let sampleValidMesoRSS = """
<rss version=\"2.0\"><channel>
  <item>
    <title>SPC MD 1234</title>
    <link>https://www.spc.noaa.gov/products/md/md1234.html</link>
    <pubDate>Wed, 12 Nov 2025 12:00:00 GMT</pubDate>
    <description><![CDATA[Valid 121200Z - 121800Z]]></description>
  </item>
</channel></rss>
"""

private let missingChannelRSS = "<rss version=\"2.0\"></rss>"

private let malformedOutlookRSS = """
<rss version=\"2.0\"><channel><item>
  <title>Day 1 Convective Outlook</title>
  <link>products/outlook/day1otlk.html</link>
  <pubDate>Wed, 12 Nov 2025 12:00:00 GMT</pubDate>
  <description>Outlook text without parsed timestamps remains otherwise valid.</description>
</item></channel></rss>
"""

private let malformedMesoRSS = """
<rss version=\"2.0\"><channel><item>
  <title>SPC MD 1234</title>
  <link>https://www.spc.noaa.gov/products/md/md1234.html</link>
  <pubDate>Wed, 12 Nov 2025 12:00:00 GMT</pubDate>
  <description>Valid 122400Z - 130100Z</description>
</item></channel></rss>
"""

private let emptyMesoRSS = "<rss version=\"2.0\"><channel></channel></rss>"

private let previousMonthMesoRSS = """
<rss version=\"2.0\"><channel><item>
  <title>SPC MD 2345</title>
  <link>https://www.spc.noaa.gov/products/md/md2345.html</link>
  <pubDate>Thu, 01 Jan 2026 00:30:00 GMT</pubDate>
  <description>Valid 312330Z - 010200Z</description>
</item></channel></rss>
"""

@MainActor
private func makeDiskContainer(for models: [any PersistentModel.Type]) throws -> (ModelContainer, URL) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConvectiveOutlookRepoTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let schema = Schema(models)
    let configuration = ModelConfiguration(
        "ConvectiveOutlookRepoTests",
        schema: schema,
        url: directory.appendingPathComponent("SkyAware.sqlite")
    )
    return (try ModelContainer(for: schema, configurations: configuration), directory)
}

// MARK: - Tests
@Suite("ConvectiveOutlookRepo", .serialized)
struct ConvectiveOutlookRepoTests {

    @Test("refresh inserts supported convective outlooks and filters unrelated products")
    func refresh_parsesAndUpserts() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [ConvectiveOutlook.self]) }
        try await MainActor.run { try TestStore.reset(ConvectiveOutlook.self, in: container) }
        let repo = ConvectiveOutlookRepo(modelContainer: container)

        let data = try #require(sampleValidRSS.data(using: .utf8))
        let client = FakeSpcClient(mode: .success(data))

        try await repo.refreshConvectiveOutlooks(using: client)

        // Verify we only stored the two matching items (Day 1 and Day 2)
        let allDay1 = try await repo.fetchConvectiveOutlooks(for: 1)
        let allDay2 = try await repo.fetchConvectiveOutlooks(for: 2)
        #expect(allDay1.count == 1)
        #expect(allDay2.count == 1)
        #expect(try await repo.collectionSnapshot().outlooks.count == 2)
        #expect(try await repo.collectionSnapshot(for: 1).outlooks.count == 1)

        // Ensure fields are mapped
        let d1 = try #require(allDay1.first)
        #expect(d1.title.contains("Day 1"))
        #expect(d1.link.absoluteString.contains("day1"))
        #expect(d1.summary.isEmpty == false)
        #expect(d1.fullText.isEmpty == false)
        #expect(d1.day == 1)
        // This compact fixture intentionally omits parseable issue and valid-until headers.
        #expect(d1.issued == nil)
        #expect(d1.validUntil == nil)
    }

    @Test("refresh propagates client failure and does not insert")
    func refresh_clientFailureNoInsert() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [ConvectiveOutlook.self]) }
        try await MainActor.run { try TestStore.reset(ConvectiveOutlook.self, in: container) }
        let repo = ConvectiveOutlookRepo(modelContainer: container)

        let client = FakeSpcClient(mode: .failure(SpcError.missingData))
        do {
            try await repo.refreshConvectiveOutlooks(using: client)
            #expect(Bool(false), "Expected client failure to propagate")
        } catch let error as SpcError {
            #expect(error == .missingData)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }

        // Nothing inserted
        let results = try await repo.fetchConvectiveOutlooks(for: 1)
        #expect(results.isEmpty)
    }

    @Test("outlook channel without a recognized product rejects and preserves accepted rows")
    func refresh_unrecognizedChannelPreservesAcceptedOutlooks() async throws {
        let (container, directory) = try await MainActor.run {
            try makeDiskContainer(for: [ConvectiveOutlook.self])
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = ConvectiveOutlookRepo(modelContainer: container)

        try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(mode: .success(try #require(sampleValidRSS.data(using: .utf8)))))
        let data = try #require(sampleOnlyNonMatchingTitlesRSS.data(using: .utf8))
        let client = FakeSpcClient(mode: .success(data))

        do {
            try await repo.refreshConvectiveOutlooks(using: client)
            Issue.record("Expected channel without a recognized outlook to be rejected")
        } catch let error as SpcError {
            #expect(error == .parsingError)
        }

        #expect(try await repo.fetchConvectiveOutlooks(for: 1).count == 1)
        #expect(try await repo.fetchConvectiveOutlooks(for: 2).count == 1)
    }

    @Test("missing RSS channel rejects the refresh and preserves accepted outlooks")
    func refresh_missingChannelPreservesOutlooks() async throws {
        let (container, directory) = try await MainActor.run {
            try makeDiskContainer(for: [ConvectiveOutlook.self])
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = ConvectiveOutlookRepo(modelContainer: container)

        try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(mode: .success(try #require(sampleValidRSS.data(using: .utf8)))))

        do {
            try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(mode: .success(try #require(missingChannelRSS.data(using: .utf8)))))
            Issue.record("Expected missing channel to be rejected")
        } catch let error as SpcError {
            #expect(error == .parsingError)
        }

        #expect(try await repo.fetchConvectiveOutlooks(for: 1).count == 1)
        #expect(try await repo.fetchConvectiveOutlooks(for: 2).count == 1)
    }

    @Test("recognized outlook with a relative link rejects and preserves accepted outlooks")
    func refresh_relativeOutlookLinkPreservesAcceptedRows() async throws {
        let (container, directory) = try await MainActor.run {
            try makeDiskContainer(for: [ConvectiveOutlook.self])
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = ConvectiveOutlookRepo(modelContainer: container)

        try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(mode: .success(try #require(sampleValidRSS.data(using: .utf8)))))

        do {
            try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(mode: .success(try #require(malformedOutlookRSS.data(using: .utf8)))))
            Issue.record("Expected relative outlook link to be rejected")
        } catch let error as SpcError {
            #expect(error == .parsingError)
        }

        let outlook = try #require(await repo.fetchConvectiveOutlooks(for: 1).first)
        #expect(outlook.title == "Day 1 Convective Outlook")
        #expect(outlook.issued == nil)
        #expect(outlook.validUntil == nil)
    }

    @Test("missing RSS channel rejects meso refresh and preserves accepted discussions")
    func refresh_missingChannelPreservesMesos() async throws {
        let (container, directory) = try await MainActor.run {
            try makeDiskContainer(for: [MD.self])
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = MesoRepo(modelContainer: container)

        try await repo.refreshMesoscaleDiscussions(using: FakeSpcClient(mode: .success(try #require(sampleValidMesoRSS.data(using: .utf8)))))

        do {
            try await repo.refreshMesoscaleDiscussions(using: FakeSpcClient(mode: .success(try #require(missingChannelRSS.data(using: .utf8)))))
            Issue.record("Expected missing channel to be rejected")
        } catch let error as SpcError {
            #expect(error == .parsingError)
        }

        #expect(try await repo.getLatestMapData(asOf: utcDate(2025, 11, 12, 13)).count == 1)
    }

    @Test("meso with an invalid valid range rejects and valid empty meso remains accepted")
    func refresh_invalidMesoValidRangePreservesAcceptedRowsAndEmptyMesoSucceeds() async throws {
        let (container, directory) = try await MainActor.run {
            try makeDiskContainer(for: [MD.self])
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = MesoRepo(modelContainer: container)

        try await repo.refreshMesoscaleDiscussions(using: FakeSpcClient(mode: .success(try #require(sampleValidMesoRSS.data(using: .utf8)))))

        do {
            try await repo.refreshMesoscaleDiscussions(using: FakeSpcClient(mode: .success(try #require(malformedMesoRSS.data(using: .utf8)))))
            Issue.record("Expected meso with an invalid valid range to be rejected")
        } catch let error as SpcError {
            #expect(error == .parsingError)
        }

        try await repo.refreshMesoscaleDiscussions(using: FakeSpcClient(mode: .success(try #require(emptyMesoRSS.data(using: .utf8)))))
        #expect(try await repo.getLatestMapData(asOf: utcDate(2025, 11, 12, 13)).count == 1)
    }

    @Test("non-authoritative meso payloads preserve accepted rows and malformed cache remains rejected")
    func refresh_nonAuthoritativeMesoPreservesAcceptedRows() async throws {
        let (container, directory) = try await MainActor.run {
            try makeDiskContainer(for: [MD.self])
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = MesoRepo(modelContainer: container)
        let acceptedData = try #require(sampleValidMesoRSS.data(using: .utf8))
        try await repo.refreshMesoscaleDiscussions(using: FakeSpcClient(mode: .success(acceptedData)))

        let localCacheData = try #require(
            sampleValidMesoRSS
                .replacingOccurrences(of: "1234", with: "5678")
                .data(using: .utf8)
        )
        let localCacheSource = try await repo.refreshMesoscaleDiscussions(
            using: SourcedRssSpcClient(
                response: .init(status: 200, headers: [:], data: localCacheData, source: .localCache)
            )
        )
        #expect(localCacheSource == .localCache)
        #expect(try await repo.getLatestMapData(asOf: utcDate(2025, 11, 12, 13)).map(\.number) == [1234])

        do {
            try await repo.refreshMesoscaleDiscussions(
                using: SourcedRssSpcClient(
                    response: .init(status: 200, headers: [:], data: Data("not-xml".utf8), source: .localCache)
                )
            )
            Issue.record("Expected malformed cached meso payload to be rejected")
        } catch let error as SpcError {
            #expect(error == .parsingError)
        }

        #expect(try await repo.getLatestMapData(asOf: utcDate(2025, 11, 12, 13)).map(\.number) == [1234])
    }

    @Test("meso DDHHmmZ validity parses across month and year boundaries")
    func mesoValidityParsesSixDigitRangeAcrossMonthAndYearBoundaries() throws {
        let issued = utcDate(2025, 1, 31, 22)
        let validRange = try #require(MDParser.parseValid("Valid 312300Z - 010200Z", issued: issued))

        #expect(validRange.0 == utcDate(2025, 1, 31, 23))
        #expect(validRange.1 == utcDate(2025, 2, 1, 2))

        let yearIssued = utcDate(2025, 12, 31, 22)
        let yearRange = try #require(MDParser.parseValid("Valid 312300Z - 010200Z", issued: yearIssued))
        #expect(yearRange.0 == utcDate(2025, 12, 31, 23))
        #expect(yearRange.1 == utcDate(2026, 1, 1, 2))

        let previousMonthIssued = utcDate(2026, 1, 1, 0, 30)
        let previousMonthRange = try #require(
            MDParser.parseValid("Valid 312330Z - 010200Z", issued: previousMonthIssued)
        )
        #expect(previousMonthRange.0 == utcDate(2025, 12, 31, 23, 30))
        #expect(previousMonthRange.1 == utcDate(2026, 1, 1, 2))
    }

    @Test("meso DDHHmmZ validity rejects invalid or reversed ranges")
    func mesoValidityRejectsMalformedSixDigitRanges() {
        let issued = utcDate(2025, 1, 12, 12)

        for text in [
            "Valid 002300Z - 002359Z",
            "Valid 122400Z - 130100Z",
            "Valid 121860Z - 121900Z",
            "Valid 121800Z - 121200Z",
            "Valid 121200Z - 311200Z",
            "Valid 311200Z - 311300Z"
        ] {
            #expect(MDParser.parseValid(text, issued: issued) == nil)
        }
    }

    @Test("meso crossing into the issue month is accepted from a disk-backed feed")
    func refresh_previousMonthMesoRangeIsAccepted() async throws {
        let (container, directory) = try await MainActor.run {
            try makeDiskContainer(for: [MD.self])
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = MesoRepo(modelContainer: container)

        try await repo.refreshMesoscaleDiscussions(
            using: FakeSpcClient(mode: .success(try #require(previousMonthMesoRSS.data(using: .utf8))))
        )

        let meso = try #require(await repo.getLatestMapData(asOf: utcDate(2026, 1, 1, 1)).first)
        #expect(meso.number == 2345)
        #expect(meso.validStart == utcDate(2025, 12, 31, 23, 30))
        #expect(meso.validEnd == utcDate(2026, 1, 1, 2))
    }

    @Test("current returns the most recently published outlook")
    @MainActor
    func current_returnsLatest() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [ConvectiveOutlook.self]) }
        try await MainActor.run { try TestStore.reset(ConvectiveOutlook.self, in: container) }
        let ctx = container.mainContext

        // Manually insert two items with different published dates
        let newer = ConvectiveOutlook(
            title: "Day 1 Convective Outlook",
            link: URL(string: "https://example.com/newer")!,
            published: Date().addingTimeInterval(-60),
            fullText: "...",
            summary: "newer",
            day: 1,
            riskLevel: "SLGT",
            issued: nil,
            validUntil: nil
        )
        let older = ConvectiveOutlook(
            title: "Day 2 Convective Outlook",
            link: URL(string: "https://example.com/older")!,
            published: Date().addingTimeInterval(-3600),
            fullText: "...",
            summary: "older",
            day: 2,
            riskLevel: "MRGL",
            issued: nil,
            validUntil: nil
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
        let container = try await MainActor.run { try TestStore.container(for: [ConvectiveOutlook.self]) }
        try await MainActor.run { try TestStore.reset(ConvectiveOutlook.self, in: container) }
        let ctx = container.mainContext

        let base = Date()
        let a = ConvectiveOutlook(title: "Day 1 Convective Outlook A",
                                  link: URL(string: "https://example.com/a")!,
                                  published: base.addingTimeInterval(-300),
                                  fullText: "a",
                                  summary: "a",
                                  day: 1,
                                  riskLevel: nil,
                                  issued: nil,
                                  validUntil: base.addingTimeInterval(3600))
        let b = ConvectiveOutlook(title: "Day 1 Convective Outlook B",
                                  link: URL(string: "https://example.com/b")!,
                                  published: base.addingTimeInterval(-200),
                                  fullText: "b",
                                  summary: "b",
                                  day: 1,
                                  riskLevel: nil,
                                  issued: nil,
                                  validUntil: base.addingTimeInterval(3600))
        let c = ConvectiveOutlook(title: "Day 2 Convective Outlook C",
                                  link: URL(string: "https://example.com/c")!,
                                  published: base.addingTimeInterval(-100),
                                  fullText: "c",
                                  summary: "c",
                                  day: 2,
                                  riskLevel: nil,
                                  issued: nil,
                                  validUntil: base.addingTimeInterval(3600))
        ctx.insert(a); ctx.insert(b); ctx.insert(c)
        try ctx.save()

        let repo = ConvectiveOutlookRepo(modelContainer: container)
        let day1 = try await repo.fetchConvectiveOutlooks(for: 1)
        try #require(day1.count == 2)
        #expect(day1[0].title.contains("B")) // newest first
        #expect(day1[1].title.contains("A"))

        let day2 = try await repo.fetchConvectiveOutlooks(for: 2)
        #expect(day2.count == 1)
        #expect(day2[0].title.contains("C"))
    }

    @Test("purge removes expired legacy rows without inventing acceptance")
    @MainActor
    func purge_removesOldItems() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [ConvectiveOutlook.self]) }
        try await MainActor.run { try TestStore.reset(ConvectiveOutlook.self, in: container) }
        let ctx = container.mainContext

        let now = utcDate(2026, 6, 15, 12)
        let oldDate = utcDate(2026, 6, 12, 12)
        let recentDate = utcDate(2026, 6, 14, 12)

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

        // Both source validity periods have expired.
        let remaining = try await repo.fetchConvectiveOutlooks(for: 1)
        #expect(remaining.isEmpty)
        #expect(try await repo.collectionSnapshot() == .unavailable)
    }

    @Test("a partial RSS response preserves omitted accepted days across restart")
    func partialRSS_reopensAndPreservesProvenance() async throws {
        let (container, directory) = try await MainActor.run {
            try makeDiskContainer(for: [ConvectiveOutlook.self])
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = ConvectiveOutlookRepo(modelContainer: container)
        let populated = try #require(sampleValidRSS.data(using: .utf8))
        let dayTwoOnly = try #require(sampleValidRSS.replacingOccurrences(
            of: "Day 1 Convective Outlook", with: "Day 1 Fire Weather Outlook"
        ).data(using: .utf8))

        #expect(try await repo.collectionSnapshot() == .unavailable)
        // A legacy partial row set has no accepted-set marker.
        let legacy = ConvectiveOutlook(
            title: "Legacy Day 2 Convective Outlook",
            link: URL(string: "https://example.com/legacy")!,
            published: utcDate(2025, 11, 11, 12),
            fullText: "legacy", summary: "legacy", day: 2,
            riskLevel: nil, issued: nil, validUntil: nil
        )
        await MainActor.run { container.mainContext.insert(legacy) }
        try await MainActor.run { try container.mainContext.save() }
        #expect(try await repo.collectionSnapshot() == .unavailable)
        try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(mode: .success(populated)))
        #expect(try await repo.collectionSnapshot().outlooks.count == 2)
        try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(mode: .success(dayTwoOnly)))
        #expect(try await repo.collectionSnapshot(for: 1).outlooks.count == 1)
        #expect(try await repo.fetchConvectiveOutlooks(for: 1).count == 1)
        #expect(try await repo.fetchConvectiveOutlooks(for: 2).count == 1)

        let reopened = try await MainActor.run { () throws -> ModelContainer in
            let schema = Schema([ConvectiveOutlook.self])
            let configuration = ModelConfiguration(
                "ConvectiveOutlookRepoTests", schema: schema,
                url: directory.appendingPathComponent("SkyAware.sqlite")
            )
            return try ModelContainer(for: schema, configurations: configuration)
        }
        let reopenedRepo = ConvectiveOutlookRepo(modelContainer: reopened)
        #expect(try await reopenedRepo.collectionSnapshot(for: 1).outlooks.count == 1)

        let feedState = FeedStateStore(directoryURL: directory)
        let acceptedAt = Date.now
        _ = try await feedState.update(FeedStateUpdate(
            feedID: "spc.outlook", attemptedAt: acceptedAt, canonicalAcceptedAt: acceptedAt
        ))
        try await reopenedRepo.purge(asOf: rssTestNow.addingTimeInterval(49 * 3600))
        #expect(try await reopenedRepo.collectionSnapshot() == .unavailable)
        #expect(try await FeedStateStore(directoryURL: directory).record(for: "spc.outlook")?.generation == 1)
    }

    @Test("all accepted days and earlier issuances survive failure and store reopen")
    func multiDayCollection_reopensAfterFailure() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("outlooks.sqlite")
        // SPC uses Severe Thunderstorm Outlook for Day 3; the synthetic Convective title hid its rejection.
        let products = [(1, 12), (2, 11), (3, 10), (2, 9), (3, 8), (1, 7), (4, 6), (10, 5)]
        let rss = "<rss version=\"2.0\"><channel>" + products.map { day, hour in
            let product = day == 3 ? "Severe Thunderstorm" : "Convective"
            return """
            <item><title>SPC Nov 12, 2025 \(hour)00 UTC Day \(day) \(product) Outlook</title>
            <link>https://www.spc.noaa.gov/products/outlook/day\(day)otlk.html</link>
            <pubDate>\(rssDate(Double(13 - hour)))</pubDate>
            <description>Discussion for Day \(day)</description></item>
            """
        }.joined() + """
        <item><title>SPC Day 2 Fire Weather Outlook</title></item>
        <item><title>SPC Convective Outlook</title></item>
        <item><title>SPC Mesoscale Discussion 1234</title></item>
        </channel></rss>
        """
        let accepted = try await { () async throws -> ConvectiveOutlookCollectionSnapshot in
            let container = try await MainActor.run {
                try ModelContainer(for: ConvectiveOutlook.self, configurations: ModelConfiguration(url: storeURL))
            }
            let repo = ConvectiveOutlookRepo(modelContainer: container)
            try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(mode: .success(Data(rss.utf8))))
            let snapshot = try await repo.collectionSnapshot()
            #expect(snapshot.outlooks.count == 6)
            for day in 1...3 {
                #expect(snapshot.outlooks.filter { $0.day == day }.count == 2)
            }
            // Recognized malformed Day 3, invalid XML, and unrecognized feeds must not replace any day.
            for rejected in [rss,
                             "<rss><channel><item>", sampleOnlyNonMatchingTitlesRSS] {
                // Use an invalid publication date to make the recognized Day 3 item definitively invalid.
                let malformed = rejected.replacingOccurrences(
                    of: rssDate(3), with: "invalid date"
                )
                do {
                    try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(mode: .success(Data(malformed.utf8))))
                    Issue.record("Expected rejected refresh")
                } catch let error as SpcError {
                    #expect(error == .parsingError)
                }
                #expect(try await repo.collectionSnapshot() == snapshot)
            }
            for source in [HTTPResponse.Source.cacheFallback, .localCache] {
                _ = try await repo.refreshConvectiveOutlooks(using: SourcedRssSpcClient(
                    response: HTTPResponse(status: 200, headers: [:], data: Data(sampleValidRSS.utf8), source: source)
                ))
                #expect(try await repo.collectionSnapshot() == snapshot)
            }
            do {
                try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(mode: .failure(TestError.boom)))
                Issue.record("Expected refresh failure")
            } catch TestError.boom {}
            #expect(try await repo.collectionSnapshot() == snapshot)
            return snapshot
        }()
        let reopened = try await MainActor.run {
            try ModelContainer(for: ConvectiveOutlook.self, configurations: ModelConfiguration(url: storeURL))
        }
        let restoredRepo = ConvectiveOutlookRepo(modelContainer: reopened)
        let restored = try await restoredRepo.collectionSnapshot()
        #expect(restored == accepted)
        let provider = SpcProvider(
            outlookRepo: restoredRepo, mesoRepo: MesoRepo(modelContainer: reopened),
            alertRepo: AlertRepo(modelContainer: reopened), stormRiskRepo: StormRiskRepo(modelContainer: reopened),
            severeRiskRepo: SevereRiskRepo(modelContainer: reopened), fireRiskRepo: FireRiskRepo(modelContainer: reopened),
            spcMapBatchPersistenceRepo: SpcMapBatchPersistenceRepo(modelContainer: reopened),
            client: FakeSpcClient(mode: .failure(TestError.boom))
        )
        let home = try await HomeSnapshotStore(
            spcRisk: provider, spcOutlook: provider,
            arcusAlerts: StubArcusAlertQuerying(activeWarnings: .success([])),
            arcusMesos: StubArcusMesoQuerying(mesos: .success([]))
        ).loadSnapshot(for: nil, weather: nil, freshness: .init(), refreshMesos: false)
        let displayed = await MainActor.run {
            let pipeline = HomeRefreshPipeline(initialOutlooks: home.outlooks)
            return HomeView.preferredOutlooks(
                cachedOutlooks: [], liveOutlooks: pipeline.outlooks, refreshStatus: .success(hasContent: true)
            )
        }
        #expect(displayed == restored.outlooks)
        for day in [SPCForecastDay.day1, .day2, .day3] {
            let presentation = ConvectiveOutlookDayPresentation(
                day: day, collection: displayed, refreshStatus: .failed
            )
            #expect(presentation.state == .populated(.failed))
            try #require(presentation.outlooks.count == 2)
            #expect(presentation.outlooks[0].published > presentation.outlooks[1].published)
            print("issue-732 accepted/restored/Home/presentation Day \(day.rawValue): \(presentation.outlooks.count)")
            #expect(presentation.outlooks.allSatisfy { $0.day == day.rawValue && $0.validUntil == nil })
            let path = await MainActor.run {
                ConvectiveOutlookView.navigationPath(
                    for: day, opensLatestDiscussion: true, dtos: displayed,
                    refreshStatus: .failed, hasAcceptedEmptySnapshot: false, isOffline: true
                )
            }
            #expect(path == [presentation.outlooks[0]])
        }
    }

    @Test("rejected and failed refresh preserve the accepted collection")
    func rejectedAndFailedRefresh_preserveAcceptedCollection() async throws {
        let (container, directory) = try await MainActor.run {
            try makeDiskContainer(for: [ConvectiveOutlook.self])
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = ConvectiveOutlookRepo(modelContainer: container)
        try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(
            mode: .success(try #require(sampleValidRSS.data(using: .utf8)))
        ))
        let accepted = try await repo.collectionSnapshot()

        do {
            try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(
                mode: .success(try #require(sampleOnlyNonMatchingTitlesRSS.data(using: .utf8)))
            ))
            Issue.record("Expected rejected refresh")
        } catch let error as SpcError {
            #expect(error == .parsingError)
        }
        #expect(try await repo.collectionSnapshot() == accepted)

        do {
            try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(mode: .failure(TestError.boom)))
            Issue.record("Expected failed refresh")
        } catch TestError.boom {}
        #expect(try await repo.collectionSnapshot() == accepted)
    }

    private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components)!
    }
}

private actor SpcMockHTTPClientState {
    var requests: [(url: URL, headers: [String: String], fallbackPolicy: HTTPFallbackPolicy)] = []

    func record(url: URL, headers: [String: String], fallbackPolicy: HTTPFallbackPolicy) {
        requests.append((url: url, headers: headers, fallbackPolicy: fallbackPolicy))
    }

    func firstRequest() -> (url: URL, headers: [String: String], fallbackPolicy: HTTPFallbackPolicy)? {
        requests.first
    }
}

private final class SpcMockHTTPClient: HTTPClient, @unchecked Sendable {
    private let state = SpcMockHTTPClientState()
    private let response: HTTPResponse
    private let error: Error?

    init(response: HTTPResponse, error: Error? = nil) {
        self.response = response
        self.error = error
    }

    func get(
        _ url: URL,
        headers: [String : String],
        fallbackPolicy: HTTPFallbackPolicy
    ) async throws -> HTTPResponse {
        await state.record(url: url, headers: headers, fallbackPolicy: fallbackPolicy)
        if let error { throw error }
        return response
    }
    
    func post(_ url: URL, headers: [String : String], body: Data?) async throws -> HTTPResponse {
        await state.record(url: url, headers: headers, fallbackPolicy: .unrestricted)
        if let error { throw error }
        return response
    }

    func clearCache() {}

    func firstRequest() async -> (url: URL, headers: [String: String], fallbackPolicy: HTTPFallbackPolicy)? {
        await state.firstRequest()
    }
}

@Suite("SpcHttpClient")
struct SpcHttpClientTests {
    @Test("forecast capability policy exposes only supported day and product pairs")
    func forecastCapabilities_areBounded() {
        #expect(SPCForecastProduct.categorical.supportedDays == [.day1, .day2, .day3])
        #expect(SPCForecastProduct.tornado.supportedDays == [.day1, .day2])
        #expect(SPCForecastProduct.hail.supportedDays == [.day1, .day2])
        #expect(SPCForecastProduct.wind.supportedDays == [.day1, .day2])
        #expect(SPCForecastProduct.fire.supportedDays == [.current])
        #expect(SPCForecastProduct.meso.supportedDays == [.current])
    }

    @Test("legacy client defaults preserve only requests whose day they can honor")
    func legacyClientDefaults_preserveDayIdentity() async throws {
        let payload = Data("legacy".utf8)
        let client = LegacyGeoJSONSpcClient(data: payload)

        let legacySupportedPairs: [(GeoJSONProduct, SPCForecastDay)] = [
            (.categorical, .day1),
            (.tornado, .day1),
            (.hail, .day1),
            (.wind, .day1),
            (.fireRH, .current)
        ]
        for (product, day) in legacySupportedPairs {
            #expect(try await client.fetchGeoJsonData(for: product, day: day) == payload)
            #expect(try await client.fetchGeoJsonResponse(for: product, day: day).data == payload)
        }

        let legacyUnsupportedPairs: [(GeoJSONProduct, SPCForecastDay, SPCForecastProduct)] = [
            (.categorical, .day2, .categorical),
            (.categorical, .day3, .categorical),
            (.tornado, .day2, .tornado),
            (.hail, .day2, .hail),
            (.wind, .day2, .wind)
        ]
        for (product, day, forecastProduct) in legacyUnsupportedPairs {
            let expectedError = SpcError.dayAwareFetchRequired(day: day, product: forecastProduct)
            do {
                _ = try await client.fetchGeoJsonData(for: product, day: day)
                Issue.record("Expected legacy data request to require day-aware support")
            } catch let error as SpcError {
                #expect(error == expectedError)
            }
            do {
                _ = try await client.fetchGeoJsonResponse(for: product, day: day)
                Issue.record("Expected legacy response request to require day-aware support")
            } catch let error as SpcError {
                #expect(error == expectedError)
            }
        }
    }

    @Test("fetchRssData builds RSS endpoint and xml accept headers")
    func fetchRssData_buildsRequest() async throws {
        let payload = Data("<rss/>".utf8)
        let http = SpcMockHTTPClient(response: HTTPResponse(status: 200, headers: [:], data: payload))
        let client = SpcHttpClient(http: http)

        let data = try await client.fetchRssData(for: .convective)
        #expect(data == payload)

        let request = try #require(await http.firstRequest())
        #expect(request.url.host == "www.spc.noaa.gov")
        #expect(request.url.path == "/products/spcacrss.xml")
        #expect(request.headers["User-Agent"]?.isEmpty == false)
        #expect((request.headers["Accept"] ?? "").contains("application/rss+xml"))
        #expect(request.fallbackPolicy == .maximumAge(10 * 60))
    }

    @Test("current discussion requests use official day pages and preserve HTTP cache provenance", arguments: [SPCForecastDay.day1, .day2, .day3])
    func currentDiscussionRequest(day: SPCForecastDay) async throws {
        let payload = Data(capturedSPCDiscussions[day.rawValue - 1].utf8)
        let http = SpcMockHTTPClient(response: HTTPResponse(status: 200, headers: [:], data: payload, source: .cacheRevalidated304))
        let response = try await SpcHttpClient(http: http).fetchCurrentOutlookResponse(for: day)
        let request = try #require(await http.firstRequest())
        #expect(request.url.absoluteString == "https://www.spc.noaa.gov/products/outlook/day\(day.rawValue)otlk.html")
        #expect(request.headers["Accept"] == "text/html")
        #expect(request.fallbackPolicy == .maximumAge(600))
        #expect(response.source == .cacheRevalidated304)
        #expect(response.data == payload)
    }

    @Test("fetchGeoJsonData builds outlook path and geojson accept headers")
    func fetchGeoJsonData_buildsRequest() async throws {
        let payload = Data("{\"type\":\"FeatureCollection\",\"features\":[]}".utf8)
        let http = SpcMockHTTPClient(response: HTTPResponse(status: 200, headers: [:], data: payload))
        let client = SpcHttpClient(http: http)

        let data = try await client.fetchGeoJsonData(for: .tornado)
        #expect(data == payload)

        let request = try #require(await http.firstRequest())
        #expect(request.url.path == "/products/outlook/day1otlk_torn.lyr.geojson")
        #expect((request.headers["Accept"] ?? "").contains("application/geo+json"))
    }

    @Test("day-scoped GeoJSON requests address SPC Day 2 and Day 3 products")
    func fetchGeoJsonData_buildsDayScopedRequests() async throws {
        let payload = Data("{\"type\":\"FeatureCollection\",\"features\":[]}".utf8)

        for (product, day, expectedPath) in [
            (GeoJSONProduct.categorical, SPCForecastDay.day2, "/products/outlook/day2otlk_cat.lyr.geojson"),
            (GeoJSONProduct.categorical, .day3, "/products/outlook/day3otlk_cat.lyr.geojson"),
            (GeoJSONProduct.tornado, .day2, "/products/outlook/day2otlk_torn.lyr.geojson"),
            (GeoJSONProduct.hail, .day2, "/products/outlook/day2otlk_hail.lyr.geojson"),
            (GeoJSONProduct.wind, .day2, "/products/outlook/day2otlk_wind.lyr.geojson")
        ] {
            let http = SpcMockHTTPClient(response: HTTPResponse(status: 200, headers: [:], data: payload))
            let client = SpcHttpClient(http: http)
            _ = try await client.fetchGeoJsonData(for: product, day: day)
            #expect(try #require(await http.firstRequest()).url.path == expectedPath)
        }
    }

    @Test("unsupported day and product requests fail before transport")
    func fetchGeoJsonData_rejectsUnsupportedRequests() async throws {
        let http = SpcMockHTTPClient(response: HTTPResponse(status: 200, headers: [:], data: Data()))
        let client = SpcHttpClient(http: http)

        do {
            _ = try await client.fetchGeoJsonData(for: .tornado, day: .day3)
            Issue.record("Expected Day 3 tornado request to be rejected")
        } catch let error as SpcError {
            #expect(error == .unsupportedForecastRequest(day: .day3, product: .tornado))
        }
        #expect(await http.firstRequest() == nil)

        do {
            _ = try await client.fetchGeoJsonData(for: .fireRH, day: .day1)
            Issue.record("Expected day-scoped fire request to be rejected")
        } catch let error as SpcError {
            #expect(error == .unsupportedForecastRequest(day: .day1, product: .fire))
        }
        #expect(await http.firstRequest() == nil)
    }

    @Test("fetchGeoJsonResponse preserves cache transport provenance")
    func fetchGeoJsonResponse_preservesTransportSource() async throws {
        let payload = Data("{\"type\":\"FeatureCollection\",\"features\":[]}".utf8)
        let http = SpcMockHTTPClient(
            response: HTTPResponse(status: 200, headers: [:], data: payload, source: .cacheRevalidated304)
        )
        let client = SpcHttpClient(http: http)

        let response = try await client.fetchGeoJsonResponse(for: .fireRH)
        #expect(response.data == payload)
        #expect(response.source == .cacheRevalidated304)
        let request = try #require(await http.firstRequest())
        #expect(request.url.path == "/products/fire_wx/day1fw_windrh.lyr.geojson")
    }

    @Test("429 maps to SpcError.rateLimited")
    func status429_throwsRateLimited() async throws {
        let http = SpcMockHTTPClient(
            response: HTTPResponse(status: 429, headers: ["Retry-After": "45"], data: nil)
        )
        let client = SpcHttpClient(http: http)

        do {
            _ = try await client.fetchRssData(for: .meso)
            #expect(Bool(false), "Expected SpcError.rateLimited(retryAfterSeconds:)")
        } catch let error as SpcError {
            #expect(error == .rateLimited(retryAfterSeconds: 45))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("503 maps to SpcError.serviceUnavailable")
    func status503_throwsServiceUnavailable() async throws {
        let http = SpcMockHTTPClient(
            response: HTTPResponse(status: 503, headers: ["Retry-After": "30"], data: nil)
        )
        let client = SpcHttpClient(http: http)

        do {
            _ = try await client.fetchGeoJsonData(for: .hail)
            #expect(Bool(false), "Expected SpcError.serviceUnavailable(retryAfterSeconds:)")
        } catch let error as SpcError {
            #expect(error == .serviceUnavailable(retryAfterSeconds: 30))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("empty successful response maps to SpcError.missingData")
    func emptyBody_throwsMissingData() async throws {
        let http = SpcMockHTTPClient(response: HTTPResponse(status: 200, headers: [:], data: nil))
        let client = SpcHttpClient(http: http)

        do {
            _ = try await client.fetchRssData(for: .watch)
            #expect(Bool(false), "Expected SpcError.missingData")
        } catch let error as SpcError {
            #expect(error == .missingData)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }
}

@Suite("ConvectiveOutlookView copy")
struct ConvectiveOutlookViewCopyTests {
    @MainActor
    @Test("overview message uses calm ready language while loading")
    func overviewMessage_usesReadyLanguage() {
        #expect(
            ConvectiveOutlookView.overviewMessage(for: nil)
                == "Latest outlooks from SPC will appear here once they are ready."
        )
    }

    @MainActor
    @Test("overview message keeps provenance when a latest outlook exists")
    func overviewMessage_mentionsSPCOutlook() {
        let message = ConvectiveOutlookView.overviewMessage(for: ConvectiveOutlook.sampleOutlookDtos.first)

        #expect(message.contains("latest SPC outlook"))
        #expect(message.contains("Most recent update:"))
    }
}

@Suite("ConvectiveOutlookView sorting")
struct ConvectiveOutlookViewSortingTests {
    @Test("earlier outlooks remain newest to oldest by publication time")
    func sortsByPublishedDateDescending() {
        let newerPublicationButOlderIssue = ConvectiveOutlookDTO(
            title: "Day 2 Convective Outlook",
            link: URL(string: "https://example.com/day2")!,
            published: Date(timeIntervalSince1970: 2_000),
            summary: "Latest outlook",
            fullText: "Latest full text",
            day: 2,
            riskLevel: "ENH",
            issued: Date(timeIntervalSince1970: 1_000),
            validUntil: Date(timeIntervalSince1970: 2_500)
        )

        let olderPublicationButNewerIssue = ConvectiveOutlookDTO(
            title: "Day 1 Convective Outlook",
            link: URL(string: "https://example.com/day1")!,
            published: Date(timeIntervalSince1970: 1_000),
            summary: "Earlier outlook",
            fullText: "Earlier full text",
            day: 1,
            riskLevel: "SLGT",
            issued: Date(timeIntervalSince1970: 3_000),
            validUntil: Date(timeIntervalSince1970: 3_500)
        )

        let sorted = sortedConvectiveOutlooks([olderPublicationButNewerIssue, newerPublicationButOlderIssue])

        #expect(sorted.map(\.title) == [
            "Day 2 Convective Outlook",
            "Day 1 Convective Outlook"
        ])
    }
}

@Suite("ConvectiveOutlookDTO identity")
struct ConvectiveOutlookDTOIdentityTests {
    @Test("same link revisions keep distinct identities")
    func sameLinkRevisionsKeepDistinctIdentities() {
        let link = URL(string: "https://www.spc.noaa.gov/products/outlook/day1otlk.html")!
        let earlier = ConvectiveOutlookDTO(
            title: "Day 1 Convective Outlook",
            link: link,
            published: Date(timeIntervalSince1970: 1_700_000_000),
            summary: "Earlier summary",
            fullText: "Earlier full text",
            day: 1,
            riskLevel: "SLGT",
            issued: Date(timeIntervalSince1970: 1_700_000_000),
            validUntil: Date(timeIntervalSince1970: 1_700_000_600)
        )
        let later = ConvectiveOutlookDTO(
            title: "Day 1 Convective Outlook",
            link: link,
            published: Date(timeIntervalSince1970: 1_700_000_300),
            summary: "Later summary",
            fullText: "Later full text",
            day: 1,
            riskLevel: "SLGT",
            issued: Date(timeIntervalSince1970: 1_700_000_300),
            validUntil: Date(timeIntervalSince1970: 1_700_000_900)
        )

        #expect(earlier.id != later.id)
    }
}

@Suite("ConvectiveOutlookDetailPresentation")
struct ConvectiveOutlookDetailPresentationTests {
    @Test("all metadata present stays visible and truthful")
    func allMetadataPresent() {
        let validUntil = Date(timeIntervalSince1970: 1_700_000_000)
        let outlook = ConvectiveOutlookDTO(
            title: "Day 3 Convective Outlook",
            link: URL(string: "https://example.com/day3")!,
            published: Date(timeIntervalSince1970: 1_700_000_100),
            summary: "Summary",
            fullText: "Full text",
            day: 3,
            riskLevel: "SLGT",
            issued: Date(timeIntervalSince1970: 1_700_000_050),
            validUntil: validUntil
        )

        let presentation = ConvectiveOutlookDetailPresentation(outlook: outlook)

        #expect(presentation.headerTitle == "Day 3 Convective Outlook")
        #expect(presentation.navigationTitle == "Day 3 Outlook")
        #expect(presentation.metadataChips.count == 3)
        #expect(presentation.metadataChips.contains(where: { $0.icon == "calendar" && $0.title == "Day 3" }))
        #expect(presentation.metadataChips.contains(where: { $0.icon == "exclamationmark.triangle" && $0.title == "Slight" }))
        #expect(presentation.validUntil == validUntil)
    }

    @Test("missing day does not invent Day 1")
    func missingDayDoesNotInventDayOne() {
        let outlook = ConvectiveOutlookDTO(
            title: "Convective Outlook",
            link: URL(string: "https://example.com/dayless")!,
            published: Date(timeIntervalSince1970: 1_700_000_100),
            summary: "Summary",
            fullText: "Full text",
            day: nil,
            riskLevel: "ENH",
            issued: Date(timeIntervalSince1970: 1_700_000_050),
            validUntil: Date(timeIntervalSince1970: 1_700_000_900)
        )

        let presentation = ConvectiveOutlookDetailPresentation(outlook: outlook)

        #expect(presentation.headerTitle == "Convective Outlook")
        #expect(presentation.navigationTitle == "Outlook Details")
        #expect(presentation.metadataChips.contains(where: { $0.icon == "calendar" }) == false)
        #expect(presentation.metadataChips.contains(where: { $0.title == "Day 1" }) == false)
    }

    @Test("title-derived day remains visible when source metadata omits it")
    func derivesDayFromTitleWhenMetadataMissing() {
        let outlook = ConvectiveOutlookDTO(
            title: "Day 2 Convective Outlook",
            link: URL(string: "https://example.com/day2")!,
            published: Date(timeIntervalSince1970: 1_700_000_100),
            summary: "Summary",
            fullText: "Full text",
            day: nil,
            riskLevel: "ENH",
            issued: Date(timeIntervalSince1970: 1_700_000_050),
            validUntil: Date(timeIntervalSince1970: 1_700_000_900)
        )

        let presentation = ConvectiveOutlookDetailPresentation(outlook: outlook)

        #expect(presentation.headerTitle == "Day 2 Convective Outlook")
        #expect(presentation.navigationTitle == "Day 2 Outlook")
        #expect(presentation.metadataChips.contains(where: { $0.icon == "calendar" && $0.title == "Day 2" }))
    }

    @Test("missing valid-until does not reuse publication time")
    func missingValidUntilDoesNotReusePublicationTime() {
        let outlook = ConvectiveOutlookDTO(
            title: "Day 2 Convective Outlook",
            link: URL(string: "https://example.com/day2")!,
            published: Date(timeIntervalSince1970: 1_700_000_100),
            summary: "Summary",
            fullText: "Full text",
            day: 2,
            riskLevel: "MDT",
            issued: Date(timeIntervalSince1970: 1_700_000_050),
            validUntil: nil
        )

        let presentation = ConvectiveOutlookDetailPresentation(outlook: outlook)

        #expect(presentation.headerTitle == "Day 2 Convective Outlook")
        #expect(presentation.navigationTitle == "Day 2 Outlook")
        #expect(presentation.validUntil == nil)
    }

    @Test("missing day and valid-until render without placeholder metadata")
    func missingDayAndValidUntilRenderCleanly() {
        let outlook = ConvectiveOutlookDTO(
            title: "Convective Outlook",
            link: URL(string: "https://example.com/dayless")!,
            published: Date(timeIntervalSince1970: 1_700_000_100),
            summary: "Summary",
            fullText: "Full text",
            day: nil,
            riskLevel: nil,
            issued: Date(timeIntervalSince1970: 1_700_000_050),
            validUntil: nil
        )

        let presentation = ConvectiveOutlookDetailPresentation(outlook: outlook)

        #expect(presentation.metadataChips.count == 1)
        #expect(presentation.metadataChips.first?.icon == "clock.arrow.circlepath")
        #expect(presentation.metadataChips.first?.title.contains("Published") == true)
        #expect(presentation.validUntil == nil)
    }
}

@Suite("ConvectiveOutlookView presentation state")
@MainActor
struct ConvectiveOutlookViewPresentationStateTests {
    @Test("loading state wins while refresh is in flight and no outlooks are shown")
    func loadingStateWins() {
        #expect(
            ConvectiveOutlookPresentationState.resolve(
                dtos: [],
                refreshStatus: .loading
            ) == .loading
        )
    }

    @Test("confirmed empty stays distinct from unavailable")
    func confirmedEmptyStaysDistinct() {
        #expect(
            ConvectiveOutlookPresentationState.resolve(
                dtos: [],
                refreshStatus: .success(hasContent: false)
            ) == .empty(.current)
        )
    }

    @Test("failed refresh without cached content is unavailable")
    func failedRefreshWithoutContentIsUnavailable() {
        #expect(
            ConvectiveOutlookPresentationState.resolve(
                dtos: [],
                refreshStatus: .failed
            ) == .unavailable
        )
    }

    @Test("non-empty content stays populated")
    func nonEmptyContentIsPopulated() {
        #expect(
            ConvectiveOutlookPresentationState.resolve(
                dtos: [ConvectiveOutlook.sampleOutlookDtos[0]],
                refreshStatus: .failed
            ) == .populated(.failed)
        )
    }

    @Test("accepted cached rows stay visible while refreshing or offline")
    func acceptedRowsRetainActivity() {
        let outlooks = [ConvectiveOutlook.sampleOutlookDtos[0]]
        #expect(ConvectiveOutlookPresentationState.resolve(
            dtos: outlooks, refreshStatus: .loading
        ) == .populated(.refreshing))
        #expect(ConvectiveOutlookPresentationState.resolve(
            dtos: outlooks, refreshStatus: .success(hasContent: true), isOffline: true
        ) == .populated(.stale))
        #expect(ConvectiveOutlookPresentationState.resolve(
            dtos: outlooks, refreshStatus: .failed, isOffline: true
        ) == .populated(.failed))
    }

    @Test("accepted empty remains distinct while offline")
    func acceptedEmptyOffline() {
        #expect(ConvectiveOutlookPresentationState.resolve(
            dtos: [], refreshStatus: .success(hasContent: false), isOffline: true
        ) == .empty(.stale))
        #expect(ConvectiveOutlookPresentationState.resolve(
            dtos: [], refreshStatus: .failed, hasAcceptedEmptySnapshot: true
        ) == .empty(.failed))
    }

    @Test("offline cold start without accepted Outlook content is unavailable")
    func offlineColdStartIsUnavailable() {
        #expect(ConvectiveOutlookPresentationState.resolve(
            dtos: [], refreshStatus: .loading, isOffline: true
        ) == .unavailable)
    }

    @Test("an unaccepted empty result is unavailable")
    func unacceptedEmptyIsUnavailable() {
        #expect(ConvectiveOutlookPresentationState.resolve(
            dtos: [], refreshStatus: .stale
        ) == .unavailable)
        #expect(ConvectiveOutlookPresentationState.resolve(
            dtos: [], refreshStatus: .success(hasContent: true)
        ) == .unavailable)
    }
}

@Suite("Convective outlook day selection")
@MainActor
struct ConvectiveOutlookDayPresentationTests {
    @Test("cross-surface navigation chooses the latest accepted discussion for its day")
    func latestDiscussionUsesRequestedDay() {
        let collection = [
            outlook(day: 1, time: 500),
            outlook(day: 2, time: 400),
            outlook(day: 3, time: 300),
            outlook(day: 2, time: 100)
        ]

        #expect(ConvectiveOutlookView.navigationResolution(
            for: .day2,
            opensLatestDiscussion: true,
            dtos: [],
            refreshStatus: .loading,
            hasAcceptedEmptySnapshot: false,
            isOffline: false
        ) == .pending(.day2))
        #expect(ConvectiveOutlookView.navigationResolution(
            for: .day2,
            opensLatestDiscussion: true,
            dtos: collection,
            refreshStatus: .success(hasContent: true),
            hasAcceptedEmptySnapshot: false,
            isOffline: false
        ) == .resolved(day: .day2, path: [collection[1]]))
        #expect(ConvectiveOutlookView.navigationResolution(
            for: .day2,
            opensLatestDiscussion: true,
            dtos: [],
            refreshStatus: .failed,
            hasAcceptedEmptySnapshot: false,
            isOffline: false
        ) == .resolved(day: .day2, path: []))

        #expect(ConvectiveOutlookView.latestAcceptedOutlook(
            for: .day2,
            dtos: collection,
            refreshStatus: .success(hasContent: true),
            hasAcceptedEmptySnapshot: false,
            isOffline: false
        ) == collection[1])
        var navigationPath = [collection[0]]
        navigationPath = ConvectiveOutlookView.navigationPath(
            for: .day2,
            opensLatestDiscussion: true,
            dtos: collection,
            refreshStatus: .success(hasContent: true),
            hasAcceptedEmptySnapshot: false,
            isOffline: false
        )
        #expect(navigationPath == [collection[1]])
        navigationPath = ConvectiveOutlookView.navigationPath(
            for: .day3,
            opensLatestDiscussion: true,
            dtos: [collection[0]],
            refreshStatus: .success(hasContent: true),
            hasAcceptedEmptySnapshot: false,
            isOffline: false
        )
        #expect(navigationPath.isEmpty)
        navigationPath = ConvectiveOutlookView.navigationPath(
            for: .current,
            opensLatestDiscussion: true,
            dtos: collection,
            refreshStatus: .success(hasContent: true),
            hasAcceptedEmptySnapshot: false,
            isOffline: false
        )
        #expect(navigationPath.isEmpty)
        navigationPath = ConvectiveOutlookView.navigationPath(
            for: .day2,
            opensLatestDiscussion: false,
            dtos: collection,
            refreshStatus: .success(hasContent: true),
            hasAcceptedEmptySnapshot: false,
            isOffline: false
        )
        #expect(navigationPath.isEmpty)
        #expect(ConvectiveOutlookView.latestAcceptedOutlook(
            for: .day3,
            dtos: collection,
            refreshStatus: .success(hasContent: true),
            hasAcceptedEmptySnapshot: false,
            isOffline: false
        ) == collection[2])
        #expect(ConvectiveOutlookView.latestAcceptedOutlook(
            for: .day3,
            dtos: [collection[0]],
            refreshStatus: .success(hasContent: true),
            hasAcceptedEmptySnapshot: false,
            isOffline: false
        ) == nil)
        #expect(ConvectiveOutlookView.latestAcceptedOutlook(
            for: .day2,
            dtos: [collection[1], collection[3]],
            refreshStatus: .failed,
            hasAcceptedEmptySnapshot: false,
            isOffline: true
        ) == collection[1])
    }

    @Test("an initial pending navigation request is claimed once and later explicit requests remain distinct")
    func requestGateHandlesInitialAndRepeatedDelivery() {
        var gate = HomeTabNavigationRequestGate()
        let initialRequest = HomeTabNavigationRequest(destination: .map(day: .day2, layer: .categorical))
        let initialRequestWasClaimed = gate.claim(initialRequest.id)
        let duplicateInitialRequestWasClaimed = gate.claim(initialRequest.id)
        #expect(initialRequestWasClaimed)
        #expect(duplicateInitialRequestWasClaimed == false)

        let repeatedExplicitRequest = HomeTabNavigationRequest(destination: .map(day: .day2, layer: .categorical))
        let repeatedRequestWasClaimed = gate.claim(repeatedExplicitRequest.id)
        #expect(repeatedRequestWasClaimed)

        var pendingGate = HomeTabNavigationRequestGate()
        let pendingRequest = HomeTabNavigationRequest(destination: .outlooks(day: .day2, opensLatestDiscussion: true))
        pendingGate.markPending(pendingRequest.id)
        let unrelatedRequest = HomeTabNavigationRequest(destination: .map(day: .day1, layer: .categorical))
        let unrelatedCancellationSucceeded = pendingGate.cancelPending(unrelatedRequest.id)
        let matchingCancellationSucceeded = pendingGate.cancelPending(pendingRequest.id)
        let abandonedRequestWasReplayed = pendingGate.claim(pendingRequest.id)
        #expect(unrelatedCancellationSucceeded == false)
        #expect(matchingCancellationSucceeded)
        #expect(pendingGate.pendingRequestID == nil)
        #expect(abandonedRequestWasReplayed == false)
    }

    @Test("latest and earlier are scoped to the selected day", arguments: [SPCForecastDay.day1, .day2, .day3])
    func selectionScopesLatestAndEarlier(day: SPCForecastDay) {
        let collection = [outlook(day: 1, time: 500), outlook(day: 2, time: 400),
                          outlook(day: 3, time: 300), outlook(day: day.rawValue, time: 100),
                          outlook(day: nil, time: 900)]
        let displayed = HomeView.preferredOutlooks(
            cachedOutlooks: [], liveOutlooks: collection, refreshStatus: .success(hasContent: true)
        )
        #expect(displayed == collection)
        let selection = ConvectiveOutlookDayPresentation(
            day: day, collection: displayed, refreshStatus: .success(hasContent: true)
        )
        #expect(selection.state == .populated(.current))
        #expect(selection.outlooks.count == 2)
        #expect(selection.outlooks.allSatisfy { $0.day == day.rawValue })
        #expect(selection.outlooks.first?.published == rssTestNow.addingTimeInterval(Double(-400 - day.rawValue * 100)))
        #expect(selection.outlooks.last?.published == rssTestNow.addingTimeInterval(-900))
        #expect(selection.outlooks.first?.validUntil == rssTestNow.addingTimeInterval(2_000))
    }

    @Test("single-day cache preserves selected-day absence and refresh activity")
    func missingDayAndFailureWithCache() {
        let cached = [outlook(day: 2, time: 400)]
        for (status, offline, activity) in [
            (ConvectiveOutlookRefreshStatus.success(hasContent: true), false, ConvectiveOutlookPresentationState.Activity.current),
            (.loading, false, .refreshing), (.failed, false, .failed), (.stale, false, .stale),
            (.loading, true, .stale), (.failed, true, .failed)
        ] {
            let displayed = HomeView.preferredOutlooks(
                cachedOutlooks: cached, liveOutlooks: [], refreshStatus: status
            )
            for day in [SPCForecastDay.day1, .day2, .day3] {
                let selection = ConvectiveOutlookDayPresentation(
                    day: day, collection: displayed, refreshStatus: status, isOffline: offline
                )
                let missingState: ConvectiveOutlookPresentationState = status == .loading && !offline ? .loading : .unavailable
                #expect(selection.state == (day == .day2 ? .populated(activity) : missingState))
                #expect(selection.outlooks == (day == .day2 ? cached : []))
            }
        }
    }

    @Test("no accepted collection stays loading or unavailable; accepted empty stays empty")
    func emptyAndUnavailable() {
        for day in [SPCForecastDay.day1, .day2, .day3] {
            for (status, offline, expected) in [
                (ConvectiveOutlookRefreshStatus.loading, false, ConvectiveOutlookPresentationState.loading),
                (.loading, true, .unavailable), (.failed, false, .unavailable),
                (.success(hasContent: false), false, .empty(.current))
            ] {
                #expect(ConvectiveOutlookDayPresentation(
                    day: day, collection: [], refreshStatus: status, isOffline: offline
                ).state == expected)
            }
            #expect(ConvectiveOutlookDayPresentation(
                day: day, collection: [], refreshStatus: .failed,
                hasAcceptedEmptySnapshot: true, isOffline: true
            ).state == .empty(.failed))
        }
    }

    private func outlook(day: Int?, time: Int) -> ConvectiveOutlookDTO {
        ConvectiveOutlookDTO(
            title: day.map { "Day \($0) Convective Outlook \(time)" } ?? "Convective Outlook",
            link: URL(string: "https://example.com/outlook")!,
            published: rssTestNow.addingTimeInterval(Double(time - 1000)), summary: "Summary", fullText: "Discussion",
            day: day, riskLevel: nil, issued: nil, validUntil: rssTestNow.addingTimeInterval(2_000)
        )
    }
}

private struct CurrentDiscussionClient: SpcClient {
    var rss: HTTPResponse? = nil
    var pages: [Int: HTTPResponse] = [:]

    func fetchRssData(for product: RssProduct) async throws -> Data {
        guard let data = rss?.data else { throw SpcError.missingData }
        return data
    }
    func fetchRssResponse(for product: RssProduct) async throws -> HTTPResponse {
        guard let rss else { throw SpcError.networkError(status: 503) }
        return rss
    }
    func fetchCurrentOutlookResponse(for day: SPCForecastDay) async throws -> HTTPResponse {
        guard let response = pages[day.rawValue] else { throw SpcError.networkError(status: 404) }
        return response
    }
    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data { throw SpcError.missingData }
}

@Suite("SPC current discussion acquisition", .serialized)
struct SPCCurrentDiscussionTests {
    private let now = Date(timeIntervalSince1970: floor(Date.now.timeIntervalSince1970 / 60) * 60 - 60)

    private func page(_ day: Int, issued: Date? = nil, rolloverHours: Double = 0) -> Data {
        // Captured official <pre> bodies below; shift only their clock headers to keep tests deterministic over time.
        let source = capturedSPCDiscussions[day - 1]
        let issue = issued ?? now.addingTimeInterval(Double(-day) * 3600)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Chicago")
        formatter.dateFormat = "hhmm a z EEE MMM dd yyyy"
        let issuePattern = #"\d{4} [AP]M [A-Z]{3} [A-Za-z]{3} [A-Za-z]{3} \d{2} \d{4}"#
        let stamped = source.replacingOccurrences(of: issuePattern, with: formatter.string(from: issue), options: .regularExpression)
        formatter.timeZone = .gmt
        formatter.dateFormat = "ddHHmm'Z'"
        let start = now.addingTimeInterval((Double(day - 1) * 24 - 1 + rolloverHours) * 3600)
        let end = start.addingTimeInterval(24 * 3600)
        let validity = "Valid \(formatter.string(from: start)) - \(formatter.string(from: end))"
        return Data(stamped.replacingOccurrences(of: #"Valid \d{6}Z - \d{6}Z"#, with: validity, options: .regularExpression).utf8)
    }

    private func response(_ data: Data, source: HTTPResponse.Source = .live) -> HTTPResponse {
        HTTPResponse(status: 200, headers: [:], data: data, source: source)
    }

    private func dayOneRSS(_ issued: Date? = nil) throws -> HTTPResponse {
        let item = try SPCDiscussionAcceptance.parseCurrent(page(1, issued: issued), day: .day1)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return response(Data("""
        <rss><channel><item><title>SPC Day 1 Convective Outlook</title>
        <link>https://www.spc.noaa.gov/products/outlook/day1otlk.html</link>
        <pubDate>\(formatter.string(from: item.published))</pubDate>
        <description><![CDATA[\(item.fullText)]]></description></item></channel></rss>
        """.utf8))
    }

    private func provider(_ container: ModelContainer, _ client: any SpcClient) -> SpcProvider {
        SpcProvider(
            outlookRepo: ConvectiveOutlookRepo(modelContainer: container), mesoRepo: MesoRepo(modelContainer: container),
            alertRepo: AlertRepo(modelContainer: container), stormRiskRepo: StormRiskRepo(modelContainer: container),
            severeRiskRepo: SevereRiskRepo(modelContainer: container), fireRiskRepo: FireRiskRepo(modelContainer: container),
            spcMapBatchPersistenceRepo: SpcMapBatchPersistenceRepo(modelContainer: container), client: client
        )
    }

    @Test("current pages bootstrap all days, partial RSS preserves them, and failures/restart preserve accepted text")
    func acquisition_partialUpdate_failure_restart() async throws {
        let (container, directory) = try await MainActor.run { try makeDiskContainer(for: [ConvectiveOutlook.self]) }
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = CurrentDiscussionClient(rss: try dayOneRSS(), pages: [1: response(page(1)), 2: response(page(2)), 3: response(page(3))])
        let spc = provider(container, client)
        #expect(await spc.syncConvectiveOutlooks() == .live)
        let initial = try await spc.getConvectiveOutlookSnapshot()
        #expect(Set(initial.outlooks.compactMap(\.day)) == [1, 2, 3])
        #expect(initial.outlooks.count == 3) // RSS and the current page share the same Day 1 issuance.

        let partial = provider(container, CurrentDiscussionClient(rss: try dayOneRSS(now)))
        #expect(await partial.syncConvectiveOutlooks() == .live)
        let updated = try await partial.getConvectiveOutlookSnapshot()
        #expect(updated.outlooks.filter { $0.day == 1 }.count == 2)
        #expect(updated.outlooks.filter { $0.day == 2 } == initial.outlooks.filter { $0.day == 2 })
        #expect(updated.outlooks.filter { $0.day == 3 } == initial.outlooks.filter { $0.day == 3 })
        #expect(await provider(container, CurrentDiscussionClient()).syncConvectiveOutlooks() == .failed)
        let rejected = CurrentDiscussionClient(pages: [2: response(Data("<pre>invalid</pre>".utf8))])
        #expect(await provider(container, rejected).syncConvectiveOutlooks() == .failed)
        let fallback = CurrentDiscussionClient(pages: [2: response(page(2, issued: now), source: .cacheFallback)])
        #expect(await provider(container, fallback).syncConvectiveOutlooks() == .errorFallback)
        #expect(try await partial.getConvectiveOutlookSnapshot() == updated)

        let reopened = try await MainActor.run { try ModelContainer(
            for: ConvectiveOutlook.self,
            configurations: ModelConfiguration("ConvectiveOutlookRepoTests", url: directory.appendingPathComponent("SkyAware.sqlite"))
        ) }
        let restored = provider(reopened, CurrentDiscussionClient())
        #expect(try await restored.getConvectiveOutlookSnapshot() == updated)
        let home = try await HomeSnapshotStore(
            spcRisk: restored, spcOutlook: restored,
            arcusAlerts: StubArcusAlertQuerying(activeWarnings: .success([])),
            arcusMesos: StubArcusMesoQuerying(mesos: .success([]))
        ).loadSnapshot(for: nil, weather: nil, freshness: .init(), refreshMesos: false)
        for day in [SPCForecastDay.day1, .day2, .day3] {
            let presentation = ConvectiveOutlookDayPresentation(day: day, collection: home.outlooks, refreshStatus: .failed)
            #expect(presentation.state == .populated(.failed))
            #expect(presentation.outlooks.count == (day == .day1 ? 2 : 1))
            #expect(presentation.outlooks.allSatisfy { $0.day == day.rawValue && $0.validUntil != nil })
        }
    }

    @Test("new issuance, bounded earlier text, out-of-order acceptance, and forecast rollover remain day scoped")
    func issuance_rollover_and_bounds() async throws {
        let (container, directory) = try await MainActor.run { try makeDiskContainer(for: [ConvectiveOutlook.self]) }
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = ConvectiveOutlookRepo(modelContainer: container)
        for index in 0..<15 {
            let issue = now.addingTimeInterval(Double(index - 16) * 60)
            _ = try await repo.refreshConvectiveOutlooks(using: CurrentDiscussionClient(pages: [2: response(page(2, issued: issue))]), asOf: now)
        }
        let retained = try await repo.collectionSnapshot(asOf: now).outlooks
        #expect(retained.count == 12)
        #expect(retained.map(\.published) == retained.map(\.published).sorted(by: >))
        // The older run stages its response first, then a newer run commits during its final await.
        let old = CurrentDiscussionClient(pages: [2: response(page(2, issued: now.addingTimeInterval(-1800)))])
        let newer = CurrentDiscussionClient(pages: [2: response(page(2, issued: now, rolloverHours: 24))])
        _ = try await repo.refreshConvectiveOutlooks(using: old, asOf: now) {
            _ = try? await repo.refreshConvectiveOutlooks(using: newer, asOf: now)
            return true
        }
        let rolled = try await repo.collectionSnapshot(asOf: now).outlooks
        #expect(rolled.count == 1)
        #expect(rolled.first?.issued == now)
        #expect(rolled.first?.day == 2)
        // Reads retire expired content before scheduled cleanup; purge persists that retirement.
        let expiredAt = now.addingTimeInterval(72 * 3600)
        #expect(try await repo.collectionSnapshot(asOf: expiredAt) == .unavailable)
        let expiredPresentation = ConvectiveOutlookDayPresentation(
            day: .day2, collection: rolled, refreshStatus: .success(hasContent: true), asOf: expiredAt
        )
        #expect(expiredPresentation.outlooks.isEmpty)
        #expect(expiredPresentation.state == .unavailable)
        try await repo.purge(asOf: expiredAt)
        #expect(try await repo.collectionSnapshot(asOf: expiredAt) == .unavailable)
    }

    @Test("missing products stay absent; valid Day 3 survives an old Day 1 purge; metadata-free rows expire in 48 hours")
    func missingProduct_and_retention() async throws {
        let (container, directory) = try await MainActor.run { try makeDiskContainer(for: [ConvectiveOutlook.self]) }
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = ConvectiveOutlookRepo(modelContainer: container)
        _ = try await repo.refreshConvectiveOutlooks(using: CurrentDiscussionClient(rss: try dayOneRSS(), pages: [3: response(page(3))]), asOf: now)
        #expect(try await repo.fetchConvectiveOutlooks(for: 2, asOf: now).isEmpty)
        let future = now.addingTimeInterval(49 * 3600)
        try await repo.purge(asOf: future)
        #expect(try await repo.fetchConvectiveOutlooks(for: 1, asOf: future).isEmpty)
        #expect(try await repo.fetchConvectiveOutlooks(for: 3, asOf: future).count == 1)
        _ = try await repo.refreshConvectiveOutlooks(using: FakeSpcClient(mode: .success(Data(sampleValidRSS.utf8))), asOf: rssTestNow)
        #expect(try await repo.fetchConvectiveOutlooks(for: 2, asOf: rssTestNow).count == 1)
        #expect(try await repo.fetchConvectiveOutlooks(for: 2, asOf: rssTestNow.addingTimeInterval(49 * 3600)).isEmpty)
    }

    @Test("legacy disk rows reconstruct source validity instead of displaying an incorrectly anchored cached date")
    func legacyValidityMetadata() async throws {
        let (container, directory) = try await MainActor.run { try makeDiskContainer(for: [ConvectiveOutlook.self]) }
        defer { try? FileManager.default.removeItem(at: directory) }
        let parsed = try SPCDiscussionAcceptance.parseCurrent(page(3), day: .day3)
        try await MainActor.run {
            let row = ConvectiveOutlook(
                title: parsed.title, link: parsed.link, published: parsed.published,
                fullText: parsed.fullText, summary: parsed.summary, day: 3, riskLevel: nil,
                issued: parsed.issued, validUntil: now.addingTimeInterval(30 * 86400)
            )
            container.mainContext.insert(row)
            container.mainContext.insert(ConvectiveOutlook.collectionMarker(published: parsed.published))
            try container.mainContext.save()
        }
        let snapshot = try await ConvectiveOutlookRepo(modelContainer: container).collectionSnapshot(asOf: now)
        #expect(snapshot.outlooks.count == 1)
        #expect(snapshot.outlooks.first?.validUntil == parsed.validUntil)
    }

    @Test("captured SPC current products expose distinct issue and validity dates, including month/year rollover")
    func sourceMetadata() throws {
        let parser = OutlookParser()
        for day in 1...3 {
            let dto = try SPCDiscussionAcceptance.parseCurrent(Data(capturedSPCDiscussions[day - 1].utf8), day: SPCForecastDay(rawValue: day)!)
            #expect(dto.day == day)
            #expect(dto.issued == parser.extractIssuedDate(dto.fullText))
            let issued = try #require(dto.issued)
            let expiry = try #require(dto.validUntil)
            #expect(expiry > issued)
            #expect(issued.ISO8601Format() == ["2026-10-19T00:44:00Z", "2026-10-18T16:58:00Z", "2026-10-18T19:07:00Z"][day - 1])
            #expect(expiry.ISO8601Format() == ["2026-10-19T12:00:00Z", "2026-10-20T12:00:00Z", "2026-10-21T12:00:00Z"][day - 1])
            #expect(dto.published == issued)
        }
        let issued = try #require("1158 PM CST Thu Dec 31 2026".parseAsIssuedDate())
        let interval = try #require(SPCDiscussionAcceptance.validity(in: "Valid 011200Z - 021200Z", issued: issued))
        #expect(interval.start.ISO8601Format() == "2027-01-01T12:00:00Z")
        #expect(interval.end.ISO8601Format() == "2027-01-02T12:00:00Z")
        #expect(SPCDiscussionAcceptance.validity(in: "Valid 012400Z - 021200Z", issued: issued) == nil)
    }
}

// Official https://www.spc.noaa.gov/products/outlook/day{1,2,3}otlk.html, captured 2026-10-19 UTC.
private let capturedSPCDiscussions: [String] = [
    #"""
    <html><pre>
    SPC AC 190044

       Day 1 Convective Outlook
       NWS Storm Prediction Center Norman OK
       0744 PM CDT Sun Oct 18 2026

       Valid 190100Z - 191200Z

       ...NO SEVERE THUNDERSTORM AREAS FORECAST...

       ...SUMMARY...
       Severe thunderstorms are not forecast across the U.S. through
       tonight.

       ...DISCUSSION...
       An upper-level ridge will move eastward into the southern
       Appalachians tonight, as southwesterly flow at mid-levels remains in
       place across much of the western and central U.S. At the surface, a
       large area of high pressure will remain entrenched from the Gulf
       Coast states to the Northeast. As a result, dry and cool conditions
       will remain over much of the continental U.S. Isolated thunderstorms
       will be possible over south Florida and in parts of the Desert
       Southwest, but no severe threat is forecast this evening through
       tonight.

       ..Broyles.. 10/19/2026

       CLICK TO GET <a href="archive/2026/KWNSPTSDY1_202610190100.txt">WUUS01 PTSDY1</a> PRODUCT

       NOTE: THE NEXT DAY 1 OUTLOOK IS SCHEDULED BY 0600Z
    <script type="text/javascript" src="/misc/utctime.js"></script>
    </pre></html>
    """#,
    #"""
    <html><pre>
    SPC AC 181658

       Day 2 Convective Outlook
       NWS Storm Prediction Center Norman OK
       1158 AM CDT Sun Oct 18 2026

       Valid 191200Z - 201200Z

       ...NO SEVERE THUNDERSTORM AREAS FORECAST...

       ...SUMMARY...
       Severe thunderstorms are not expected on Monday.

       ...Synopsis...
       An upper low will linger off the East Coast while an upper trough
       amplifies just off the West Coast. Meanwhile, a leading wave will
       affect the area from Baja CA into the Four Corners states.

       Instability will be minimal over most of the CONUS due to an area of
       high pressure, with the surface ridge extending from the Great
       Lakes/Upper Midwest to the Gulf Coast. The exceptions will be near
       the FL Keys where moist easterly winds will persist, supporting
       scattered showers and a few thunderstorms, and over AZ and NM, where
       midlevel moisture will support weak instability. In either case,
       severe weather is not anticipated due to weak instability.

       ..Jewell.. 10/18/2026

       CLICK TO GET <a href="archive/2026/KWNSPTSDY2_202610181730.txt">WUUS02 PTSDY2</a> PRODUCT

       NOTE: THE NEXT DAY 2 OUTLOOK IS SCHEDULED BY 0600Z
    <script type="text/javascript" src="/misc/utctime.js"></script>
    </pre></html>
    """#,
    #"""
    <html><pre>
    SPC AC 181907

       Day 3 Convective Outlook
       NWS Storm Prediction Center Norman OK
       0207 PM CDT Sun Oct 18 2026

       Valid 201200Z - 211200Z

       ...NO SEVERE THUNDERSTORM AREAS FORECAST...

       ...SUMMARY...
       No severe thunderstorms are expected on Tuesday.

       ...Synopsis...
       A large upper trough is forecast to amplify just off the CA coast,
       with increasing south/southwest winds aloft, as well as cooling
       aloft near the coast overnight. To the east, minor height rises will
       occur over the Plains, while an upper low meanders off the Mid
       Atlantic coast.

       At the surface, high pressure over the Upper Great Lakes and Ontario
       will shift eastward, though the surface ridge will remain entrenched
       into the Southern Plains. This will maintain stable conditions over
       the central and eastern states.

       General thunderstorm chances will be limited to parts of the
       southwestern states in relation to the upper trough. Veering winds
       with height and moderate deep-layer shear will develop over AZ and
       NM as the upper trough amplified. However, forecast soundings show a
       subsidence inversion above 500 mb during the day, which will limit
       storm intensity. Overnight, elevated instability may increase as
       cooling aloft occurs, with isolated storms still possible. Potential
       should generally increase into Wednesday/D4 as the upper trough
       strengthens.

       ..Jewell.. 10/18/2026

       CLICK TO GET <a href="archive/2026/KWNSPTSDY3_202610181930.txt">WUUS03 PTSDY3</a> PRODUCT

       NOTE: THE NEXT DAY 3 OUTLOOK IS SCHEDULED BY 0730Z
    <script type="text/javascript" src="/misc/utctime.js"></script>
    </pre></html>
    """#,
]
