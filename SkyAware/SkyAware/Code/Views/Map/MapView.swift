//
//  MapView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject private var provider: SpcProvider
    
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
            return provider.categorical
        case "TOR":
            return provider.tornado
        case "HAIL":
            return provider.hail
        case "WIND":
            return provider.wind
        default:
            return MKMultiPolygon()
        }
    }
}

#Preview {
    MapView()
        .environmentObject(LocationManager())
}
