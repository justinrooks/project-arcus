//
//  OutlookSummaryCard.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/5/25.
//

import SwiftUI

struct OutlookSummaryCard: View {
    let outlook: ConvectiveOutlookDTO
    
    @State private var navigateToFull = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.skyAwareAccent)
                Text("Outlook Summary")
                    .font(.headline.weight(.semibold))
                Spacer()
            }
            
            // Preview text
            Text(outlook.summary)
                .font(.body)
                .lineSpacing(4)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            
            // Read more link
            Button(action: {
                navigateToFull = true
            }) {
                HStack(spacing: 6) {
                    Text("Read full outlook")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                }
            }
            .skyAwareGlassButtonStyle()
        }
        .padding()
        .cardBackground()
        .navigationDestination(isPresented: $navigateToFull) {
            ConvectiveOutlookDetailView(outlook: outlook)
        }
    }
}

#Preview {
    let dto:ConvectiveOutlookDTO = .init(
        title: "Outlook Test",
        link: URL(string: "https://www.weather.gov/severe/outlook/test")!,
        published: Date(),
        summary: "Isolated severe thunderstorms are possible through the day along the western Oregon and far northern California coastal region. Strong to locally severe gusts may accompany shallow convection that develops over parts of the Northeast.",
        fullText: "...SUMMARY... \nIsolated severe thunderstorms are possible through the day along the western Oregon and far northern California coastal region. Strong to locally severe gusts may accompany shallow convection that develops over parts of the Northeast.\n....20z UPDATE... \nThe only adjustment was a northward expansion of the 2% tornado and 5% wind risk probabilities across the far southwest WA coast. Recent imagery from KLGX shows a cluster of semi-discrete cells off the far southwest WA coast with weak, but discernible, mid-level rotation. Regional VWPs continue to show ample low-level shear, and surface temperatures are warming to near/slightly above the upper-end of the ensemble envelope. These kinematic/thermodynamic conditions may support at least a low-end wind and brief tornado threat along the coast.",
        day: 1,
        riskLevel: "mdt",
        issued: Date(),
        validUntil: Date()
    )
    
    return NavigationStack {
        OutlookSummaryCard(outlook: dto)
    }
}
