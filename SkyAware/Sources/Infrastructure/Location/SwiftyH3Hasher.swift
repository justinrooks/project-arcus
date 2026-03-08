//
//  SwiftyH3Hasher.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/8/26.
//

import CoreLocation
import Foundation
import SwiftyH3

protocol LocationHashing: Sendable {
    func h3Cell(for coord: CLLocationCoordinate2D) throws -> Int64
}

struct SwiftyH3Hasher: LocationHashing {
    let resolution: H3Cell.Resolution

    init(resolution: H3Cell.Resolution = .res8) {
        self.resolution = resolution
    }

    func h3Cell(for coord: CLLocationCoordinate2D) throws -> Int64 {
        let cell = try H3LatLng(coord).cell(at: resolution)
        
        return Int64(bitPattern: cell.id)
//        return cell.description
    }
}
