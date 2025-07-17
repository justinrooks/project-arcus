//
//  MesoView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

struct MesoView: View {
    let discussions: [MesoscaleDiscussion]
    
    var body: some View {
        VStack {
            if (discussions.count == 0) {
                Text("No current mesoscale discussions")
            } else {
                Text("Mesoscale Discussions")
                    .fontWeight(.bold)
                    .padding()
                NavigationView {
                    List(discussions.sorted(by: { $0.published < $1.published }), id: \.id) { meso in
                        VStack(alignment: .leading) {
                            Text(meso.title)
                                .font(.headline)
                        }
                    }
                }
            }
        }
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
