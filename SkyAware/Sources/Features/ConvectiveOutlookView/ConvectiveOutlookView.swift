//
//  ConvectiveOutlook.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

struct ConvectiveOutlookView: View {
    @Environment(\.dependencies) private var deps
    
    // MARK: Local handles
    private var sync: any SpcSyncing { deps.spcSync }
    private var outlookSvc: any SpcOutlookQuerying { deps.spcOutlook }

    @State private var dtos: [ConvectiveOutlookDTO] = []
    @State private var selectedOutlook: ConvectiveOutlookDTO?
    
    var body: some View {
        List {
            if dtos.isEmpty {
                ContentUnavailableView {
                    Label("No convective outlooks found", systemImage: "cloud.sun.fill")
                } description: {
                    Text("There are no convective outlooks available.")
                }
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
                await sync.syncTextProducts()
                dtos = try await outlookSvc.getConvectiveOutlooks()
            }
        }
        .task {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                dtos = ConvectiveOutlook.sampleOutlookDtos
                return
            }
            
            if let outlooks = try? await outlookSvc.getConvectiveOutlooks() {
                await MainActor.run { dtos = outlooks }
            }
        }
    }
}

#Preview {
    let spcMock = MockSpcService(storm: .slight, severe: .tornado(probability: 0.10))

    return NavigationStack {
        ConvectiveOutlookView()
            .navigationTitle("Convective Outlooks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
    }
}
