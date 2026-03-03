//
//  ActiveAlertSummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/8/25.
//

import SwiftUI

struct ActiveAlertSummaryView: View {
    let mesos: [MdDTO]
    let watches: [WatchRowDTO]
    let isLoading: Bool
    private let sortedMesos: [MdDTO]
    private let sortedWatches: [WatchRowDTO]
    
    @State private var selectedMeso: MdDTO? = nil
    @State private var selectedWatch: WatchRowDTO? = nil
    @State private var mesoSheetHeight: CGFloat = .zero
    @State private var watchSheetHeight: CGFloat = .zero

    init(mesos: [MdDTO], watches: [WatchRowDTO], isLoading: Bool = false) {
        self.mesos = mesos
        self.watches = watches
        self.isLoading = isLoading
        self.sortedMesos = mesos.sorted { $0.validEnd < $1.validEnd }
        self.sortedWatches = watches.sorted { $0.expires < $1.expires }
    }

    @ViewBuilder
    private var alertsContent: some View {
        ActiveAlertSection(
            label: "Watches",
            items: sortedWatches,
            limit: 3,
            onSelect: { selectedWatch = $0 }
        ) { watch in
            WatchRowView(watch: watch)
        }

        ActiveAlertSection(
            label: "Mesos",
            items: sortedMesos,
            limit: 3,
            onSelect: { selectedMeso = $0 }
        ) { meso in
            MesoRowView(meso: meso)
        }
    }

    @ViewBuilder
    private var placeholderAlertsContent: some View {
        PlaceholderAlertSection(label: "Watches")
        PlaceholderAlertSection(label: "Mesos")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Local Alerts", systemImage: "exclamationmark.triangle.fill")
                .sectionLabel()

            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 12) {
                    if isLoading {
                        placeholderAlertsContent
                    } else {
                        alertsContent
                    }
                }
            } else {
                if isLoading {
                    placeholderAlertsContent
                } else {
                    alertsContent
                }
            }
        }
        .padding(18)
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
        .placeholder(isLoading)
        .sheet(item: $selectedMeso) { meso in
            sheetContent(height: $mesoSheetHeight) {
                MesoscaleDiscussionCard(meso: meso, layout: .sheet)
                    .padding(.top, 8)
                    .padding(.horizontal, 6)
            }
        }
        .sheet(item: $selectedWatch) { watch in
            sheetContent(height: $watchSheetHeight) {
                WatchDetailView(watch: watch, layout: .sheet)
                    .padding(.top, 8)
                    .padding(.horizontal, 6)
            }
        }
    }

    @ViewBuilder
    private func sheetContent<Content: View>(
        height: Binding<CGFloat>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            ScrollView {
                content()
            }
            .background(.skyAwareBackground)
            .getHeight(for: height)
            .presentationDetents([.height(height.wrappedValue)])
            .presentationDragIndicator(.visible)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: Components
private struct PlaceholderAlertSection: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .skyAwareChip(cornerRadius: SkyAwareRadius.chip, tint: .white.opacity(0.09))

        ForEach(0..<2, id: \.self) { _ in
            HStack(alignment: .top, spacing: 15) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Placeholder alert title")
                        .font(.subheadline.weight(.semibold))
                    Text("Additional placeholder context")
                        .font(.caption)
                }

                Spacer()
                Text("Until 00:00 pm")
                    .monospacedDigit()
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .skyAwareChip(cornerRadius: SkyAwareRadius.chip, tint: .white.opacity(0.09))
            }
            .padding(.vertical, 3)
        }
    }
}

private struct ActiveAlertSection<Item: Identifiable, Row: View>: View {
    let label: String
    let items: [Item]
    let limit: Int
    let onSelect: (Item) -> Void
    @ViewBuilder let row: (Item) -> Row
    
    var body: some View {
        if !items.isEmpty {
            let visibleItems = items.prefix(limit)
            
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .skyAwareChip(cornerRadius: SkyAwareRadius.chip, tint: .white.opacity(0.09))
            
            ForEach(visibleItems) { item in
                Button { onSelect(item) } label: { row(item) }
                    .buttonStyle(.plain)
            }
            
            if items.count > visibleItems.count {
                Text("Showing \(visibleItems.count) of \(items.count) \(label.lowercased())")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MesoRowView: View {
    let meso: MdDTO
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            let (icon, color) = styleForType(.mesoscale, "")
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text("Meso \(meso.number.formatted(.number.grouping(.never)))")
                    .font(.subheadline.weight(.semibold))
            }
            
            Spacer()
            VStack(alignment: .trailing) {
                Text("Watch \(Int(meso.watchProbability))%")
                    .monospacedDigit()
                    .font(.caption.weight(.semibold))
                Text("Ends \(meso.validEnd, style: .time)")
                    .monospacedDigit()
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .skyAwareChip(cornerRadius: SkyAwareRadius.chip, tint: color.opacity(0.16))
        }
        .padding(.vertical, 3)
    }
}

private struct WatchRowView: View {
    let watch: WatchRowDTO
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            let (icon, color) = styleForType(.watch, watch.title)
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(watch.title)")
                    .font(.subheadline.weight(.semibold))
            }
            
            Spacer()
            VStack(alignment: .trailing) {
                let txt = buildDisplay(watch: watch)
                Text("Until \(txt) \(watch.validEnd, style: .time)")
                    .monospacedDigit()
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .skyAwareChip(cornerRadius: SkyAwareRadius.chip, tint: color.opacity(0.16))
        }
        .padding(.vertical, 3)
    }

    private func buildDisplay(watch: WatchRowDTO) -> String {
        Self.dayFormatter.string(from: watch.validEnd)
    }
}

#Preview {
    NavigationStack {
        ActiveAlertSummaryView(mesos: MD.sampleDiscussionDTOs, watches: Watch.sampleWatchRows)
            .toolbar(.hidden, for: .navigationBar)
            .background(.skyAwareBackground)
            .environment(\.dependencies, Dependencies.unconfigured)
    }
}
