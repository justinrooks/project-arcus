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
    @Test("allows https URLs in-app")
    func allowsHTTPSInApp() throws {
        let url = try #require(URL(string: "https://www.spc.noaa.gov/products/outlook/day1otlk.html"))

        #expect(WebContentPolicy.decision(for: url) == .inApp)
        #expect(WebContentPolicy.canOpenInApp(url))
    }

    @Test("allows http URLs in-app")
    func allowsHTTPInApp() throws {
        let url = try #require(URL(string: "http://example.com/reference"))

        #expect(WebContentPolicy.decision(for: url) == .inApp)
        #expect(WebContentPolicy.canOpenInApp(url))
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
