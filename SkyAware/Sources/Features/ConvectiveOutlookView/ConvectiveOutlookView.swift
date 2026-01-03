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
