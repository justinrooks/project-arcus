//
//  MesoscaleDiscussion.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/11/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class MD {
    var id: UUID                // usually the GUID or derived from it
    @Attribute(.unique) var number: Int             // the MD number 1895
    var title: String           // e.g., "Day 1 Convective Outlook"
    var link: URL               // link to full outlook page
    var issued: Date            // Issued Date
    var validStart: Date        // Valid start
    var validEnd: Date          // Valid end
    var areasAffected: String   // locations affected by the meso
    var summary: String         // description / CDATA
    var concerning: String?     // e.g. "Severe potential... Watch unlikely"
    
    var watchProbability: String
    var threats: MDThreats?
    var coordinates: [Coordinate2D]
    
    var minLat: Double?
    var maxLat: Double?
    var minLon: Double?
    var maxLon: Double?
    
    var alertType: AlertType    // type of alert to conform to AlertItem

    convenience init? (from dto: MdDTO) {
        self.init(
            number: dto.number,
            title: dto.title,
            link: dto.link,
            issued: dto.issued,
            validStart: dto.validStart,
            validEnd: dto.validEnd,
            areasAffected: dto.areasAffected,
            summary: dto.summary,
            concerning: dto.concerning,
            watchProbability: String(dto.watchProbability),
            threats: dto.threats,
            coordinates: dto.coordinates,
            alertType: .mesoscale
        )
    }
    
    init(number: Int, title: String, link: URL, issued: Date, validStart: Date, validEnd: Date, areasAffected: String, summary: String, concerning: String? = nil, watchProbability: String, threats: MDThreats?, coordinates: [Coordinate2D], alertType: AlertType) {
        self.id = UUID()
        self.number = number
        self.title = title
        self.link = link
        self.issued = issued
        self.validStart = validStart
        self.validEnd = validEnd
        self.areasAffected = areasAffected
        self.summary = summary
        self.concerning = concerning
        self.watchProbability = watchProbability
        self.threats = threats
        self.coordinates = coordinates
        
        if !coordinates.isEmpty {
            let lats = coordinates.map(\.latitude)
            let lons = coordinates.map(\.longitude)
            
            self.minLat = lats.min()
            self.maxLat = lats.max()
            self.minLon = lons.min()
            self.maxLon = lons.max()
        } else {
            self.minLat = nil
            self.maxLat = nil
            self.minLon = nil
            self.maxLon = nil
        }
        
        self.alertType = alertType
    }
}

struct MDThreats: Sendable, Codable, Hashable {
    var peakWindMPH: Int?            // e.g. 60
    var hailRangeInches: Double? // e.g. 1.5...2.5
    var tornadoStrength: String?     // e.g. "Brief / weak", "EF1+ possible", or nil
}

struct GeoBBox: Sendable {
    let minLat: Double, maxLat: Double, minLon: Double, maxLon: Double
    
    func contains(_ p: CLLocationCoordinate2D) -> Bool {
        p.latitude >= minLat && p.latitude <= maxLat &&
        p.longitude >= minLon && p.longitude <= maxLon
    }
}

extension MD {
    nonisolated var ringCoordinates: [CLLocationCoordinate2D] {
        coordinates.map { $0.location }
    }
    
    nonisolated var bbox: GeoBBox? {
        guard let minLat, let maxLat, let minLon, let maxLon else { return nil }
        
        return GeoBBox(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }
    
    func updateDerivedBBox() {
        if !coordinates.isEmpty {
            let lats = coordinates.map(\.latitude)
            let lons = coordinates.map(\.longitude)
            
            self.minLat = lats.min()
            self.maxLat = lats.max()
            self.minLon = lons.min()
            self.maxLon = lons.max()
        } else {
            self.minLat = nil
            self.maxLat = nil
            self.minLon = nil
            self.maxLon = nil
        }
    }
}
