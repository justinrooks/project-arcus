import Foundation

enum WidgetRouteURL {
    static let scheme = "skyaware"
    static let host = "widget"

    static func url(for destination: WidgetSummaryDestination) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path(for: destination)
        return components.url ?? URL(string: "skyaware://widget/summary")!
    }

    static func destination(from url: URL) -> WidgetSummaryDestination? {
        guard url.scheme?.localizedLowercase == scheme else {
            return nil
        }

        guard url.host?.localizedLowercase == host else {
            return nil
        }

        switch normalizedPath(url.path) {
        case "summary":
            return .summary
        default:
            return nil
        }
    }

    private static func path(for destination: WidgetSummaryDestination) -> String {
        switch destination {
        case .summary:
            return "/summary"
        }
    }

    private static func normalizedPath(_ path: String) -> String {
        path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .localizedLowercase
    }
}
