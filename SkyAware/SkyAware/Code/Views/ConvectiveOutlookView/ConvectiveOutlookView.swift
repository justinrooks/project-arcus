//
//  ConvectiveOutlook.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

struct ConvectiveOutlookView: View {
    let outlooks: [SPCConvectiveOutlook]
    
    var body: some View {
        VStack {
            HStack {
                Text("Convective Outlooks")
                    .fontWeight(.bold)
                    .padding()
                
                Spacer()
            }
            NavigationView {
                List(outlooks.filter { $0.day == 1 }.sorted(by: { $0.published > $1.published }), id: \.id) { outlook in
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

//                        Text(outlook.published)
//                            .font(.subheadline)
                    }
                }
            }
        }
    }
}

#Preview {
    ConvectiveOutlookView(outlooks: [
        SPCConvectiveOutlook(
            id: UUID(),
            title: "Day 1 Convective Outlook",
            link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk.html")!,
            published: Date(),
            summary: "A SLGT risk of severe thunderstorms exists across the Plains.",
            day: 1,
            riskLevel: "SLGT"
        ),
        SPCConvectiveOutlook(
            id: UUID(),
            title: "Day 1 Convective Outlook - Update",
            link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk2.html")!,
            published: Date().addingTimeInterval(-3600),
            summary: "An ENH risk of severe storms exists across the Midwest.",
            day: 1,
            riskLevel: "ENH"
        )
    ])
}
