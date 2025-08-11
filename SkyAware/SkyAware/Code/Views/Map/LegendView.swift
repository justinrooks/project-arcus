//
//  LegendView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/4/25.
//

import SwiftUI

struct LegendView: View {
//    @ObservedObject var selection: SelectedLayer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Severe Risk")
                .fontWeight(.bold)
                .font(.caption)
            LegendItem(risk:"HIGH")
            LegendItem(risk:"MDT")
            LegendItem(risk:"ENH")
            LegendItem(risk:"SLGT")
            LegendItem(risk:"MRGL")
            LegendItem(risk:"TSTM")
        }
        .padding()
    }
}

struct LegendItem: View {
    let risk: String
    
    var body: some View {
        let (_, stroke) = PolygonStyleProvider.getPolygonStyle(risk: risk, probability: "0%")
        HStack {
            Circle()
                .fill(Color(stroke))
                .frame(width: 13, height: 13)
            Text(risk)
                .font(.caption)
        }
    }
}

#Preview {
    LegendView()
}



