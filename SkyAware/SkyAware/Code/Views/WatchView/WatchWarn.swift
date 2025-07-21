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
    
    var body: some View {
        if ( watches.isEmpty) {
            Text("No current watches")
        } else {
            VStack {
                Text("Watches")
                    .fontWeight(.bold)
                    .padding()
                NavigationView {
                    List(watches.sorted(by: { $0.published > $1.published }), id: \.id) { watch in
                        VStack(alignment: .leading) {
                            Text(watch.title)
                                .font(.headline)
                        }
                    }
                }
            }
        }
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
