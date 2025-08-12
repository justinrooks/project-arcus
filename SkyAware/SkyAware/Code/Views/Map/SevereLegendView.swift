//
//  SevereLegendView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/9/25.
//

import SwiftUI

struct SevereLegendView: View {
    let probabilities: [ThreatProbability]
    let risk: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 9) {
                Text(getLabel(risk: risk))
                    .fontWeight(.bold)
                    .font(.caption)
                ForEach (probabilities, id: \.self) { index in
                    let (fill, _) = PolygonStyleProvider.getPolygonStyleForLegend(
                        risk: "\(risk) - \(index)",
                        probability: String(index.intValue))
                    HStack {
                        Circle()
                            .fill(Color(fill))
                            .frame(width: 13, height: 13)
                        Text("\(index.intValue)%")
                            .font(.caption)
                    }
                }
            }
            .padding()
        }
}

private func getLabel(risk: String) -> String {
    switch risk {
    case "WIND":
        return "Wind"
    case "HAIL":
        return "Hail"
    case "TOR":
        return "Tornado"
    default:
        return "Unknown"
    }
}

#Preview {
    SevereLegendView(
        probabilities: [.percent(0.02), .percent(0.15)],
        risk: "TOR")
}
