//
//  ConvectiveOutlook.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

struct ConvectiveOutlookView: View {
    enum DiscussionNavigationResolution: Equatable {
        case pending(SPCForecastDay)
        case resolved(day: SPCForecastDay?, path: [ConvectiveOutlookDTO])
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selectedDay: SPCForecastDay
    @State private var navigationRequestGate = HomeTabNavigationRequestGate()

    let dtos: [ConvectiveOutlookDTO]
    let onRefresh: (() async -> Void)?
    let refreshStatus: ConvectiveOutlookRefreshStatus
    let hasAcceptedEmptySnapshot: Bool
    let isOffline: Bool
    let isVisible: Bool
    let navigationRequest: HomeTabNavigationRequest?
    @Binding var navigationPath: [ConvectiveOutlookDTO]
    let onNavigationRequestHandled: (UUID) -> Void
    let onOpenMap: (SPCForecastDay) -> Void

    private var dayPresentation: ConvectiveOutlookDayPresentation {
        ConvectiveOutlookDayPresentation(
            day: selectedDay,
            collection: dtos,
            refreshStatus: refreshStatus,
            hasAcceptedEmptySnapshot: hasAcceptedEmptySnapshot,
            isOffline: isOffline
        )
    }

    private var presentationState: ConvectiveOutlookPresentationState {
        dayPresentation.state
    }

    private var navigationRequestState: ConvectiveOutlookPresentationState? {
        guard let navigationRequest,
              case let .outlooks(day, _) = navigationRequest.destination else {
            return nil
        }
        return ConvectiveOutlookDayPresentation(
            day: day,
            collection: dtos,
            refreshStatus: refreshStatus,
            hasAcceptedEmptySnapshot: hasAcceptedEmptySnapshot,
            isOffline: isOffline
        ).state
    }

    private var latestOutlook: ConvectiveOutlookDTO? {
        dayPresentation.outlooks.first
    }

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    private var earlierOutlooks: [ConvectiveOutlookDTO] {
        Array(dayPresentation.outlooks.dropFirst())
    }

    private enum NavigationRequestResult {
        case notApplicable
        case pending
        case handled
    }

    private func applyNavigationRequestIfNeeded() -> NavigationRequestResult {
        guard isVisible,
              let navigationRequest,
              case let .outlooks(day, opensLatestDiscussion) = navigationRequest.destination else {
            return .notApplicable
        }

        switch Self.navigationResolution(
            for: day,
            opensLatestDiscussion: opensLatestDiscussion,
            dtos: dtos,
            refreshStatus: refreshStatus,
            hasAcceptedEmptySnapshot: hasAcceptedEmptySnapshot,
            isOffline: isOffline
        ) {
        case let .pending(requestedDay):
            selectedDay = requestedDay
            navigationRequestGate.markPending(navigationRequest.id)
            return .pending
        case let .resolved(requestedDay, path):
            if let requestedDay {
                selectedDay = requestedDay
            }
            guard navigationRequestGate.claim(navigationRequest.id) else { return .handled }
            navigationPath = path
            onNavigationRequestHandled(navigationRequest.id)
            return .handled
        }
    }

    static func navigationResolution(
        for day: SPCForecastDay,
        opensLatestDiscussion: Bool,
        dtos: [ConvectiveOutlookDTO],
        refreshStatus: ConvectiveOutlookRefreshStatus,
        hasAcceptedEmptySnapshot: Bool,
        isOffline: Bool
    ) -> DiscussionNavigationResolution {
        guard day != .current, opensLatestDiscussion else { return .resolved(day: nil, path: []) }
        let presentation = ConvectiveOutlookDayPresentation(
            day: day,
            collection: dtos,
            refreshStatus: refreshStatus,
            hasAcceptedEmptySnapshot: hasAcceptedEmptySnapshot,
            isOffline: isOffline
        )
        switch presentation.state {
        case .loading:
            return .pending(day)
        case .unavailable, .empty:
            return .resolved(day: day, path: [])
        case .populated:
            return .resolved(day: day, path: presentation.outlooks.first.map { [$0] } ?? [])
        }
    }

    static func latestAcceptedOutlook(
        for day: SPCForecastDay,
        dtos: [ConvectiveOutlookDTO],
        refreshStatus: ConvectiveOutlookRefreshStatus,
        hasAcceptedEmptySnapshot: Bool,
        isOffline: Bool
    ) -> ConvectiveOutlookDTO? {
        let presentation = ConvectiveOutlookDayPresentation(
            day: day,
            collection: dtos,
            refreshStatus: refreshStatus,
            hasAcceptedEmptySnapshot: hasAcceptedEmptySnapshot,
            isOffline: isOffline
        )
        guard case .populated = presentation.state else { return nil }
        return presentation.outlooks.first
    }

    static func navigationPath(
        for day: SPCForecastDay,
        opensLatestDiscussion: Bool,
        dtos: [ConvectiveOutlookDTO],
        refreshStatus: ConvectiveOutlookRefreshStatus,
        hasAcceptedEmptySnapshot: Bool,
        isOffline: Bool
    ) -> [ConvectiveOutlookDTO] {
        switch navigationResolution(
            for: day,
            opensLatestDiscussion: opensLatestDiscussion,
            dtos: dtos,
            refreshStatus: refreshStatus,
            hasAcceptedEmptySnapshot: hasAcceptedEmptySnapshot,
            isOffline: isOffline
        ) {
        case .pending:
            return []
        case let .resolved(_, path):
            return path
        }
    }

    init(
        dtos: [ConvectiveOutlookDTO],
        refreshStatus: ConvectiveOutlookRefreshStatus? = nil,
        hasAcceptedEmptySnapshot: Bool = false,
        isOffline: Bool = false,
        isVisible: Bool = true,
        navigationRequest: HomeTabNavigationRequest? = nil,
        navigationPath: Binding<[ConvectiveOutlookDTO]> = .constant([]),
        selectedDay: Binding<SPCForecastDay> = .constant(.day1),
        onNavigationRequestHandled: @escaping (UUID) -> Void = { _ in },
        onOpenMap: @escaping (SPCForecastDay) -> Void = { _ in },
        onRefresh: (() async -> Void)? = nil
    ) {
        self.dtos = dtos
        self.onRefresh = onRefresh
        self.refreshStatus = refreshStatus ?? (dtos.isEmpty ? .loading : .success(hasContent: true))
        self.hasAcceptedEmptySnapshot = hasAcceptedEmptySnapshot
        self.isOffline = isOffline
        self.isVisible = isVisible
        self.navigationRequest = navigationRequest
        self._navigationPath = navigationPath
        self._selectedDay = selectedDay
        self.onNavigationRequestHandled = onNavigationRequestHandled
        self.onOpenMap = onOpenMap
    }

    var body: some View {
        List {
            Section {
                Picker("Forecast day", selection: $selectedDay) {
                    ForEach([SPCForecastDay.day1, .day2, .day3], id: \.self) { day in
                        Text("Day \(day.rawValue)").tag(day)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("outlook-day-picker")
                .listRowBackground(Color.clear)

                overviewCard
                    .listRowInsets(
                        EdgeInsets(
                            top: SkyAwareSpacing.compact,
                            leading: SkyAwareSpacing.contentInset,
                            bottom: SkyAwareSpacing.compact,
                            trailing: SkyAwareSpacing.contentInset
                        )
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            switch presentationState {
            case .loading:
                Section {
                    stateCard(
                        title: "Outlooks pending",
                        message: "Latest outlooks from SPC will appear here once they are ready.",
                        symbol: "clock.arrow.circlepath"
                    )
                    .listRowInsets(
                        EdgeInsets(
                            top: SkyAwareSpacing.compact,
                            leading: SkyAwareSpacing.contentInset,
                            bottom: SkyAwareSpacing.compact,
                            trailing: SkyAwareSpacing.contentInset
                        )
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

            case .unavailable:
                Section {
                    stateCard(
                        title: "Outlooks unavailable",
                        message: "SkyAware could not load the latest SPC outlooks right now. Severe-weather risk can still exist even when this feed is unavailable.",
                        symbol: "cloud.slash"
                    )
                    .listRowInsets(
                        EdgeInsets(
                            top: SkyAwareSpacing.compact,
                            leading: SkyAwareSpacing.contentInset,
                            bottom: SkyAwareSpacing.compact,
                            trailing: SkyAwareSpacing.contentInset
                        )
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

            case .empty:
                Section {
                    stateCard(
                        title: "No Day \(selectedDay.rawValue) outlooks returned",
                        message: emptyMessage,
                        symbol: "cloud.sun.fill"
                    )
                    .listRowInsets(
                        EdgeInsets(
                            top: SkyAwareSpacing.compact,
                            leading: SkyAwareSpacing.contentInset,
                            bottom: SkyAwareSpacing.compact,
                            trailing: SkyAwareSpacing.contentInset
                        )
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

            case .populated:
                if let latestOutlook {
                    Section {
                        outlookNavigationRow(
                            outlook: latestOutlook,
                            identifier: "outlook-latest-row",
                        ) {
                            OutlookRowView(outlook: latestOutlook)
                        }
                    } header: {
                        outlookSectionHeader(
                            title: "Latest Outlook",
                            subtitle: nil,
                            symbol: "sparkles.rectangle.stack.fill"
                        )
                    }
                }

                if earlierOutlooks.isEmpty == false {
                    Section {
                        ForEach(Array(earlierOutlooks.enumerated()), id: \.element.id) { index, dto in
                            outlookNavigationRow(
                                outlook: dto,
                                identifier: "outlook-earlier-row-\(index)",
                            ) {
                                OutlookRowView(outlook: dto)
                            }
                        }
                    } header: {
                        outlookSectionHeader(
                            title: "Earlier Outlooks",
                            subtitle: "\(earlierOutlooks.count) more",
                            symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: ConvectiveOutlookDTO.self) { outlook in
            ConvectiveOutlookDetailView(outlook: outlook, onOpenMap: onOpenMap)
        }
        .onChange(of: isVisible, initial: true) { _, newValue in
            guard newValue else {
                if let pendingRequestID = navigationRequestGate.pendingRequestID,
                   pendingRequestID == navigationRequest?.id,
                   navigationRequestGate.cancelPending(pendingRequestID) {
                    onNavigationRequestHandled(pendingRequestID)
                }
                return
            }
            _ = applyNavigationRequestIfNeeded()
        }
        .onChange(of: navigationRequest?.id, initial: true) { _, _ in
            _ = applyNavigationRequestIfNeeded()
        }
        .onChange(of: navigationRequestState) { _, _ in
            _ = applyNavigationRequestIfNeeded()
        }
        .listSectionSpacing(15)
        .scrollContentBackground(.hidden)
        .navigationLinkIndicatorVisibility(.hidden)
        .refreshable {
            guard let onRefresh else { return }
            await onRefresh()
        }
        .scrollIndicators(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .background(Color(.skyAwareBackground).ignoresSafeArea())
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(overviewTitle, systemImage: overviewSymbol)
                .sectionLabel()

//            if let overviewProviderText {
//                Text(overviewProviderText)
//                    .font(.caption.weight(.medium))
//                    .foregroundStyle(.secondary)
//                    .padding(.horizontal, 10)
//                    .padding(.vertical, 5)
//                    .skyAwareChip(cornerRadius: SkyAwareRadius.chip, tint: .white.opacity(0.08))
//            }

            Text(overviewMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let activityMessage {
                Text(activityMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(SkyAwareSpacing.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }

    private var overviewTitle: String {
        switch presentationState {
        case .loading:
            "Outlooks pending"
        case .unavailable:
            "Outlooks unavailable"
        case .empty, .populated:
            "Forecast Discussions"
        }
    }

    private var overviewSymbol: String {
        switch presentationState {
        case .loading:
            "clock.arrow.circlepath"
        case .unavailable:
            "cloud.slash"
        case .empty:
            "cloud.sun.fill"
        case .populated:
            "sparkles.rectangle.stack.fill"
        }
    }

    private var overviewProviderText: String? {
        guard case .populated = presentationState, latestOutlook != nil else {
            return nil
        }
        return "SPC discussion"
    }

    private var activityMessage: String? {
        switch presentationState.activity {
        case .refreshing: "Refreshing outlooks. Showing the last confirmed result."
        case .failed: "Outlooks could not be updated. Showing the last confirmed result."
        case .stale: "Showing saved outlooks. The latest update is unavailable."
        case .current, nil: nil
        }
    }

    private var overviewMessage: String {
        switch presentationState {
        case .loading:
            Self.overviewMessage(for: nil)
        case .unavailable:
            "SkyAware could not load the latest SPC outlooks right now. Severe-weather risk can still exist even when this feed is unavailable."
        case .empty:
            emptyMessage
        case .populated:
            Self.overviewMessage(for: latestOutlook)
        }
    }

    private var emptyMessage: String {
        "The last confirmed SPC collection did not include a Day \(selectedDay.rawValue) convective outlook."
    }

    private func stateCard(
        title: String,
        message: String,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .sectionLabel()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }

    private func outlookSectionHeader(
        title: String,
        subtitle: String?,
        symbol: String
    ) -> some View {
        Group {
            if adaptiveLayout.usesAccessibilityLayout {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: symbol)
                    Text(title)
                }
                .font(.headline.weight(.semibold))
                .textCase(nil)
//                Label(title, systemImage: symbol)
//                    .font(.headline.weight(.semibold))
//                    .textCase(nil)
            } else {
                HStack {
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: symbol)
                        Text(title)
                    }
                    .font(.headline.weight(.semibold))
                    Spacer()
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .skyAwareChip(cornerRadius: SkyAwareRadius.chip, tint: .white.opacity(0.08))
                    }
                }
                .textCase(nil)
            }
        }
    }

    private func outlookNavigationRow<RowContent: View>(
        outlook: ConvectiveOutlookDTO,
        identifier: String,
        @ViewBuilder label: () -> RowContent
    ) -> some View {
        NavigationLink(value: outlook) {
            HStack(spacing: SkyAwareSpacing.standard) {
                label()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, SkyAwareSpacing.standard)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .cardRowBackground(
            cornerRadius: SkyAwareRadius.row,
            shadowOpacity: 0.04,
            shadowRadius: 4,
            shadowY: 1
        )
        .listRowInsets(
            EdgeInsets(
                top: 6,
                leading: SkyAwareSpacing.contentInset,
                bottom: 6,
                trailing: SkyAwareSpacing.contentInset
            )
        )
    }
}

func sortedConvectiveOutlooks(_ dtos: [ConvectiveOutlookDTO]) -> [ConvectiveOutlookDTO] {
    dtos.sorted { lhs, rhs in
        if lhs.published != rhs.published {
            return lhs.published > rhs.published
        }

        let lhsIssued = lhs.issued ?? lhs.published
        let rhsIssued = rhs.issued ?? rhs.published

        if lhsIssued != rhsIssued {
            return lhsIssued > rhsIssued
        }

        if lhs.title != rhs.title {
            return lhs.title > rhs.title
        }

        return lhs.id > rhs.id
    }
}

extension ConvectiveOutlookView {
    static func overviewMessage(for latestOutlook: ConvectiveOutlookDTO?) -> String {
        if let latestOutlook {
            return "Open the latest SPC outlook first, then work backward if you want earlier issuances for comparison. Most recent update: \((latestOutlook.issued ?? latestOutlook.published).relativeDate())."
        }

        return "Latest outlooks from SPC will appear here once they are ready."
    }
}

#Preview {
    NavigationStack {
        ConvectiveOutlookView(dtos: ConvectiveOutlook.sampleOutlookDtos)
            .navigationTitle("Convective Outlooks")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

#Preview("Empty") {
    NavigationStack {
        ConvectiveOutlookView(
            dtos: [],
            refreshStatus: .success(hasContent: false)
        )
        .navigationTitle("Convective Outlooks")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

#Preview("Unavailable") {
    NavigationStack {
        ConvectiveOutlookView(
            dtos: [],
            refreshStatus: .failed
        )
        .navigationTitle("Convective Outlooks")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

#Preview("Loading") {
    NavigationStack {
        ConvectiveOutlookView(
            dtos: [],
            refreshStatus: .loading
        )
        .navigationTitle("Convective Outlooks")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

#Preview("AX5") {
    NavigationStack {
        ConvectiveOutlookView(dtos: ConvectiveOutlook.sampleOutlookDtos, refreshStatus: .success(hasContent: true))
            .environment(\.dynamicTypeSize, .accessibility5)
            .navigationTitle("Convective Outlooks")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}
