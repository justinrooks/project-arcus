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
                sectionTitle

                if hasNoOutlooks {
                    emptyCard
                } else {
                    VStack(spacing: 10) {
                        ForEach(dtos) { dto in
                            Button {
                                selectedOutlook = dto
                            } label: {
                                OutlookRowView(outlook: dto)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
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

    private var sectionTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Forecast Discussions")
                .font(.headline.weight(.semibold))
            Text("Latest convective outlook products from SPC.")
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
