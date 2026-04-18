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
    let onOpenAlertCenter: (() -> Void)?
    private let sortedMesos: [MdDTO]
    private let sortedWatches: [WatchRowDTO]
    
    @State private var selectedMeso: MdDTO? = nil
    @State private var selectedWatch: WatchRowDTO? = nil
    @State private var selectedMesoDetent: PresentationDetent = .medium
    @State private var selectedWatchDetent: PresentationDetent = .medium
    init(
        mesos: [MdDTO],
        watches: [WatchRowDTO],
        isLoading: Bool = false,
        onOpenAlertCenter: (() -> Void)? = nil
    ) {
        self.mesos = mesos
        self.watches = watches
        self.isLoading = isLoading
        self.onOpenAlertCenter = onOpenAlertCenter
        self.sortedMesos = mesos.sorted { $0.validEnd < $1.validEnd }
        self.sortedWatches = watches.sorted { $0.expires < $1.expires }
    }

    @ViewBuilder
    private var alertsContent: some View {
        ActiveAlertSection(
            label: "Watches",
            items: sortedWatches,
            limit: 2,
            onSelect: {
                selectedWatchDetent = .medium
                selectedWatch = $0
            }
        ) { watch in
            WatchRowView(watch: watch)
        }

        ActiveAlertSection(
            label: "Mesos",
            items: sortedMesos,
            limit: 2,
            onSelect: {
                selectedMesoDetent = .medium
                selectedMeso = $0
            }
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
            HStack(alignment: .center, spacing: 12) {
                Label("Local Alerts", systemImage: "exclamationmark.triangle.fill")
                    .sectionLabel()

                Spacer(minLength: 12)

                if let onOpenAlertCenter, isLoading == false {
                    Button {
                        onOpenAlertCenter()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Alert Center")
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.semibold))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .skyAwareChip(cornerRadius: SkyAwareRadius.chipCompact, tint: .white.opacity(0.10))
                    }
                    .buttonStyle(
                        SkyAwarePressableButtonStyle(
                            cornerRadius: SkyAwareRadius.chipCompact,
                            pressedScale: 0.985,
                            pressedOverlayOpacity: 0.08
                        )
                    )
                    .accessibilityHint("Opens the full alerts tab.")
                }
            }

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
            sheetContent(selection: $selectedMesoDetent) { isExpanded in
                MesoscaleDiscussionCard(meso: meso, layout: .sheet, isExpanded: isExpanded)
                    .padding(.top, 8)
                    .padding(.horizontal, 6)
            }
        }
        .sheet(item: $selectedWatch) { watch in
            sheetContent(selection: $selectedWatchDetent) { isExpanded in
                WatchDetailView(watch: watch, layout: .sheet, isExpanded: isExpanded)
                    .padding(.top, 8)
                    .padding(.horizontal, 6)
            }
        }
    }

    @ViewBuilder
    private func sheetContent<Content: View>(
        selection: Binding<PresentationDetent>,
        @ViewBuilder content: @escaping (_ isExpanded: Bool) -> Content
    ) -> some View {
        NavigationStack {
            GeometryReader { geometry in
                let isExpanded = selection.wrappedValue == .large
                ScrollView {
                    content(isExpanded)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: geometry.size.height,
                            maxHeight: isExpanded ? nil : geometry.size.height,
                            alignment: .top
                        )
                }
                .scrollBounceBehavior(.basedOnSize)
                .background(.skyAwareBackground)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large], selection: selection)
        .presentationDragIndicator(.visible)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let label: String
    let items: [Item]
    let limit: Int
    let onSelect: (Item) -> Void
    @ViewBuilder let row: (Item) -> Row
    @State private var isExpanded = false
    
    var body: some View {
        if !items.isEmpty {
            let visibleItems = isExpanded ? items : Array(items.prefix(limit))
            
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
//                .skyAwareChip(cornerRadius: SkyAwareRadius.chip, tint: .white.opacity(0.09))
            
            ForEach(visibleItems) { item in
                Button { onSelect(item) } label: { row(item) }
                    .buttonStyle(
                        SkyAwarePressableButtonStyle(
                            cornerRadius: SkyAwareRadius.row,
                            pressedScale: 0.988,
                            pressedOverlayOpacity: 0.06
                        )
                    )
            }
            
            if items.count > limit {
                Button {
                    withAnimation(SkyAwareMotion.disclosure(reduceMotion)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(isExpanded ? "Show less" : "See all (\(items.count - visibleItems.count) more)")
                        Image(systemName: isExpanded ? "arrow.up" : "arrow.right")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                }
                .buttonStyle(
                    SkyAwarePressableButtonStyle(
                        cornerRadius: SkyAwareRadius.chipCompact,
                        pressedScale: 0.985,
                        pressedOverlayOpacity: 0.08
                    )
                )
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 16, alignment: .center)
                .padding(.top, 6)

            VStack(alignment: .leading) {
                HStack {
                    Text("Meso \(meso.number.formatted(.number.grouping(.never)))")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Ends \(meso.validEnd, style: .time)")
                            .monospacedDigit()
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                
                if meso.watchProbability >= 20 {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Watch \(Int(meso.watchProbability))%")
                                .monospacedDigit()
                                .font(.caption.weight(.semibold))
                        }
                        Spacer()
                    }
                }
            }

        }
        .padding(.vertical, 3)
//            .skyAwareChip(cornerRadius: SkyAwareRadius.chip, tint: color.opacity(0.16))
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 16, alignment: .center)
                .padding(.top, 6)

            VStack(alignment: .leading) {
                HStack {
                    Text("\(watch.title)")
                        .font(.subheadline.weight(.semibold))
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
//                    .skyAwareChip(cornerRadius: SkyAwareRadius.chip, tint: color.opacity(0.16))
                }
                if let sevTags = watch.SevereRiskTags {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(sevTags)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.tornadoRed)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                }
            }
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
