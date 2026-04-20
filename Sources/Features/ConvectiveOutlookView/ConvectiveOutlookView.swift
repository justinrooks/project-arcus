//
//  ConvectiveOutlook.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

struct ConvectiveOutlookView: View {
    let dtos: [ConvectiveOutlookDTO]
    let onRefresh: (() async -> Void)?
    
    @State private var selectedOutlook: ConvectiveOutlookDTO?

    private var hasNoOutlooks: Bool {
        dtos.isEmpty
    }

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

    private var earlierOutlooks: [ConvectiveOutlookDTO] {
        Array(sortedOutlooks.dropFirst())
    }

    init(
        dtos: [ConvectiveOutlookDTO],
        onRefresh: (() async -> Void)? = nil
    ) {
        self.dtos = dtos
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                overviewCard

                if hasNoOutlooks {
                    emptyCard
                } else {
                    if let latestOutlook {
                        outlookSection(
                            title: "Latest Outlook",
                            subtitle: "Newest SPC product",
                            symbol: "sparkles.rectangle.stack.fill"
                        ) {
                            outlookButton(for: latestOutlook)
                        }
                    }

                    if earlierOutlooks.isEmpty == false {
                        outlookSection(
                            title: "Earlier Outlooks",
                            subtitle: "\(earlierOutlooks.count) more",
                            symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                        ) {
                            VStack(spacing: 10) {
                                ForEach(earlierOutlooks) { dto in
                                    outlookButton(for: dto)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .refreshable {
            guard let onRefresh else { return }
            await onRefresh()
        }
        .scrollIndicators(.hidden)
        .background(Color(.skyAwareBackground).ignoresSafeArea())
        .navigationDestination(item: $selectedOutlook) { outlook in
            ConvectiveOutlookDetailView(outlook: outlook)
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(hasNoOutlooks ? "Outlooks pending" : "Forecast Discussions")
                .font(.headline.weight(.semibold))
            Text(overviewMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No convective outlooks found", systemImage: "cloud.sun.fill")
                .font(.headline.weight(.semibold))
            Text("There are no convective outlooks available.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardBackground(cornerRadius: SkyAwareRadius.section, shadowOpacity: 0.06, shadowRadius: 6, shadowY: 2)
    }

    private var overviewMessage: String {
        if let latestOutlook {
            return "Open the latest SPC discussion first, then work backward if you want earlier issuances for comparison. Most recent update: \((latestOutlook.issued ?? latestOutlook.published).relativeDate())."
        }

        return "Latest convective outlook products from SPC will appear here once sync completes."
    }

    private func outlookSection<Content: View>(
        title: String,
        subtitle: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .skyAwareChip(cornerRadius: SkyAwareRadius.chip, tint: .white.opacity(0.08))
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }

    private func outlookButton(for outlook: ConvectiveOutlookDTO) -> some View {
        Button {
            selectedOutlook = outlook
        } label: {
            OutlookRowView(outlook: outlook)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(
            SkyAwarePressableButtonStyle(
                cornerRadius: SkyAwareRadius.row,
                pressedScale: 0.988,
                pressedOverlayOpacity: 0.06
            )
        )
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
