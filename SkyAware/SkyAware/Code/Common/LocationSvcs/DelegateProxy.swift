//
//  DelegateProxy.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/6/25.
//

import Foundation
import CoreLocation

final class DelegateProxy: NSObject, CLLocationManagerDelegate {
    var onUpdate: ((CLLocationCoordinate2D, Date, CLLocationAccuracy) -> Void)?
    var onAuthChange: ((CLAuthorizationStatus) -> Void)?

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        onAuthChange?(status)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        onUpdate?(loc.coordinate, loc.timestamp, loc.horizontalAccuracy)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // log if you like; don’t spam
    }
}
