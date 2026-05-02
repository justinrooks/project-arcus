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
            return "Update unavailable"
        case .fresh:
            guard let timestamp = freshness.timestamp else {
                return "Updated just now"
            }
            return "Updated \(formatter.string(from: timestamp))"
        case .stale:
            guard let timestamp = freshness.timestamp else {
                return "Data may be stale"
            }
            return "Stale since \(formatter.string(from: timestamp))"
        }
    }
}
