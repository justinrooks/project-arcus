//
//  ConvectiveOutlook.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

struct ConvectiveOutlookView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let dtos: [ConvectiveOutlookDTO]
    let onRefresh: (() async -> Void)?
    let presentationState: ConvectiveOutlookPresentationState

    private var sortedOutlooks: [ConvectiveOutlookDTO] {
        dtos.sorted { lhs, rhs in
            let lhsDate = lhs.issued ?? lhs.published
            let rhsDate = rhs.issued ?? rhs.published
            return lhsDate > rhsDate
        }
    }

    private var latestOutlook: ConvectiveOutlookDTO? {
        sortedOutlooks.first
    }

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    private var earlierOutlooks: [ConvectiveOutlookDTO] {
        Array(sortedOutlooks.dropFirst())
    }

    init(
        dtos: [ConvectiveOutlookDTO],
        refreshStatus: ConvectiveOutlookRefreshStatus? = nil,
        onRefresh: (() async -> Void)? = nil
    ) {
        self.dtos = dtos
        self.onRefresh = onRefresh
        self.presentationState = ConvectiveOutlookPresentationState.resolve(
            dtos: dtos,
            refreshStatus: refreshStatus ?? (dtos.isEmpty ? .loading : .success(hasContent: true))
        )
    }

    var body: some View {
        List {
            Section {
                overviewCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

            case .empty:
                Section {
                    stateCard(
                        title: "No outlooks returned",
                        message: "The latest SPC refresh did not return any convective outlooks.",
                        symbol: "cloud.sun.fill"
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

            case .populated:
                if let latestOutlook {
                    Section {
                        outlookNavigationRow(
                            identifier: "outlook-latest-row",
                            destination: {
                                ConvectiveOutlookDetailView(outlook: latestOutlook)
                            }
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
                                identifier: "outlook-earlier-row-\(index)",
                                destination: {
                                    ConvectiveOutlookDetailView(outlook: dto)
                                }
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
        }
        .padding(16)
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
        guard presentationState == .populated, latestOutlook != nil else {
            return nil
        }
        return "SPC discussion"
    }

    private var overviewMessage: String {
        switch presentationState {
        case .loading:
            Self.overviewMessage(for: nil)
        case .unavailable:
            "SkyAware could not load the latest SPC outlooks right now. Severe-weather risk can still exist even when this feed is unavailable."
        case .empty:
            "The latest SPC refresh did not return any convective outlooks."
        case .populated:
            Self.overviewMessage(for: latestOutlook)
        }
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

    private func outlookNavigationRow<Destination: View, RowContent: View>(
        identifier: String,
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: () -> RowContent
    ) -> some View {
        NavigationLink(destination: destination) {
            label()
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
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
