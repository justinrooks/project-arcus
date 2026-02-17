//
//  ConvectiveOutlook.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

struct ConvectiveOutlookView: View {
    let dtos: [ConvectiveOutlookDTO]
    
    @State private var selectedOutlook: ConvectiveOutlookDTO?

    private var hasNoOutlooks: Bool {
        dtos.isEmpty
    }
    
    var body: some View {
        List {
            if hasNoOutlooks {
                ContentUnavailableView {
                    Label("No convective outlooks found", systemImage: "cloud.sun.fill")
                } description: {
                    Text("There are no convective outlooks available.")
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(dtos) { dto in
                        Button {
                            selectedOutlook = dto
                        } label: {
                            OutlookRowView(outlook: dto)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(12)
        .scrollContentBackground(.hidden)
        .background(.skyAwareBackground)
        .navigationDestination(item: $selectedOutlook) { outlook in
            ConvectiveOutlookDetailView(outlook: outlook)
        }
    }
}

#Preview {
    NavigationStack {
        ConvectiveOutlookView(dtos: ConvectiveOutlook.sampleOutlookDtos)
            .navigationTitle("Convective Outlooks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
    }
}
