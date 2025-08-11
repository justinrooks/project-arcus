//
//  SevereLegendView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/9/25.
//

import SwiftUI

struct SevereLegendView: View {
    let probabilities: [ThreatProbability]
    let legendLabel: String
    let risk: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 9) {
                Text(legendLabel)
                    .fontWeight(.bold)
                    .font(.caption)
                ForEach (probabilities, id: \.self) { index in
//                    print(index.description)
                    let (_, stroke) = PolygonStyleProvider.getPolygonStyleForLegend(
                        risk: "\(risk) - \(index)",
                        probability: String(index.intValue * 25))
                    HStack {
                        Circle()
                            .fill(Color(stroke))
                            .frame(width: 13, height: 13)
                        Text("\(index.intValue)%")
                            .font(.caption)
                    }
                }
            }
            .padding()
        }
}

#Preview {
    SevereLegendView(
        probabilities: [.percent(0.02), .percent(0.15)],
        legendLabel: "Tornado",
        risk: "TOR")
}
