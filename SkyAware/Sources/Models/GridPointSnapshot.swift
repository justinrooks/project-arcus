//
//  GridPointSnapshot.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/3/26.
//

import Foundation

struct GridPointSnapshot: Sendable, Equatable {
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
    let forecastZone: String?
    let countyCode: String?
    let fireZone: String?
    let countyLabel: String?
    let fireZoneLabel: String?

    init(
        nwsId: String,
        latitude: Double,
        longitude: Double,
        gridId: String,
        gridX: Int,
        gridY: Int,
        forecastURL: URL?,
        forecastHourlyURL: URL?,
        forecastGridDataURL: URL?,
        observationStationsURL: URL?,
        city: String?,
        state: String?,
        timeZoneId: String?,
        radarStationId: String?,
        forecastZone: String?,
        countyCode: String?,
        fireZone: String?,
        countyLabel: String?,
        fireZoneLabel: String?
    ) {
        self.nwsId = nwsId
        self.latitude = latitude
        self.longitude = longitude
        self.gridId = gridId
        self.gridX = gridX
        self.gridY = gridY
        self.forecastURL = forecastURL
        self.forecastHourlyURL = forecastHourlyURL
        self.forecastGridDataURL = forecastGridDataURL
        self.observationStationsURL = observationStationsURL
        self.city = city
        self.state = state
        self.timeZoneId = timeZoneId
        self.radarStationId = radarStationId
        self.forecastZone = forecastZone
        self.countyCode = countyCode
        self.fireZone = fireZone
        self.countyLabel = countyLabel
        self.fireZoneLabel = fireZoneLabel
    }
    
    init(
        from: NWSGridPoint,
        with coordinates: Coordinate2D,
        countyLabel: String? = nil,
        fireZoneLabel: String? = nil
    ) {
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
        self.forecastZone           = props.forecastZone?.lastPathComponent
        self.countyCode             = props.county?.lastPathComponent
        self.fireZone               = props.fireWeatherZone?.lastPathComponent
        self.countyLabel            = countyLabel
        self.fireZoneLabel          = fireZoneLabel
    }
}
