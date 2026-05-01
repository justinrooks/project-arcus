import SwiftUI
import WidgetKit

@main
struct SkyAwareWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SkyAwarePlaceholderWidget()
    }
}

struct SkyAwarePlaceholderWidget: Widget {
    private let kind = "SkyAwarePlaceholderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SkyAwarePlaceholderWidgetView(entry: entry)
        }
        .configurationDisplayName("SkyAware")
        .description("Placeholder widget used to validate target plumbing.")
        .supportedFamilies([.systemSmall])
    }
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let timeline = Timeline(entries: [Entry(date: .now)], policy: .never)
        completion(timeline)
    }
}

private struct Entry: TimelineEntry {
    let date: Date
}

private struct SkyAwarePlaceholderWidgetView: View {
    let entry: Entry

    var body: some View {
        Text("SkyAware")
            .font(.headline)
    }
}
