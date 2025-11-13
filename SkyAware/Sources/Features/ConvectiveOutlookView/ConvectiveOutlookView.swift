//
//  ConvectiveOutlook.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

struct ConvectiveOutlookView: View {
    @Environment(\.outlookQuery) private var sync: any SpcOutlookQuerying
    @Environment(\.spcSync) private var ss: any SpcSyncing

    @State private var dtos: [ConvectiveOutlookDTO] = []
    @State private var selectedOutlook: ConvectiveOutlookDTO?
    
    var body: some View {
        List {
            if dtos.isEmpty {
                ContentUnavailableView("No Convective outlooks found", systemImage: "cloud.sun.fill")
            } else {
                Section {
                    ForEach(dtos) { dto in
                        OutlookRowView(outlook: dto)
                            .contentShape(Rectangle()) // Makes entire row tappable
                            .onTapGesture {
                                selectedOutlook = dto
                            }
                            .padding(.horizontal)
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: -10, bottom: 4, trailing: -10))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .navigationDestination(item: $selectedOutlook) { outlook in
            ConvectiveOutlookDetailView(outlook:outlook)
        }
        .scrollContentBackground(.hidden)
        .background(.skyAwareBackground)
        .contentMargins(.top, 0, for: .scrollContent)
        .refreshable {
            Task {
                await ss.syncTextProducts()
                dtos = try await sync.getConvectiveOutlooks()
            }
        }
        .task {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                dtos = ConvectiveOutlook.sampleOutlookDtos
                return
            }
            
            if let outlooks = try? await sync.getConvectiveOutlooks() {
                await MainActor.run { dtos = outlooks }
            }
        }
    }
}

#Preview {
    let spcMock = MockSpcService(storm: .slight, severe: .tornado(probability: 0.10))

    return NavigationStack {
        ConvectiveOutlookView()
            .environment(\.outlookQuery, spcMock)
            .environment(\.spcSync, spcMock)
            .navigationTitle("Convective Outlooks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
    }
}
