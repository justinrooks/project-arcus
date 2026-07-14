//
//  ActiveAlertSummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/8/25.
//

import SwiftUI

struct ActiveAlertSummaryView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum ContentState: Equatable {
        case loading
        case empty
        case alerts
    }

    private enum HeightPhase: Equatable {
        case uninitialized
        case stable(ContentState)
        case leavingAlerts
    }

    let mesos: [MdDTO]
    let alerts: [AlertDTO]
    let localAlertsDisplayState: LocalAlertsDisplayState
    let todayContentState: TodayContentState
    let isOffline: Bool
    let onOpenAlertCenter: (() -> Void)?
    private let sortedMesos: [MdDTO]
    private let sortedAlerts: [AlertDTO]
    
    @State private var selectedMeso: MdDTO? = nil
    @State private var selectedAlert: AlertDTO? = nil
    @State private var selectedMesoDetent: PresentationDetent = .medium
    @State private var selectedAlertDetent: PresentationDetent = .medium
    @State private var heightPhase: HeightPhase = .uninitialized
    @State private var flexibleHeightResetTask: Task<Void, Never>? = nil
    init(
        mesos: [MdDTO],
        alerts: [AlertDTO],
        localAlertsDisplayState: LocalAlertsDisplayState = .current(content: .populated, source: .cached),
        todayContentState: TodayContentState = .current,
        isOffline: Bool = false,
        onOpenAlertCenter: (() -> Void)? = nil
    ) {
        self.mesos = mesos
        self.alerts = alerts
        self.localAlertsDisplayState = localAlertsDisplayState
        self.todayContentState = todayContentState
        self.isOffline = isOffline
        self.onOpenAlertCenter = onOpenAlertCenter
        self.sortedMesos = AlertPresentationOrdering.ordered(mesos, endDate: \.validEnd)
        self.sortedAlerts = AlertPresentationOrdering.ordered(alerts, endDate: \.expires)
    }

    private var hasRenderableAlerts: Bool {
        sortedMesos.isEmpty == false || sortedAlerts.isEmpty == false
    }

    private var contentState: ContentState {
        return Self.contentState(
            for: localAlertsDisplayState,
            hasRenderableAlerts: hasRenderableAlerts
        )
    }

    private var isLeavingAlertsTransition: Bool {
        switch heightPhase {
        case .stable(.alerts), .leavingAlerts:
            return contentState != .alerts
        case .stable, .uninitialized:
            return false
        }
    }

    private var usesFlexibleAlertHeight: Bool {
        Self.usesFlexibleAlertHeight(currentState: contentState, isLeavingAlerts: isLeavingAlertsTransition)
    }

    private var contentStateAnimation: Animation? {
        guard let previousState = previousStableContentState else {
            return nil
        }

        guard Self.shouldAnimateContentStateTransition(
            from: previousState,
            to: contentState,
            suppressesRoutineRefreshMotion: todayContentState.suppressesRoutineRefreshMotion
        ) else {
            return nil
        }

        return SkyAwareMotion.layerChange(reduceMotion)
    }

    private var previousStableContentState: ContentState? {
        switch heightPhase {
        case .stable(let state):
            return state
        case .leavingAlerts:
            return .alerts
        case .uninitialized:
            return nil
        }
    }

    private var transitionHoldDurationNanoseconds: UInt64 {
        let seconds = reduceMotion ? 0.01 : 0.32
        return UInt64(seconds * 1_000_000_000)
    }

    @ViewBuilder
    private var alertsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ActiveAlertSection(
                label: "Watches & Warnings",
                items: sortedAlerts,
                limit: 2,
                onSelect: {
                    selectedAlertDetent = .medium
                    selectedAlert = $0
                }
            ) { alert in
                WatchRowView(alert: alert)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        shellContent
        .sheet(item: $selectedMeso) { meso in
            sheetContent(selection: $selectedMesoDetent) { isExpanded in
                MesoscaleDiscussionCard(meso: meso, layout: .sheet, isExpanded: isExpanded)
                    .padding(.top, 8)
                    .padding(.horizontal, 6)
            }
        }
        .sheet(item: $selectedAlert) { alert in
            sheetContent(selection: $selectedAlertDetent) { isExpanded in
                AlertDetailView(alert: alert, layout: .sheet, isExpanded: isExpanded)
                    .padding(.top, 8)
                    .padding(.horizontal, 6)
            }
            .accessibilityIdentifier("summary-watch-detail-sheet")
        }
        .onChange(of: contentState) { oldValue, newValue in
            handleContentStateTransition(from: oldValue, to: newValue)
        }
        .onAppear {
            if heightPhase == .uninitialized {
                heightPhase = .stable(contentState)
            }
        }
        .onDisappear {
            flexibleHeightResetTask?.cancel()
            flexibleHeightResetTask = nil
        }
    }

    @ViewBuilder
    private var shellContent: some View {
        if contentState == .empty {
            contentShell
        } else {
            contentShell
                .cardBackground(
                    cornerRadius: SkyAwareRadius.card,
                    shadowOpacity: 0.08,
                    shadowRadius: 8,
                    shadowY: 3
                )
        }
    }

    private var contentShell: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Label("Local Alerts", systemImage: "exclamationmark.triangle.fill")
                    .sectionLabel()

                Spacer(minLength: 12)

                if let onOpenAlertCenter, contentState != .loading, (hasRenderableAlerts || isOffline) {
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

            if isOffline {
                Label("Offline. Showing saved local alerts when available.", systemImage: "wifi.slash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Offline. Showing saved local alerts when available.")
            }

            innerContent
        }
        .padding(18)
    }

    @ViewBuilder
    private var innerContent: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 12) {
                contentStateContainer
            }
        } else {
            contentStateContainer
        }
    }

    private var contentStateContainer: some View {
        ZStack(alignment: .topLeading) {
            contentStateView
        }
        .animation(contentStateAnimation, value: contentState)
        .frame(
            maxWidth: .infinity,
            minHeight: usesFlexibleAlertHeight ? nil : 72,
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private var contentStateView: some View {
        switch contentState {
        case .loading:
            loadingContent
        case .alerts:
            alertsContent
        case .empty:
            emptyContent
        }
    }

    private var emptyContent: some View {
        LocalAlertsNoActiveRailView()
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Checking local alerts", systemImage: "antenna.radiowaves.left.and.right")
                .sectionLabel()
            Text("Bringing in local alerts…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(2)
        .accessibilityElement(children: .combine)
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

    private func handleContentStateTransition(from oldState: ContentState, to newState: ContentState) {
        if newState == .alerts {
            flexibleHeightResetTask?.cancel()
            heightPhase = .stable(.alerts)
            return
        }

        guard oldState == .alerts, newState != .alerts else {
            flexibleHeightResetTask?.cancel()
            heightPhase = .stable(newState)
            return
        }

        flexibleHeightResetTask?.cancel()
        heightPhase = .leavingAlerts
        flexibleHeightResetTask = Task { @MainActor in
            try? await Task.sleep(for: .nanoseconds(transitionHoldDurationNanoseconds))
            guard Task.isCancelled == false else { return }
            heightPhase = .stable(contentState)
            flexibleHeightResetTask = nil
        }
    }

    static func usesFlexibleAlertHeight(currentState: ContentState, isLeavingAlerts: Bool) -> Bool {
        currentState == .alerts || isLeavingAlerts
    }

    static func shouldAnimateContentStateTransition(
        from oldState: ContentState,
        to newState: ContentState,
        suppressesRoutineRefreshMotion: Bool
    ) -> Bool {
        guard suppressesRoutineRefreshMotion == false else {
            return false
        }

        guard oldState != .loading, newState != .loading else {
            return false
        }

        return oldState != newState
    }

    // Keep visible alerts ahead of transient loading/empty bookkeeping so cached refreshes stay calm.
    static func contentState(
        for displayState: LocalAlertsDisplayState,
        hasRenderableAlerts: Bool
    ) -> ContentState {
        if hasRenderableAlerts {
            return .alerts
        }

        switch displayState.presentationState {
        case .loading:
            return .loading
        case .alerts, .empty, .unavailable:
            return .empty
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

            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)

                ForEach(visibleItems) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        row(item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(
                        SkyAwarePressableButtonStyle(
                            cornerRadius: SkyAwareRadius.row,
                            pressedScale: 0.988,
                            pressedOverlayOpacity: 0.06
                        )
                    )
                    .accessibilityIdentifier("\(label.lowercased())-row-\(String(describing: item.id))")
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
                
                if let watchProbability = meso.watchProbability, watchProbability >= 20 {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Watch \(Int(watchProbability))%")
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
    let alert: AlertDTO
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            let (icon, color) = styleForType(.watch, alert.title)
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 16, alignment: .center)
                .padding(.top, 6)

            VStack(alignment: .leading) {
                HStack {
                    Text("\(alert.title)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    VStack(alignment: .trailing) {
                        let txt = buildDisplay(alert: alert)
                        Text("Until \(txt) \(alert.validEnd, style: .time)")
                            .monospacedDigit()
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
//                    .skyAwareChip(cornerRadius: SkyAwareRadius.chip, tint: color.opacity(0.16))
                }
                if let sevTags = alert.SevereRiskTags {
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

    private func buildDisplay(alert: AlertDTO) -> String {
        Self.dayFormatter.string(from: alert.validEnd)
    }
}

#Preview {
    NavigationStack {
        ActiveAlertPreviewContainer(
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows,
            localAlertsDisplayState: .current(content: .populated, source: .cached),
            todayContentState: .current
        )
        .toolbar(.hidden, for: .navigationBar)
        .background(.skyAwareBackground)
        .environment(\.dependencies, Dependencies.unconfigured)
    }
}

#Preview("Local Alerts - Multiple Active Alerts") {
    ActiveAlertPreviewContainer(
        alerts: Watch.sampleWatchRows,
        localAlertsDisplayState: .current(content: .populated, source: .cached)
    )
}

#Preview("Local Alerts - One Active Alert") {
    ActiveAlertPreviewContainer(
        alerts: Array(Watch.sampleWatchRows.prefix(1)),
        localAlertsDisplayState: .current(content: .populated, source: .cached)
    )
}

#Preview("Local Alerts - Populated Mesos") {
    ActiveAlertPreviewContainer(
        mesos: MD.sampleDiscussionDTOs,
        localAlertsDisplayState: .current(content: .populated, source: .cached)
    )
}

#Preview("Local Alerts - Mixed Alert and Meso") {
    ActiveAlertPreviewContainer(
        mesos: [MD.sampleDiscussionDTOs[0]],
        alerts: [Watch.sampleWatchRows[0]],
        localAlertsDisplayState: .current(content: .populated, source: .cached)
    )
}

#Preview("Local Alerts - No Active Rail") {
    ActiveAlertPreviewContainer(
        mesos: [],
        alerts: [],
        localAlertsDisplayState: .current(content: .empty, source: .cached)
    )
}

#Preview("Local Alerts - No Cache Resolving") {
    ActiveAlertPreviewContainer(
        mesos: [],
        alerts: [],
        localAlertsDisplayState: .noCacheResolving,
        todayContentState: .noCacheResolving
    )
}

#Preview("Local Alerts - Cached Refreshing Populated") {
    ActiveAlertPreviewContainer(
        mesos: MD.sampleDiscussionDTOs,
        alerts: Watch.sampleWatchRows,
        localAlertsDisplayState: .cachedRefreshing(content: .populated),
        todayContentState: .cachedRefreshing
    )
}

#Preview("Local Alerts - Cached Refreshing Empty") {
    ActiveAlertPreviewContainer(
        mesos: [],
        alerts: [],
        localAlertsDisplayState: .cachedRefreshing(content: .empty),
        todayContentState: .cachedRefreshing
    )
}

#Preview("Local Alerts - Offline Cached Populated") {
    ActiveAlertPreviewContainer(
        mesos: MD.sampleDiscussionDTOs,
        alerts: Watch.sampleWatchRows,
        localAlertsDisplayState: .staleOrDegraded(content: .populated),
        todayContentState: .staleRefreshing,
        isOffline: true
    )
    .environment(\.colorScheme, .dark)
}

#Preview("Local Alerts - Offline Cached Empty") {
    ActiveAlertPreviewContainer(
        mesos: [],
        alerts: [],
        localAlertsDisplayState: .staleOrDegraded(content: .empty),
        todayContentState: .staleRefreshing,
        isOffline: true
    )
    .environment(\.colorScheme, .light)
}

#Preview("Local Alerts - Degraded Cached Populated") {
    ActiveAlertPreviewContainer(
        mesos: MD.sampleDiscussionDTOs,
        alerts: Watch.sampleWatchRows,
        localAlertsDisplayState: .staleOrDegraded(content: .populated),
        todayContentState: .degraded,
        isOffline: true
    )
}

#Preview("Local Alerts - Degraded Cached Empty") {
    ActiveAlertPreviewContainer(
        mesos: [],
        alerts: [],
        localAlertsDisplayState: .staleOrDegraded(content: .empty),
        todayContentState: .degraded,
        isOffline: true
    )
}

#Preview("Local Alerts - AX Large Type") {
    ActiveAlertPreviewContainer(
        mesos: MD.sampleDiscussionDTOs,
        alerts: Watch.sampleWatchRows,
        localAlertsDisplayState: .cachedRefreshing(content: .populated),
        todayContentState: .cachedRefreshing
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}

private struct ActiveAlertPreviewContainer: View {
    let mesos: [MdDTO]
    let alerts: [AlertDTO]
    let localAlertsDisplayState: LocalAlertsDisplayState
    let todayContentState: TodayContentState
    let isOffline: Bool

    init(
        mesos: [MdDTO] = [],
        alerts: [AlertDTO] = [],
        localAlertsDisplayState: LocalAlertsDisplayState,
        todayContentState: TodayContentState = .current,
        isOffline: Bool = false
    ) {
        self.mesos = mesos
        self.alerts = alerts
        self.localAlertsDisplayState = localAlertsDisplayState
        self.todayContentState = todayContentState
        self.isOffline = isOffline
    }

    var body: some View {
        ActiveAlertSummaryView(
            mesos: mesos,
            alerts: alerts,
            localAlertsDisplayState: localAlertsDisplayState,
            todayContentState: todayContentState,
            isOffline: isOffline
        )
        .padding()
        .background(.skyAwareBackground)
    }
}
