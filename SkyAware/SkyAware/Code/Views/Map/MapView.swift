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
    
    @State private var selectedLayer: String = "CAT"
    
    private let availableLayers: [(key: String, label: String)] = [
        ("CAT", "Categorical"),
        ("TOR", "Tornado"),
        ("HAIL", "Hail"),
        ("WIND", "Wind")
    ]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            CONUSMapView(polygonList: polygonsForLayer(named: selectedLayer))
                .edgesIgnoringSafeArea(.top)
            
            Menu {
                ForEach(availableLayers, id: \.key) { layer in
                    Button(layer.label) {
                        withAnimation {
                            selectedLayer = layer.key
                        }
                    }
                }
            } label: {
                Image(systemName: "list.triangle")
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(Circle())
                    .padding()
            }
        }
    }
    
    private func polygonsForLayer(named layer: String) -> MKMultiPolygon {
        switch layer {
        case "CAT":
            return pointsProvider.categorical
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
        .environmentObject(LocationManager())
}
