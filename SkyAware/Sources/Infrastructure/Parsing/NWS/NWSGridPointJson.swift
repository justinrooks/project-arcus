//
//  NWSGridPointJson.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/23/25.
//

import Foundation

/// Top-level feature for /points
struct NWSGridPoint: Decodable {
//    let context: [String]?
    let id: String
    let type: String
    let geometry: NWSGeometryDTO?
    let properties: NWSGridPointProperties

    enum CodingKeys: String, CodingKey {
//        case context = "@context"
        case id
        case type
        case geometry
        case properties
    }
}

/// Properties block of the /points response
struct NWSGridPointProperties: Decodable {
    let context: [String]?
    let geometry: String?
    let id: String?
    let type: String?

    let cwa: String?
    let forecastOffice: String?
    let gridId: String
    let gridX: Int
    let gridY: Int

    let forecast: URL?
    let forecastHourly: URL?
    let forecastGridData: URL?
    let observationStations: URL?

    let relativeLocation: NWSRelativeLocation?

    let forecastZone: URL?
    let county: URL?
    let fireWeatherZone: URL?

    let timeZone: String?
    let radarStation: String?

    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case geometry
        case id = "@id"
        case type = "@type"

        case cwa
        case forecastOffice
        case gridId
        case gridX
        case gridY

        case forecast
        case forecastHourly
        case forecastGridData
        case observationStations

        case relativeLocation

        case forecastZone
        case county
        case fireWeatherZone

        case timeZone
        case radarStation
    }
}

/// Nested "relativeLocation" feature
struct NWSRelativeLocation: Decodable {
    let context: [String]?
    let id: String?
    let type: String?
    let geometry: NWSGeometryDTO?
    let properties: NWSRelativeLocationProperties

    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case type
        case geometry
        case properties
    }
}

struct NWSRelativeLocationProperties: Decodable {
    let city: String?
    let state: String?
    let distance: NWSMeasurement?
    let bearing: NWSMeasurement?
}

/// Used for "distance" and "bearing"
struct NWSMeasurement: Decodable {
    let value: Double?
    let maxValue: Double?
    let minValue: Double?
    let unitCode: String?
    let qualityControl: String?
}
