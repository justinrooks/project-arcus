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
        case "MESO":
            let polys = provider.meso.compactMap() {
                let poly = MKPolygon(coordinates: $0.coordinates, count: $0.coordinates.count)
                poly.title = layer
                
                return poly
            }
            
            return MKMultiPolygon(polys)
//            let coords = MesoGeometry.coordinates(from: """
//            
//               ATTN...WFO...DLH...MPX...DMX...FGF...FSD...ABR...
//            
//               LAT...LON   43289764 48459445 48459097 43289447 43289764
//            
//               MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
//            """)
//            let testPoly = MKPolygon(coordinates: coords ?? [], count: coords?.count ?? 0)
//            testPoly.title = "MESO"
//            
//            return MKMultiPolygon([testPoly])
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
