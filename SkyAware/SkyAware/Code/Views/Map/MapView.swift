//
//  MapView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import MapKit

struct MapView: View {
    @Environment(SpcProvider.self) private var provider: SpcProvider
    
    @State private var selectedLayer: String = "CAT"
    
    private let availableLayers: [(key: String, label: String)] = [
        ("CAT", "Categorical"),
        ("TOR", "Tornado"),
        ("HAIL", "Hail"),
        ("WIND", "Wind")
    ]
    
    var body: some View {
        ZStack {
            CONUSMapView(polygonList: polygonsForLayer(named: selectedLayer))
                .edgesIgnoringSafeArea(.top)
            
            VStack {
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
               Spacer()
           }
           .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Legend in bottom-right
            VStack {
                Spacer()
                LegendView()
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding([.bottom, .trailing])
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
    
    private func polygonsForLayer(named layer: String) -> MKMultiPolygon {
        switch layer {
        case "CAT":
            return MKMultiPolygon(provider.categorical.flatMap {$0.polygons}) //provider.categorical
        case "TOR":
            return MKMultiPolygon(provider.tornado.flatMap {$0.polygons})
        case "HAIL":
            return MKMultiPolygon(provider.hail.flatMap {$0.polygons})
        case "WIND":
            return MKMultiPolygon(provider.wind.flatMap {$0.polygons})
        default:
            return MKMultiPolygon()
        }
    }
}

#Preview {
    MapView()
        .environment(LocationManager())
        .environment(SpcProvider())
}
