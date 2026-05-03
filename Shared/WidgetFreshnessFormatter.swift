import Foundation

enum WidgetFreshnessFormatter {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static func line(for freshness: WidgetFreshnessState) -> String {
        switch freshness.state {
        case .unavailable:
            return "As of now: unavailable"
        case .fresh:
            guard let timestamp = freshness.timestamp else {
                return "As of just now"
            }
            return "As of \(formatter.string(from: timestamp))"
        case .stale:
            guard let timestamp = freshness.timestamp else {
                return "As of earlier"
            }
            return "As of \(formatter.string(from: timestamp)) · may be stale"
        }
    }
}
