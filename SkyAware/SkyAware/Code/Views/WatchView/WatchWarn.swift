//
//  WatchWarn.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI
import MapKit

struct WatchWarn: View {
    let watches: [Watch]
    @EnvironmentObject private var provider: SpcProvider
    @EnvironmentObject private var pointsProvider: PointsProvider
    
    var body: some View {
        VStack {
            if (watches.count == 0) {
                Text("No current watches")
            } else {
                NavigationStack {
                    List(watches.sorted(by: { $0.published > $1.published }), id: \.id) { watch in
                        NavigationLink(destination: WatchDetailView(watch: watch)) {
                            VStack(alignment: .leading) {
                                Text(watch.title)
                                    .font(.headline)
                            }
                            .padding(.vertical, 4)
                        }
                        .navigationTitle("Watches")
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

extension WatchWarn {
    func fetchSpcData() {
        provider.loadFeed()
        
        print("Got SPC Feed data")
        
        pointsProvider.loadPoints()
        
        print("Got SPC Points data")
    }
}

#Preview {
    WatchWarn(watches: [
        Watch(
            id: UUID(),
            title: "Day 1 Watch",
            link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk.html")!,
            published: Date(),
            summary: "A SLGT risk of severe thunderstorms exists across the Plains.",
        ),
        Watch(
            id: UUID(),
            title: "Day 1 Watch - Update",
            link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk2.html")!,
            published: Date().addingTimeInterval(-3600),
            summary: "An ENH risk of severe storms exists across the Midwest.",
        )
    ])
}
