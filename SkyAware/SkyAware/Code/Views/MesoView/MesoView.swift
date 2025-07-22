//
//  MesoView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

struct MesoView: View {
    let discussions: [MesoscaleDiscussion]
    @EnvironmentObject private var provider: SpcProvider
    @EnvironmentObject private var pointsProvider: PointsProvider
    
    var body: some View {
        VStack {
            if (discussions.count == 0) {
                Text("No current mesoscale discussions")
            } else {
                NavigationStack {
                    List(discussions.sorted(by: { $0.published > $1.published }), id: \.id) { meso in
//                        Section("Meso Discussions") {
//                            ForEach(provider.meso) { meso in
//                                NavigationLink(value: meso) {
//                                    Text(meso.title)
//                                }
//                            }
//                        }
                        NavigationLink(destination: MesoDetailView(discussion: meso)) {
                            VStack(alignment: .leading) {
                                Text(meso.title)
                                    .font(.headline)
                            }
                            .padding(.vertical, 4)
                        }
                        .navigationTitle("Mesoscale Discussions")
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

extension MesoView {
    func fetchSpcData() {
        provider.loadFeed()
        
        print("Got SPC Feed data")
        
        pointsProvider.loadPoints()
        
        print("Got SPC Points data")
    }
}

#Preview {
    MesoView(discussions: [
        MesoscaleDiscussion(
            id: UUID(),
            title: "Day 1 MD",
            link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk.html")!,
            published: Date(),
            summary: "A SLGT risk of severe thunderstorms exists across the Plains.",
        ),
        MesoscaleDiscussion(
            id: UUID(),
            title: "Day 1 MD - Update",
            link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk2.html")!,
            published: Date().addingTimeInterval(-3600),
            summary: "An ENH risk of severe storms exists across the Midwest.",
        )
    ])
}
