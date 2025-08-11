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
    
    @State private var selectedLayer: String = "HAIL"
    
    private let availableLayers: [(key: String, label: String)] = [
        ("CAT", "Categorical"),
        ("TOR", "Tornado"),
        ("HAIL", "Hail"),
        ("WIND", "Wind"),
        ("MESO", "Mesoscale")
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
           .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            
            // Legend in bottom-right
            VStack {
                Spacer()
                switch selectedLayer {
                case "CAT":
                    LegendView()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .padding([.bottom, .trailing])
                case "TOR":
                    let probabilities = provider.tornado.compactMap { $0.probability }
                        .sorted { $0.intValue < $1.intValue }
                    SevereLegendView(probabilities: probabilities,
                                     legendLabel: "Tornado",
                                     risk: "TOR")
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .padding([.bottom, .trailing])
                case "HAIL":
                    let probabilities = provider.hail.compactMap { $0.probability }
                        .sorted { $0.intValue < $1.intValue }
                    SevereLegendView(probabilities: probabilities,
                                     legendLabel: "Hail",
                                     risk: "HAIL")
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .padding([.bottom, .trailing])
                case "WIND":
                    let probabilities = provider.wind.compactMap { $0.probability }
                        .sorted { $0.intValue < $1.intValue }
                    SevereLegendView(probabilities: probabilities,
                                     legendLabel: "Wind",
                                     risk: "WIND")
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .padding([.bottom, .trailing])
                default:
                    EmptyView()
                }
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
        case "MESO":
            let polys = provider.meso.compactMap() {
                let poly = MKPolygon(coordinates: $0.coordinates, count: $0.coordinates.count)
                poly.title = layer
                
                return poly
            }
            
            return MKMultiPolygon(polys)
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
