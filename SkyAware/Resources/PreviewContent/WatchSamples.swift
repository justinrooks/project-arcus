//
//  WatchSamples.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/15/25.
//

import Foundation

extension Watch {
    static func buildNwsTornadoSample(
        ugcArray: [String] = [
            "ALC013",
            "ALC025",
            "ALC035",
            "ALC041",
            "ALC099",
            "ALC129",
            "ALC131",
            "COZ246"
        ],
        areaDesc: String = "Butler, AL; Clarke, AL; Conecuh, AL; Crenshaw, AL; Monroe, AL; Washington, AL; Wilcox, AL"
    ) -> String {
                ##"""
                {
                  "type": "FeatureCollection",
                  "features": [
                    {
                      "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.cfc6c16f6a710f26ac1510695362885161a510a0.002.1",
                      "type": "Feature",
                      "geometry": null,
                      "properties": {
                        "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.cfc6c16f6a710f26ac1510695362885161a510a0.002.1",
                        "@type": "wx:Alert",
                        "id": "urn:oid:2.49.0.1.840.0.cfc6c16f6a710f26ac1510695362885161a510a0.002.1",
                        "areaDesc": "\##(areaDesc)",
                        "geocode": {
                          "SAME": [
                            "001013",
                            "001025",
                            "001035",
                            "001041",
                            "001099",
                            "001129",
                            "001131"
                          ],
                          "UGC": \##(ugcArray)
                        },
                        "affectedZones": [
                          "https://api.weather.gov/zones/county/ALC013",
                          "https://api.weather.gov/zones/county/ALC025",
                          "https://api.weather.gov/zones/county/ALC035",
                          "https://api.weather.gov/zones/county/ALC041",
                          "https://api.weather.gov/zones/county/ALC099",
                          "https://api.weather.gov/zones/county/ALC129",
                          "https://api.weather.gov/zones/county/ALC131"
                        ],
                        "references": [
                          {
                            "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.f95cf0f79f72666950dffd7631c8e3ea59badf98.001.1",
                            "identifier": "urn:oid:2.49.0.1.840.0.f95cf0f79f72666950dffd7631c8e3ea59badf98.001.1",
                            "sender": "w-nws.webmaster@noaa.gov",
                            "sent": "2025-11-25T12:06:00-06:00"
                          }
                        ],
                        "sent": "2025-11-25T16:20:00-06:00",
                        "effective": "2025-11-25T16:20:00-06:00",
                        "onset": "2025-11-25T16:20:00-06:00",
                        "expires": "2025-11-25T18:00:00-06:00",
                        "ends": "2025-11-25T19:00:00-06:00",
                        "status": "Actual",
                        "messageType": "Update",
                        "category": "Met",
                        "severity": "Extreme",
                        "certainty": "Possible",
                        "urgency": "Future",
                        "event": "Tornado Watch",
                        "sender": "w-nws.webmaster@noaa.gov",
                        "senderName": "NWS Mobile AL",
                        "headline": "Tornado Watch issued November 25 at 4:20PM CST until November 25 at 6:00PM CST by NWS Mobile AL",
                        "description": "TORNADO WATCH 641 REMAINS VALID UNTIL 6 PM CST THIS EVENING FOR\nTHE FOLLOWING AREAS\n\nIN ALABAMA THIS WATCH INCLUDES 7 COUNTIES\n\nIN SOUTH CENTRAL ALABAMA\n\nBUTLER                CONECUH               CRENSHAW\nMONROE                WILCOX\n\nIN SOUTHWEST ALABAMA\n\nCLARKE                WASHINGTON\n\nTHIS INCLUDES THE CITIES OF BRANTLEY, CAMDEN, CHATOM, EVERGREEN,\nGREENVILLE, GROVE HILL, HOMEWOOD, JACKSON, LUVERNE, MILLRY,\nMONROEVILLE, PINE HILL, AND THOMASVILLE.",
                        "instruction": "Take shelter in an interior room of your home. If you are in a mobile home seek shelter in a storm shelter.",
                        "response": "Monitor",
                        "parameters": {
                          "AWIPSidentifier": [
                            "WCNMOB"
                          ],
                          "WMOidentifier": [
                            "WWUS64 KMOB 252220"
                          ],
                          "BLOCKCHANNEL": [
                            "EAS",
                            "NWEM",
                            "CMAS"
                          ],
                          "EAS-ORG": [
                            "WXR"
                          ],
                          "VTEC": [
                            "/O.CON.KMOB.TO.A.0641.000000T0000Z-251126T0000Z/"
                          ],
                          "eventEndingTime": [
                            "2025-11-25T18:00:00-06:00"
                          ]
                        },
                        "scope": "Public",
                        "code": "IPAWSv1.0",
                        "language": "en-US",
                        "web": "http://www.weather.gov",
                        "eventCode": {
                          "SAME": [
                            "TOA"
                          ],
                          "NationalWeatherService": [
                            "TOA"
                          ]
                        },
                        "replacedBy": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.0711ef43523e0b5667f883960792712aea1aac1b.001.1",
                        "replacedAt": "2025-11-25T17:57:00-06:00"
                      }
                    }
                ],
                  "title": "Watches, warnings, and advisories for 31.433058668587 N, 88.036333326417 W",
                  "updated": "2025-11-25T23:59:05+00:00",
                  "pagination": {
                    "next": "https://api.weather.gov/alerts?point=31.433058668587183,-88.0363333264173&limit=500&cursor=eyJ0IjoxNzYzNjE0ODAwLCJpIjoidXJuOm9pZDoyLjQ5LjAuMS44NDAuMC44MWYwOTdiZDFkMTNhMGUxMjA5NTQ3YmY0MGVlMDgwZjgwNTUwYjNlLjAwMS4xIn0%3D"
                  }
                }           
                """##
    }
    
    static let sampleWatchRows: [WatchRowDTO] = [
        WatchRowDTO(
            id: "urn:oid:2.49.0.1.840.0.cfc6c16f6a710f26ac1510695362885161a510a0.002.1",
            messageId: "urn:oid:2.49.0.1.840.0.cfc6c16f6a710f26ac1510695362885161a510a0.002.1",
            title: "Tornado Watch",
            headline: "Tornado Watch issued November 25 at 4:20PM CST until November 25 at 6:00PM CST by NWS Mobile AL",
            issued: ISO8601DateFormatter().date(from: "2025-11-25T22:20:00Z")!,   // 4:20 PM CST
            expires: ISO8601DateFormatter().date(from: "2025-11-26T00:00:00Z")!,  // 6:00 PM CST
            ends: ISO8601DateFormatter().date(from: "2026-01-23T00:23:00Z")!,  // 5:00 PM CST,
            messageType: "Alert",
            sender: "NWS Boulder CO",
            severity: "Extreme",
            urgency: "Future",
            certainty: "Actual",
            description: "TORNADO WATCH 641 REMAINS VALID UNTIL 6 PM CST THIS EVENING FOR\nTHE FOLLOWING AREAS\n\nIN ALABAMA THIS WATCH INCLUDES 7 COUNTIES\n\nIN SOUTH CENTRAL ALABAMA\n\nBUTLER                CONECUH               CRENSHAW\nMONROE                WILCOX\n\nIN SOUTHWEST ALABAMA\n\nCLARKE                WASHINGTON\n\nTHIS INCLUDES THE CITIES OF BRANTLEY, CAMDEN, CHATOM, EVERGREEN,\nGREENVILLE, GROVE HILL, HOMEWOOD, JACKSON, LUVERNE, MILLRY,\nMONROEVILLE, PINE HILL, AND THOMASVILLE.",
            instruction: nil,
            response: "Monitor",
            areaSummary: "Butler; Clarke; Conecuh; Crenshaw; Monroe; Washington; Wilcox (AL)"
        ),
        WatchRowDTO(
            id: "urn:oid:2.49.0.1.840.0.9b1e1a6b7c0f4f0f3b90c08d8d22e7a4e4d0a123.001.1",
            messageId: "urn:oid:2.49.0.1.840.0.9b1e1a6b7c0f4f0f3b90c08d8d22e7a4e4d0a123.001.1",
            title: "Severe Thunderstorm Watch",
            headline: "Severe T-Storm Watch issued November 25 at 4:20PM CST until November 25 at 6:00PM CST by NWS Mobile AL",
            issued: ISO8601DateFormatter().date(from: "2025-06-18T19:05:00Z")!,   // ~2:05 PM CDT
            expires: ISO8601DateFormatter().date(from: "2025-06-18T23:00:00Z")!,  // ~6:00 PM CDT
            ends: ISO8601DateFormatter().date(from: "2026-01-23T23:23:00Z")!,  // 5:00 PM CST,
            messageType: "Update",
            sender: "NWS Boulder CO",
            severity: "Severe",
            urgency: "Expected",
            certainty: "Actual",
            description: "TORNADO WATCH 641 REMAINS VALID UNTIL 6 PM CST THIS EVENING FOR\nTHE FOLLOWING AREAS\n\nIN ALABAMA THIS WATCH INCLUDES 7 COUNTIES\n\nIN SOUTH CENTRAL ALABAMA\n\nBUTLER                CONECUH               CRENSHAW\nMONROE                WILCOX\n\nIN SOUTHWEST ALABAMA\n\nCLARKE                WASHINGTON\n\nTHIS INCLUDES THE CITIES OF BRANTLEY, CAMDEN, CHATOM, EVERGREEN,\nGREENVILLE, GROVE HILL, HOMEWOOD, JACKSON, LUVERNE, MILLRY,\nMONROEVILLE, PINE HILL, AND THOMASVILLE.",
            instruction: nil,
            response: "Monitor",
            areaSummary: "Sedgwick; Butler; Harvey (KS)"
            
        ),
        WatchRowDTO(
            id: "urn:oid:2.49.0.1.840.0.2f6a9c1c0b5e44d6a9d3a33a9b7d8a0d88aa77bb.001.1",
            messageId: "urn:oid:2.49.0.1.840.0.2f6a9c1c0b5e44d6a9d3a33a9b7d8a0d88aa77bb.001.1",
            title: "Tornado Watch",
            headline: "Tornado Watch issued November 25 at 4:20PM CST until November 25 at 6:00PM CST by NWS Mobile AL",
            issued: ISO8601DateFormatter().date(from: "2025-05-06T20:10:00Z")!,   // ~3:10 PM CDT
            expires: ISO8601DateFormatter().date(from: "2025-05-07T01:00:00Z")!,  // ~8:00 PM CDT
            ends: ISO8601DateFormatter().date(from: "2025-11-26T00:23:00Z")!,  // 5:00 PM CST,
            messageType: "Alert",
            sender: "NWS Boulder CO",
            severity: "Extreme",
            urgency: "Immediate",
            certainty: "Possible",
            description: "TORNADO WATCH 641 REMAINS VALID UNTIL 6 PM CST THIS EVENING FOR\nTHE FOLLOWING AREAS\n\nIN ALABAMA THIS WATCH INCLUDES 7 COUNTIES\n\nIN SOUTH CENTRAL ALABAMA\n\nBUTLER                CONECUH               CRENSHAW\nMONROE                WILCOX\n\nIN SOUTHWEST ALABAMA\n\nCLARKE                WASHINGTON\n\nTHIS INCLUDES THE CITIES OF BRANTLEY, CAMDEN, CHATOM, EVERGREEN,\nGREENVILLE, GROVE HILL, HOMEWOOD, JACKSON, LUVERNE, MILLRY,\nMONROEVILLE, PINE HILL, AND THOMASVILLE.",
            instruction: nil,
            response: "Monitor",
            areaSummary: "Cleveland; McClain; Oklahoma; Pottawatomie (OK)"
            
        ),
        WatchRowDTO(
            id: "urn:oid:2.49.0.1.840.0.6a7e1d3c9c2e4b4ab06e2d5b5e6f7a8b9c0d1e2f.001.1",
            messageId: "urn:oid:2.49.0.1.840.0.6a7e1d3c9c2e4b4ab06e2d5b5e6f7a8b9c0d1e2f.001.1",
            title: "Severe Thunderstorm Watch",
            headline: "Severe T-Storm Watch issued November 25 at 4:20PM CST until November 25 at 6:00PM CST by NWS Mobile AL",
            issued: ISO8601DateFormatter().date(from: "2025-08-12T21:30:00Z")!,   // ~4:30 PM CDT
            expires: ISO8601DateFormatter().date(from: "2025-08-13T02:00:00Z")!,  // ~9:00 PM CDT
            ends: ISO8601DateFormatter().date(from: "2025-11-26T00:23:00Z")!,  // 5:00 PM CST,
            messageType: "Alert",
            sender: "NWS Boulder CO",
            severity: "Severe",
            urgency: "Expected",
            certainty: "Actual",
            description: "TORNADO WATCH 641 REMAINS VALID UNTIL 6 PM CST THIS EVENING FOR\nTHE FOLLOWING AREAS\n\nIN ALABAMA THIS WATCH INCLUDES 7 COUNTIES\n\nIN SOUTH CENTRAL ALABAMA\n\nBUTLER                CONECUH               CRENSHAW\nMONROE                WILCOX\n\nIN SOUTHWEST ALABAMA\n\nCLARKE                WASHINGTON\n\nTHIS INCLUDES THE CITIES OF BRANTLEY, CAMDEN, CHATOM, EVERGREEN,\nGREENVILLE, GROVE HILL, HOMEWOOD, JACKSON, LUVERNE, MILLRY,\nMONROEVILLE, PINE HILL, AND THOMASVILLE.",
            instruction: nil,
            response: "Monitor",
            areaSummary: "Douglas; Sarpy; Cass (NE) / Pottawattamie (IA)"
            
        ),
        WatchRowDTO(
            id: "urn:oid:2.49.0.1.840.0.0d1c2b3a4e5f60718293a4b5c6d7e8f901234567.001.1",
            messageId: "urn:oid:2.49.0.1.840.0.0d1c2b3a4e5f60718293a4b5c6d7e8f901234567.001.1",
            title: "Tornado Watch",
            headline: "Tornado Watch issued November 25 at 4:20PM CST until November 25 at 6:00PM CST by NWS Mobile AL",
            issued: ISO8601DateFormatter().date(from: "2025-09-27T23:45:00Z")!,   // ~6:45 PM CDT
            expires: ISO8601DateFormatter().date(from: "2025-09-28T04:00:00Z")!,  // ~11:00 PM CDT
            ends: ISO8601DateFormatter().date(from: "2025-11-26T00:23:00Z")!,  // 5:00 PM CST,
            messageType: "Update",
            sender: "NWS Boulder CO",
            severity: "Extreme",
            urgency: "Immediate",
            certainty: "Actual",
            description: "TORNADO WATCH 641 REMAINS VALID UNTIL 6 PM CST THIS EVENING FOR\nTHE FOLLOWING AREAS\n\nIN ALABAMA THIS WATCH INCLUDES 7 COUNTIES\n\nIN SOUTH CENTRAL ALABAMA\n\nBUTLER                CONECUH               CRENSHAW\nMONROE                WILCOX\n\nIN SOUTHWEST ALABAMA\n\nCLARKE                WASHINGTON\n\nTHIS INCLUDES THE CITIES OF BRANTLEY, CAMDEN, CHATOM, EVERGREEN,\nGREENVILLE, GROVE HILL, HOMEWOOD, JACKSON, LUVERNE, MILLRY,\nMONROEVILLE, PINE HILL, AND THOMASVILLE.",
            instruction: "Take shelter in an interior room of your home. If you are in a mobile home seek shelter in a storm shelter.",
            response: "Monitor",
            areaSummary: "Johnson; Wyandotte; Jackson (KS/MO metro)"
        )
    ]
    
    static var sampleWatches: [Watch] {
        let iso = ISO8601DateFormatter()

        return [
            // Tornado Watch (evening CST)
            Watch(
                nwsId: "urn:oid:2.49.0.1.840.0.cfc6c16f6a710f26ac1510695362885161a510a0.002.1",
                messageId: "urn:oid:2.49.0.1.840.0.cfc6c16f6a710f26ac1510695362885161a510a0.002.1",
                areaDesc: "Butler, AL; Clarke, AL; Conecuh, AL; Crenshaw, AL; Monroe, AL; Washington, AL; Wilcox, AL",
                ugcZones: ["ALC013", "ALC025", "ALC035", "ALC041", "ALC099", "ALC129", "ALC131"],
                sameCodes: ["001013", "001025", "001035", "001041", "001099", "001129", "001131"],
                sent: iso.date(from: "2025-11-25T22:20:00Z")!,
                effective: iso.date(from: "2025-11-25T22:20:00Z")!,
                onset: iso.date(from: "2025-11-25T22:20:00Z")!,
                expires: iso.date(from: "2025-11-26T00:00:00Z")!,
                ends: iso.date(from: "2025-11-26T00:00:00Z")!,
                status: "Actual",
                messageType: "Update",
                severity: "Extreme",
                certainty: "Possible",
                urgency: "Future",
                event: "Tornado Watch",
                headline: "Tornado Watch issued Nov 25 at 4:20 PM CST until Nov 25 at 6:00 PM CST by NWS Mobile AL",
                watchDescription: "TORNADO WATCH remains valid until 6 PM CST this evening. Primary threats include a couple tornadoes possible and damaging winds.",
                sender: "w-nws.webmaster@noaa.gov",
                instruction: "Take shelter in an interior room. Avoid windows. If in a mobile home, move to a sturdier shelter.",
                response: "Monitor"
            ),

            // Severe Thunderstorm Watch (afternoon CDT)
            Watch(
                nwsId: "urn:oid:2.49.0.1.840.0.9b1e1a6b7c0f4f0f3b90c08d8d22e7a4e4d0a123.001.1",
                messageId: "urn:oid:2.49.0.1.840.0.9b1e1a6b7c0f4f0f3b90c08d8d22e7a4e4d0a123.001.1",
                areaDesc: "Sedgwick, KS; Butler, KS; Harvey, KS",
                ugcZones: ["KSZ047", "KSZ048", "KSZ049"],
                sameCodes: ["020173", "020015", "020079"],
                sent: iso.date(from: "2025-06-18T19:05:00Z")!,
                effective: iso.date(from: "2025-06-18T19:05:00Z")!,
                onset: iso.date(from: "2025-06-18T19:10:00Z")!,
                expires: iso.date(from: "2025-06-18T23:00:00Z")!,
                ends: iso.date(from: "2025-06-18T23:00:00Z")!,
                status: "Actual",
                messageType: "Alert",
                severity: "Severe",
                certainty: "Observed",
                urgency: "Immediate",
                event: "Severe Thunderstorm Watch",
                headline: "Severe Thunderstorm Watch issued Jun 18 at 2:05 PM CDT until Jun 18 at 6:00 PM CDT by NWS Wichita KS",
                watchDescription: "Severe storms expected with large hail up to 1.5 inches and damaging wind gusts up to 70 mph possible.",
                sender: "w-nws.webmaster@noaa.gov",
                instruction: "Be prepared to seek sturdy shelter if warnings are issued. Secure outdoor objects.",
                response: "Monitor"
            ),

            // Tornado Watch (spring outbreak window)
            Watch(
                nwsId: "urn:oid:2.49.0.1.840.0.2f6a9c1c0b5e44d6a9d3a33a9b7d8a0d88aa77bb.001.1",
                messageId: "urn:oid:2.49.0.1.840.0.2f6a9c1c0b5e44d6a9d3a33a9b7d8a0d88aa77bb.001.1",
                areaDesc: "Cleveland, OK; McClain, OK; Oklahoma, OK; Pottawatomie, OK",
                ugcZones: ["OKC027", "OKC087", "OKC109", "OKC125"],
                sameCodes: ["040027", "040087", "040109", "040125"],
                sent: iso.date(from: "2025-05-06T20:10:00Z")!,
                effective: iso.date(from: "2025-05-06T20:10:00Z")!,
                onset: iso.date(from: "2025-05-06T20:15:00Z")!,
                expires: iso.date(from: "2025-05-07T01:00:00Z")!,
                ends: iso.date(from: "2025-05-07T01:00:00Z")!,
                status: "Actual",
                messageType: "Alert",
                severity: "Extreme",
                certainty: "Possible",
                urgency: "Immediate",
                event: "Tornado Watch",
                headline: "Tornado Watch issued May 6 at 3:10 PM CDT until May 6 at 8:00 PM CDT by NWS Norman OK",
                watchDescription: "Conditions favor supercells capable of tornadoes. Very large hail and damaging winds also possible.",
                sender: "w-nws.webmaster@noaa.gov",
                instruction: "Review your shelter plan now. Have multiple ways to receive warnings.",
                response: "Shelter"
            ),

            // Severe Thunderstorm Watch (late summer)
            Watch(
                nwsId: "urn:oid:2.49.0.1.840.0.6a7e1d3c9c2e4b4ab06e2d5b5e6f7a8b9c0d1e2f.001.1",
                messageId: "urn:oid:2.49.0.1.840.0.6a7e1d3c9c2e4b4ab06e2d5b5e6f7a8b9c0d1e2f.001.1",
                areaDesc: "Douglas, NE; Sarpy, NE; Cass, NE; Pottawattamie, IA",
                ugcZones: ["NEC055", "NEC153", "NEC025", "IAC155"],
                sameCodes: ["031055", "031153", "031025", "019155"],
                sent: iso.date(from: "2025-08-12T21:30:00Z")!,
                effective: iso.date(from: "2025-08-12T21:30:00Z")!,
                onset: iso.date(from: "2025-08-12T21:35:00Z")!,
                expires: iso.date(from: "2025-08-13T02:00:00Z")!,
                ends: iso.date(from: "2025-08-13T02:00:00Z")!,
                status: "Actual",
                messageType: "Alert",
                severity: "Severe",
                certainty: "Likely",
                urgency: "Expected",
                event: "Severe Thunderstorm Watch",
                headline: "Severe Thunderstorm Watch issued Aug 12 at 4:30 PM CDT until Aug 12 at 9:00 PM CDT by NWS Omaha/Valley NE",
                watchDescription: "Organized thunderstorms may produce damaging winds and hail. A line segment could develop toward evening.",
                sender: "w-nws.webmaster@noaa.gov",
                instruction: "Stay weather-aware this evening. If a warning is issued, move indoors away from windows.",
                response: "Monitor"
            )
        ]
    }
}
