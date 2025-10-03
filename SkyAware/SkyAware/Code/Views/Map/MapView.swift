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
    @Environment(\.spcService) private var svc: any SpcService
    
    @State private var selectedLayer: String = "CAT"
    @State private var showLayerPicker = false
    
    @State private var mesos: [MdDTO] = []
    @State private var stormRisk: [StormRiskDTO] = []
    @State private var severeRisks: [SevereRiskShapeDTO] = []
    
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
//                .sheet(isPresented: $showLayerPicker) {
//                    NavigationStack {
//                        List {
//                            ForEach(availableLayers, id: \.key) { layer in
//                                Button {
//                                    selectedLayer = layer.key
//                                    showLayerPicker = false
//                                } label: {
//                                    HStack {
//                                        Text(layer.label)
//                                        if selectedLayer == layer.key {
//                                            Spacer()
//                                            Image(systemName: "checkmark")
//                                                .foregroundStyle(.secondary)
//                                        }
//                                    }
//                                }
//                                .buttonStyle(.plain)
//                            }
//                        }
//                        .navigationTitle("Select Layer")
//                        .navigationBarTitleDisplayMode(.inline)
//                    }
//                    .presentationDetents([.medium])
//                    .presentationDragIndicator(.visible)
//                }
                .confirmationDialog("Select Layer", isPresented: $showLayerPicker) {
                    ForEach(availableLayers, id: \.key) { layer in
                        Button(layer.label) { selectedLayer = layer.key }
                    }
                }
                
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
                        SevereLegendView(probabilities: getProbability(for: .tornado), risk: selectedLayer)

////                        let prob = tornadoRisks.probabilities
////                        let probabilities = severeRisks
////                            .filter { $0.type == .tornado }
////                            .compactMap { $0.probability }
////                            .sorted { $0.intValue < $1.intValue }
////                        let probabilities = provider.tornado.compactMap { $0.probability }
////                            .sorted { $0.intValue < $1.intValue }
//
////                        SevereLegendView(probabilities: probabilities, risk: selectedLayer)
//                        if let tornadoRisks{
//                            SevereLegendView(probabilities: tornadoRisks.probabilities, risk: selectedLayer)
//                        }
                    case "HAIL":
                        SevereLegendView(probabilities: getProbability(for: .hail), risk: selectedLayer)
                    case "WIND":
                        SevereLegendView(probabilities: getProbability(for: .wind), risk: selectedLayer)
                    default:
                        EmptyView()
                    }
                }
                .transition(.opacity)
                .animation(.default, value: selectedLayer)
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding([.bottom, .trailing])
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .onAppear {
            Task {
                do {
                    severeRisks = try await svc.getSevereRiskShapes()
//                    async let dto = svc.getStormRiskMapData()
                    stormRisk = try await svc.getStormRiskMapData()
                    mesos = try await svc.getMesoMapData()
//                    stormRisk = try await dto.compactMap{ StormRisk(from: $0) }
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    private func getProbability(for type:ThreatType) -> [ThreatProbability] {
        severeRisks.filter { $0.type == type }
          .compactMap { $0.probabilities }
          .sorted { $0.intValue < $1.intValue }
    }
    
    // Helper to build MKPolygons from arbitrary sources
    private func makeMKPolygons<Element>(
        from source: [Element],
        coordinates: (Element) -> [CLLocationCoordinate2D],
        title: (Element) -> String?
    ) -> [MKPolygon] {
        source.map { element in
            let coords = coordinates(element)
            let mkPolygon = MKPolygon(coordinates: coords, count: coords.count)
            mkPolygon.title = title(element)
            return mkPolygon
        }
    }
    
    private func polygonsForLayer(named layer: String) -> MKMultiPolygon {
        switch layer {
        case "CAT":
            let source = stormRisk.flatMap { $0.polygons }
            let polygons = makeMKPolygons(
                from: source,
                coordinates: { $0.ringCoordinates },
                title: { $0.title }
            )
            return MKMultiPolygon(polygons)
        case "TOR":
//            return MKMultiPolygon(provider.tornado.flatMap {$0.polygons})
            let source = severeRisks
                .filter { $0.type == .tornado }
                .flatMap { $0.polygons }
            let polygons = makeMKPolygons(
                from: source,
                coordinates: { $0.ringCoordinates },
                title: { $0.title }
            )
            return MKMultiPolygon(polygons)
        case "HAIL":
            let source = severeRisks
                .filter { $0.type == .hail }
                .flatMap { $0.polygons }
            let polygons = makeMKPolygons(
                from: source,
                coordinates: { $0.ringCoordinates },
                title: { $0.title }
            )
            return MKMultiPolygon(polygons)
        case "WIND":
            let source = severeRisks
                .filter { $0.type == .wind }
                .flatMap { $0.polygons }
            let polygons = makeMKPolygons(
                from: source,
                coordinates: { $0.ringCoordinates },
                title: { $0.title }
            )
            return MKMultiPolygon(polygons)
        case "MESO":
            let polygons = makeMKPolygons(
                from: mesos,
                coordinates: { $0.coordinates.map { $0.location } },
                title: { _ in layer }
            )
            return MKMultiPolygon(polygons)
        default:
            return MKMultiPolygon()
        }
    }
}

#Preview {
    let preview = Preview(MD.self)
    preview.addExamples(MD.sampleDiscussions)
    let spcMock = MockSpcService(storm: .slight, severe: .tornado(probability: 0.10))
    
    return NavigationStack {
        MapView()
//            .modelContainer(preview.container)
            .environment(LocationManager())       // or a preconfigured preview instance
            .environment(\.spcService, spcMock)
    }
}
