//
//  ConvectiveOutlook.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

struct ConvectiveOutlookView: View {
    @EnvironmentObject private var provider: SpcProvider
    
    var body: some View {
        VStack {
            if(provider.outlooks.count == 0){
                Text("No convective outlooks found")
            } else {
                NavigationStack {
                    List(provider.outlooks.filter { $0.day == 1 }.sorted(by: { $0.published > $1.published }), id: \.id) { outlook in
                        
                        NavigationLink(destination: ConvectiveOutlookDetailView(outlook:outlook)) {
                            VStack(alignment: .leading) {
                                Text(outlook.title)
                                    .font(.headline)
                                if(outlook.riskLevel != nil) {
                                    Text(outlook.riskLevel!)
                                        .font(.subheadline)
                                } else {
                                    Text("No risk level")
                                        .font(.subheadline)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .navigationTitle("Convective Outlooks")
                        .font(.subheadline)
                    }
                }
                .refreshable {
                    fetchSpcData()
                }
            }
        }
    }
}

extension ConvectiveOutlookView {
    func fetchSpcData() {
        provider.loadFeed()
        
        print("Got SPC Feed data")
    }
}

#Preview {
    ConvectiveOutlookView()
        .environmentObject(SpcProvider.previewData)
}
