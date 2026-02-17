//
//  GridPointSnapshot.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/3/26.
//

import Foundation

struct GridPointSnapshot {
    let nwsId: String
    let latitude: Double
    let longitude: Double
    let gridId: String
    let gridX: Int
    let gridY: Int
    let forecastURL: URL?
    let forecastHourlyURL: URL?
    let forecastGridDataURL: URL?
    let observationStationsURL: URL?
    let city: String?
    let state: String?
    let timeZoneId: String?
    let radarStationId: String?
    let zone: String?
    let county: String?
    let fireZone: String?
    
    init(from: NWSGridPoint, with coordinates: Coordinate2D) {
        let props = from.properties
        
        self.nwsId                  = props.id ?? ""
        self.latitude               = coordinates.latitude
        self.longitude              = coordinates.longitude
        self.gridId                 = props.gridId
        self.gridX                  = props.gridX
        self.gridY                  = props.gridY
        self.forecastURL            = props.forecast
        self.forecastHourlyURL      = props.forecastHourly
        self.forecastGridDataURL    = props.forecastGridData
        self.observationStationsURL = props.observationStations
        self.city                   = props.relativeLocation?.properties.city
        self.state                  = props.relativeLocation?.properties.state
        self.timeZoneId             = props.timeZone
        self.radarStationId         = props.radarStation
        self.zone                   = props.forecastZone?.lastPathComponent
        self.county                 = props.county?.lastPathComponent
        self.fireZone               = props.fireWeatherZone?.lastPathComponent
    }
}
