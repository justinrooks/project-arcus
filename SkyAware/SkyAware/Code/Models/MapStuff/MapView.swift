//
//  MapView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import MapKit

struct MapView: View {
    let polygons: MKMultiPolygon
    
    var body: some View {
        if !polygons.polygons.isEmpty {
            CONUSMapView(polygonList: polygons)
                .edgesIgnoringSafeArea(.top)
        } else {
            Text("No threat found")
        }
    }
}

#Preview {
    MapView(polygons: MKMultiPolygon([]))
}
