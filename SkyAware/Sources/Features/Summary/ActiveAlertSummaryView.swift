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
    
    @State private var selectedMeso: MdDTO? = nil
    @State private var selectedWatch: WatchRowDTO? = nil
    @State private var mesoSheetHeight: CGFloat = .zero
    @State private var watchSheetHeight: CGFloat = .zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // MARK: Header
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.skyAwareAccent)
                Text("Local Alerts")
                    .font(.headline)
                    .foregroundColor(.skyAwareAccent)
                Spacer()
            }
            
            // MARK: Active Alerts
            VStack(alignment: .leading, spacing: 15) {
                ActiveAlertSection(
                    label: "Watches",
                    items: watches,
                    limit: 3,
                    sort: { $0.expires < $1.expires },
                    onSelect: { selectedWatch = $0 }
                ) { watch in
                    WatchRowView(watch: watch)
                }
                
                ActiveAlertSection(
                    label: "Mesos",
                    items: mesos,
                    limit: 3,
                    sort: { $0.validEnd < $1.validEnd },
                    onSelect: { selectedMeso = $0 }
                ) { meso in
                    MesoRowView(meso: meso)
                }
            }
        }
        .padding()
        .cardBackground()
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
private struct ActiveAlertSection<Item: Identifiable, Row: View>: View {
    let label: String
    let items: [Item]
    let limit: Int
    let sort: (Item, Item) -> Bool
    let onSelect: (Item) -> Void
    @ViewBuilder let row: (Item) -> Row
    
    var body: some View {
        if !items.isEmpty {
            let visibleItems = items.sorted(by: sort).prefix(limit)
            
            Text(label.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            
            ForEach(visibleItems) { item in
                Button { onSelect(item) } label: { row(item) }
                    .buttonStyle(.plain)
            }
            
            if items.count > visibleItems.count {
                Text("Showing \(visibleItems.count) of \(items.count) \(label.lowercased())")
                    .font(.footnote)
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
            //                .font(.subheadline)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text("MD \(meso.number.formatted(.number.grouping(.never)))")
                    .font(.subheadline.weight(.semibold))
//                Text(meso.areasAffected.isEmpty ? meso.title : meso.areasAffected)
//                    .lineLimit(3)
//                    .truncationMode(.tail)
//                    .font(.subheadline.weight(.semibold))
//                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            VStack(alignment: .trailing) {
                Text("Prob: \(Int(meso.watchProbability))%")
                    .monospacedDigit()
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Expires: \(meso.validEnd, style: .time)")
                    .monospacedDigit()
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WatchRowView: View {
    let watch: WatchRowDTO
    
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
                Text("Until: \(txt) \(watch.validEnd, style: .time)")
                    .monospacedDigit()
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    func buildDisplay(watch: WatchRowDTO) -> String {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f.string(from: watch.validEnd)
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
