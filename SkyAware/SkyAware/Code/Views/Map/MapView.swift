//
//  MapView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import MapKit
import SwiftData

struct MapView: View {
    @Environment(SpcProvider.self) private var provider: SpcProvider
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedLayer: String = "CAT"
    @State private var showLayerPicker = false
    
    @Query private var mesos: [MD]
    
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
                Button {
                    showLayerPicker = true
                } label: {
                    Image(systemName: "list.triangle")
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(Circle())
                        .padding()
                }
                .sheet(isPresented: $showLayerPicker) {
                    NavigationStack {
                        List {
                            ForEach(availableLayers, id: \.key) { layer in
                                Button {
                                    selectedLayer = layer.key
                                    showLayerPicker = false
                                } label: {
                                    HStack {
                                        Text(layer.label)
                                        if selectedLayer == layer.key {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .navigationTitle("Select Layer")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
//                .confirmationDialog("Select Layer", isPresented: $showLayerPicker) {
//                    ForEach(availableLayers, id: \.key) { layer in
//                        Button(layer.label) { selectedLayer = layer.key }.buttonStyle(.borderless)
//                    }
//                }
                
               Spacer()
           }
           .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            
            // Legend in bottom-right (stable container)
            VStack {
                Spacer()
                Group {
                    switch selectedLayer {
                    case "CAT":
                        LegendView()
                    case "TOR":
                        let probabilities = provider.tornado.compactMap { $0.probability }
                            .sorted { $0.intValue < $1.intValue }
                        SevereLegendView(probabilities: probabilities, risk: selectedLayer)
                    case "HAIL":
                        let probabilities = provider.hail.compactMap { $0.probability }
                            .sorted { $0.intValue < $1.intValue }
                        SevereLegendView(probabilities: probabilities, risk: selectedLayer)
                    case "WIND":
                        let probabilities = provider.wind.compactMap { $0.probability }
                            .sorted { $0.intValue < $1.intValue }
                        SevereLegendView(probabilities: probabilities, risk: selectedLayer)
                    default:
                        EmptyView()
                    }
                }
//                .transition(.opacity)
//                .animation(.default, value: selectedLayer)
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
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
            let polys = mesos.compactMap() {
                let coord = $0.coordinates.map { $0.location }
                let poly = MKPolygon(coordinates: coord, count: coord.count)
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
    let preview = Preview(MD.self)
    preview.addExamples(MD.sampleDiscussions)
    let provider = SpcProvider(client: SpcClient(),
                               container: preview.container,
                               autoLoad: false)
    
    return NavigationStack {
        MapView()
            .modelContainer(preview.container)
            .environment(provider)
            .environment(LocationManager())       // or a preconfigured preview instance
    }
}

