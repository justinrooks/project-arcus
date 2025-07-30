//
//  MapView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject private var pointsProvider: PointsProvider
    
    @State private var selectedLayer: String = "MRGL"
    
    private let availableLayers: [(key: String, label: String)] = [
        ("MRGL", "Marginal Risk"),
        ("SLGT", "Slight Risk"),
        ("ENH", "Enhanced Risk"),
        ("MDT", "Moderate Risk"),
        ("HIGH", "High Risk"),
        ("TOR", "Tornado"),
        ("HAIL", "Hail"),
        ("WIND", "Wind")
    ]
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            CONUSMapView(polygonList: polygonsForLayer(named: selectedLayer))
                .edgesIgnoringSafeArea(.top)
            
            Menu {
                ForEach(availableLayers.filter { hasPolygons(for: $0.key) }, id: \.key) { layer in
                    Button(layer.label) {
                        withAnimation {
                            selectedLayer = layer.key
                        }
                    }
                }
            } label: {
                Image(systemName: "map.fill")
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(Circle())
                    .padding()
            }
        }
    }
    
    
    private func hasPolygons(for layer: String) -> Bool {
        let polygons = polygonsForLayer(named: layer)
        return polygons.polygons.count > 0
    }
    
    private func polygonsForLayer(named layer: String) -> MKMultiPolygon {
        switch layer {
        case "MRGL":
            return pointsProvider.marginal
        case "SLGT":
            return pointsProvider.slight
        case "ENH":
            return pointsProvider.enhanced
        case "MDT":
            return pointsProvider.moderate
        case "HIGH":
            return pointsProvider.high
        case "TOR":
            return pointsProvider.tornado
        case "HAIL":
            return pointsProvider.hail
        case "WIND":
            return pointsProvider.wind
        default:
            return MKMultiPolygon()
        }
    }
}

#Preview {
    MapView()
        .environmentObject(PointsProvider.pointsPreview)
}
