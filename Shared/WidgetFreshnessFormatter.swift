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
            return "unavailable"
        case .fresh:
            guard let timestamp = freshness.timestamp else {
                return "As of just now"
            }
            return "As of \(formatter.string(from: timestamp))"
        case .stale:
            guard let timestamp = freshness.timestamp else {
                return "Delayed update"
            }
            return "Delayed update · \(formatter.string(from: timestamp))"
        }
    }

    static func lineSuppressingStaleState(for freshness: WidgetFreshnessState) -> String? {
        guard freshness.state != .stale else { return nil }
        return line(for: freshness)
    }
}
