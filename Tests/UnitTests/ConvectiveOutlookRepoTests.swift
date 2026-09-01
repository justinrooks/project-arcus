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

private enum TestError: Error { case boom }

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

    @Test("refresh inserts parsed outlooks and filters titles containing ' Convective Outlook'")
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
        let container = try await MainActor.run { try TestStore.container(for: [ConvectiveOutlook.self]) }
        try await MainActor.run { try TestStore.reset(ConvectiveOutlook.self, in: container) }
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

        // Only the recent item should remain
        let remaining = try await repo.fetchConvectiveOutlooks(for: 1)
        #expect(remaining.count == 1)
        #expect(remaining[0].title.contains("Recent"))
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
    var requests: [(url: URL, headers: [String: String])] = []

    func record(url: URL, headers: [String: String]) {
        requests.append((url: url, headers: headers))
    }

    func firstRequest() -> (url: URL, headers: [String: String])? {
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

    func get(_ url: URL, headers: [String : String]) async throws -> HTTPResponse {
        await state.record(url: url, headers: headers)
        if let error { throw error }
        return response
    }
    
    func post(_ url: URL, headers: [String : String], body: Data?) async throws -> HTTPResponse {
        await state.record(url: url, headers: headers)
        if let error { throw error }
        return response
    }

    func clearCache() {}

    func firstRequest() async -> (url: URL, headers: [String: String])? {
        await state.firstRequest()
    }
}

@Suite("SpcHttpClient")
struct SpcHttpClientTests {
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
            ) == .empty
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
            ) == .populated
        )
    }
}
