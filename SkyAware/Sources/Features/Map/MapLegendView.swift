import SwiftUI

struct MapLegend: View {
    let layer: MapLayer
    let probabilities: [ThreatProbability]?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            switch layer {
            case .categorical:
                Text("Severe Storm Risk")
                    .font(.caption)
                    .fontWeight(.bold)
                ForEach(categoricalLevels, id: \.self) { level in
                    CategoricalLegendRow(risk: level)
                }

            case .meso:
                Text("Legend")
                    .font(.caption)
                    .fontWeight(.bold)
                CategoricalLegendRow(risk: layer.key.capitalized) // MESO
            
            case .fire:
                Text("Legend")
                    .font(.caption)
                    .fontWeight(.bold)
                CategoricalLegendRow(risk: layer.key.capitalized) // Fire

            case .tornado, .hail, .wind:
                let probs = probabilities ?? []
                Text(probs.isEmpty ? "No \(layer.title.lowercased()) risk" : "\(layer.title) Risk")
                    .font(.caption)
                    .fontWeight(.bold)

                ForEach(probs, id: \.self) { item in
                    SevereLegendRow(layer: layer, probability: item)
                }
            }
        }
        .padding()
    }

    // Categorical ordering; mirrors SPC scale from highest to lowest, plus TSTM
    private var categoricalLevels: [String] {
        ["HIGH", "MDT", "ENH", "SLGT", "MRGL", "TSTM"]
    }
}

// MARK: - Rows

private struct CategoricalLegendRow: View {
    let risk: String

    var body: some View {
        let (_, stroke) = PolygonStyleProvider.getPolygonStyle(risk: risk, probability: "0%")
        HStack {
            Circle()
                .fill(Color(stroke))
                .frame(width: 15, height: 15)
            Text(risk)
                .font(.caption)
        }
    }
}

private struct SevereLegendRow: View {
    let layer: MapLayer
    let probability: ThreatProbability

    var body: some View {
        let (fill, _) = PolygonStyleProvider.getPolygonStyleForLegend(
            risk: "\(layer.key) - \(probability)",
            probability: String(probability.intValue)
        )
        HStack {
            Circle()
                .fill(Color(fill))
                .frame(width: 15, height: 15)
            switch probability {
            case .significant:
                Text(probability.description)
                    .font(.caption)
                    .fontWeight(.bold)
            default:
                Text(probability.description)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Previews

#Preview("Categorical") {
    MapLegend(layer: .categorical, probabilities: nil)
        .padding()
        .background(.thinMaterial)
}

#Preview("Tornado 10% + SIGN") {
    MapLegend(layer: .tornado, probabilities: [.percent(0.10), .significant(25)])
        .padding()
        .background(.thinMaterial)
}

#Preview("Meso") {
    MapLegend(layer: .meso, probabilities: nil)
        .padding()
        .background(.thinMaterial)
}
