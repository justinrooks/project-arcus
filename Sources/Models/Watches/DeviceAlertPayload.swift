//
//  DeviceAlertPayload.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation
import ArcusCore

extension DeviceAlertGeometry {
    init?(encodedData: Data?) {
        guard let encodedData else {
            return nil
        }

        guard let geometry = try? JSONDecoder().decode(DeviceAlertGeometry.self, from: encodedData) else {
            return nil
        }

        self = geometry
    }

    var encodedData: Data? {
        try? JSONEncoder().encode(self)
    }
}
