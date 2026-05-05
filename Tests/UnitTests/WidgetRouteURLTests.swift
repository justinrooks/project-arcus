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
