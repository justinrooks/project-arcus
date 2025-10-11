//
//  ForegroundLocationSvc.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/6/25.
//

import Foundation
import CoreLocation

final class ForegroundLocationSvc: NSObject, LocationService {
    private let manager = CLLocationManager()
    private let delegateProxy = DelegateProxy()
    
    var onUpdate: ((CLLocationCoordinate2D, Date, CLLocationAccuracy) -> Void)? {
        get { delegateProxy.onUpdate } set { delegateProxy.onUpdate = newValue }
    }
    
    var onAuthChange: ((CLAuthorizationStatus) -> Void)? {
         get { delegateProxy.onAuthChange } set { delegateProxy.onAuthChange = newValue }
    }
    
    override init() {
        super.init()
        manager.delegate = delegateProxy
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 1650
    }
    
    func start() { manager.startUpdatingLocation() }
    func stop() { manager.stopUpdatingLocation() }
}
