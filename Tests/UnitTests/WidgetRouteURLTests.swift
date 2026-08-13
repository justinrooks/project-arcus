import Foundation
import Testing
@testable import SkyAware

@Suite("Widget route URL")
struct WidgetRouteURLTests {
    @Test("builds summary URL for widget destination")
    func buildsSummaryURL() {
        let url = WidgetRouteURL.url(for: .summary)

        #expect(url.absoluteString == "skyaware://widget/summary")
    }

    @Test("parses summary destination from widget URL")
    func parsesSummaryDestination() throws {
        let url = try #require(URL(string: "skyaware://widget/summary"))

        #expect(WidgetRouteURL.destination(from: url) == .summary)
    }

    @Test("rejects non-widget URLs")
    func rejectsNonWidgetURL() throws {
        let url = try #require(URL(string: "skyaware://alerts/detail"))

        #expect(WidgetRouteURL.destination(from: url) == nil)
    }

    @Test("summary route maps to today tab fallback")
    func summaryRouteMapsToTodayTab() throws {
        let url = try #require(URL(string: "skyaware://widget/summary"))

        #expect(HomeView.tabSelection(forIncomingURL: url) == .today)
    }

    @Test("unknown route does not change tab")
    func unknownRouteDoesNotChangeTab() throws {
        let url = try #require(URL(string: "skyaware://widget/unknown"))

        #expect(HomeView.tabSelection(forIncomingURL: url) == nil)
    }
}

@Suite("Web content policy")
struct WebContentPolicyTests {
    @Test("allows an exact trusted host in-app")
    func allowsExactTrustedHostInApp() throws {
        let url = try #require(URL(string: "https://weather.gov"))

        #expect(WebContentPolicy.decision(for: url) == .inApp)
        #expect(WebContentPolicy.canOpenInApp(url))
    }

    @Test("allows trusted source URLs in-app")
    func allowsTrustedSourceURLInApp() throws {
        let url = try #require(URL(string: "https://www.spc.noaa.gov/products/outlook/day1otlk.html"))

        #expect(WebContentPolicy.decision(for: url) == .inApp)
        #expect(WebContentPolicy.canOpenInApp(url))
    }

    @Test("allows an intended trusted subdomain in-app")
    func allowsTrustedSubdomainInApp() throws {
        let url = try #require(URL(string: "https://api.weather.gov/alerts/123"))

        #expect(WebContentPolicy.decision(for: url) == .inApp)
        #expect(WebContentPolicy.canOpenInApp(url))
    }

    @Test("routes unrelated web hosts externally")
    func routesUnrelatedWebHostExternally() throws {
        let url = try #require(URL(string: "https://example.com/reference"))

        #expect(WebContentPolicy.decision(for: url) == .external)
        #expect(WebContentPolicy.canOpenInApp(url) == false)
    }

    @Test("rejects deceptive lookalike hosts")
    func rejectsDeceptiveLookalikeHost() throws {
        let url = try #require(URL(string: "https://weather.gov.example.com/reference"))

        #expect(WebContentPolicy.decision(for: url) == .external)
        #expect(WebContentPolicy.canOpenInApp(url) == false)
    }

    @Test("rejects malformed web URL")
    func rejectsMalformedWebURL() throws {
        let url = try #require(URL(string: "https:///missing-host"))

        #expect(WebContentPolicy.decision(for: url) == .unsupported)
        #expect(WebContentPolicy.canOpenInApp(url) == false)
    }

    @Test("routes non-web schemes externally")
    func routesNonWebSchemesExternally() throws {
        let mail = try #require(URL(string: "mailto:help@skyaware.app"))
        let phone = try #require(URL(string: "tel:+13035551234"))

        #expect(WebContentPolicy.decision(for: mail) == .external)
        #expect(WebContentPolicy.decision(for: phone) == .external)
        #expect(WebContentPolicy.canOpenInApp(mail) == false)
        #expect(WebContentPolicy.canOpenInApp(phone) == false)
    }

    @Test("supports deterministic route values")
    func routeSupportsDeterministicValues() throws {
        let url = try #require(URL(string: "https://www.weather.gov"))
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let route = WebContentRoute(id: id, url: url, title: "NWS", sourceName: "National Weather Service")

        #expect(route.id == id)
        #expect(route.url == url)
        #expect(route.title == "NWS")
        #expect(route.sourceName == "National Weather Service")
    }
}
