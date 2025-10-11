//
//  LocationService.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/6/25.
//

import CoreLocation

protocol LocationService: AnyObject {
    func start()
    func stop()
    
    var onUpdate: ((CLLocationCoordinate2D, Date, CLLocationAccuracy) -> Void)? { get set }
    var onAuthChange: ((CLAuthorizationStatus) -> Void)? { get set }
}
