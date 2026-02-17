import SwiftUI

struct MapLegend: View {
    let layer: MapLayer
    let severeRisks: [SevereRiskShapeDTO]?
    let fireRisks: [FireRiskDTO]?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch layer {
            case .categorical:
                Text("Severe Storm Risk")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                ForEach(categoricalLevels, id: \.self) { level in
                    CategoricalLegendRow(risk: level)
                }

            case .meso:
                Text("Legend")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                CategoricalLegendRow(risk: layer.key.capitalized) // MESO
            
            case .fire:
                let risks = fireLevels
                Text(risks.isEmpty ? "No fire risk" : "Fire Risk")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                ForEach(risks, id: \.riskLevel) { risk in
                    FireLegendRow(risk: risk)
                }

            case .tornado, .hail, .wind:
                let risks = severeRisks ?? []
                Text(risks.isEmpty ? "No \(layer.title.lowercased()) risk" : "\(layer.title) Risk")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)

                ForEach(risks.indices, id: \.self) { index in
                    SevereLegendRow(layer: layer, risk: risks[index])
                }
            }
        }
        .padding(16)
        .frame(minWidth: 144, alignment: .leading)
        .cardBackground(
            cornerRadius: 18,
            shadowOpacity: 0.10,
            shadowRadius: 8,
            shadowY: 3
        )
    }

    // Categorical ordering; mirrors SPC scale from highest to lowest, plus TSTM
    private var categoricalLevels: [String] {
        ["HIGH", "MDT", "ENH", "SLGT", "MRGL", "TSTM"]
    }

    private var fireLevels: [FireRiskDTO] {
        let source = fireRisks ?? []
        let mostRecentByLevel = Dictionary(
            source.map { ($0.riskLevel, $0) },
            uniquingKeysWith: { lhs, rhs in lhs.valid >= rhs.valid ? lhs : rhs }
        )
        return mostRecentByLevel.values.sorted { $0.riskLevel > $1.riskLevel }
    }
}

// MARK: - Rows

private struct CategoricalLegendRow: View {
    let risk: String

    var body: some View {
        let (fill, stroke) = PolygonStyleProvider.getPolygonStyleForLegend(risk: risk, probability: "0%")
        HStack {
            Circle()
                .fill(Color(fill))
                .overlay(
                    Circle().stroke(Color(stroke), lineWidth: 1.15)
                )
                .frame(width: 14, height: 14)
            Text(risk)
                .font(.caption)
                .fontWeight(["HIGH", "MDT", "ENH"].contains(risk) ? .semibold : .regular)
        }
    }
}

private struct SevereLegendRow: View {
    let layer: MapLayer
    let risk: SevereRiskShapeDTO

    var body: some View {
        let probability = risk.probabilities
        let (fill, stroke) = PolygonStyleProvider.getPolygonStyleForLegend(
            risk: "\(layer.key) - \(probability)",
            probability: String(probability.intValue),
            spcFillHex: risk.fill,
            spcStrokeHex: risk.stroke
        )
        HStack {
            Circle()
                .fill(Color(fill))
                .overlay(
                    Circle().stroke(Color(stroke), lineWidth: 1.15)
                )
                .frame(width: 14, height: 14)
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

private struct FireLegendRow: View {
    let risk: FireRiskDTO

    var body: some View {
        let (fill, stroke) = PolygonStyleProvider.getPolygonStyleForLegend(
            risk: "FIRE \(risk.riskLevel)",
            probability: "0",
            spcFillHex: risk.fill,
            spcStrokeHex: risk.stroke
        )
        HStack {
            Circle()
                .fill(Color(fill))
                .overlay(
                    Circle().stroke(Color(stroke), lineWidth: 1.15)
                )
                .frame(width: 14, height: 14)
            Text(riskLabel)
                .font(.caption)
                .fontWeight(risk.riskLevel >= 8 ? .semibold : .regular)
        }
    }

    private var riskLabel: String {
        switch risk.riskLevel {
        case 10: return "Extreme"
        case 8: return "Critical"
        case 5: return "Elevated"
        default:
            if !risk.riskLevelDescription.isEmpty && risk.riskLevelDescription != "Unknown" {
                return risk.riskLevelDescription
            }
            return "Level \(risk.riskLevel)"
        }
    }
}

// MARK: - Previews

#Preview("Categorical") {
    MapLegend(layer: .categorical, severeRisks: nil, fireRisks: nil)
        .padding()
        .background(.thinMaterial)
}

#Preview("Tornado 10% + SIGN") {
    MapLegend(
        layer: .tornado,
        severeRisks: [
            SevereRiskShapeDTO(type: .tornado, probabilities: .percent(0.10), stroke: nil, fill: nil, polygons: []),
            SevereRiskShapeDTO(type: .tornado, probabilities: .significant(25), stroke: nil, fill: nil, polygons: [])
        ],
        fireRisks: nil
    )
        .padding()
        .background(.thinMaterial)
}

#Preview("Meso") {
    MapLegend(layer: .meso, severeRisks: nil, fireRisks: nil)
        .padding()
        .background(.thinMaterial)
}
