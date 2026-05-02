import SwiftUI
import WidgetKit

@main
struct SkyAwareWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SkyAwarePlaceholderWidget()
    }
}

struct SkyAwarePlaceholderWidget: Widget {
    private let kind = SkyAwareWidgetKind.placeholder

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SkyAwarePlaceholderWidgetView(entry: entry)
        }
        .configurationDisplayName("SkyAware")
        .description("Placeholder widget used to validate target plumbing.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: WidgetPreviewFixtures.normal)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snapshot: WidgetPreviewFixtures.normal))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let timeline = Timeline(entries: [Entry(date: .now, snapshot: WidgetPreviewFixtures.normal)], policy: .never)
        completion(timeline)
    }
}

private struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

private struct SkyAwarePlaceholderWidgetView: View {
    let entry: Entry

    var body: some View {
        WidgetRenderingPreviewCard(snapshot: entry.snapshot)
    }
}
