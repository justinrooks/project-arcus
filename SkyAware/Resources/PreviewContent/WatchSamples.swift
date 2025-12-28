//
//  WatchSamples.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/15/25.
//

import Foundation

extension WatchModel {
    static func buildNwsTornadoSample() -> String {
                """
                {
                  "@context": [
                    "https://geojson.org/geojson-ld/geojson-context.jsonld",
                    {
                      "@version": "1.1",
                      "wx": "https://api.weather.gov/ontology#",
                      "@vocab": "https://api.weather.gov/ontology#"
                    }
                  ],
                  "type": "FeatureCollection",
                  "features": [
                    {
                      "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.b65fb091e05fea08483f8f6b0c7c57f290315a18.001.1",
                      "type": "Feature",
                      "geometry": null,
                      "properties": {
                        "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.b65fb091e05fea08483f8f6b0c7c57f290315a18.001.1",
                        "@type": "wx:Alert",
                        "id": "urn:oid:2.49.0.1.840.0.b65fb091e05fea08483f8f6b0c7c57f290315a18.001.1",
                        "areaDesc": "Washington, AL",
                        "geocode": {
                          "SAME": [
                            "001129"
                          ],
                          "UGC": [
                            "ALC129"
                          ]
                        },
                        "affectedZones": [
                          "https://api.weather.gov/zones/county/ALC129"
                        ],
                        "references": [
                          {
                            "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.f95cf0f79f72666950dffd7631c8e3ea59badf98.001.1",
                            "identifier": "urn:oid:2.49.0.1.840.0.f95cf0f79f72666950dffd7631c8e3ea59badf98.001.1",
                            "sender": "w-nws.webmaster@noaa.gov",
                            "sent": "2025-11-25T12:06:00-06:00"
                          },
                          {
                            "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.cfc6c16f6a710f26ac1510695362885161a510a0.002.1",
                            "identifier": "urn:oid:2.49.0.1.840.0.cfc6c16f6a710f26ac1510695362885161a510a0.002.1",
                            "sender": "w-nws.webmaster@noaa.gov",
                            "sent": "2025-11-25T16:20:00-06:00"
                          }
                        ],
                        "sent": "2025-11-25T16:54:00-06:00",
                        "effective": "2025-11-25T16:54:00-06:00",
                        "onset": "2025-11-25T16:54:00-06:00",
                        "expires": "2025-11-25T17:10:07-06:00",
                        "ends": "2025-11-25T18:00:00-06:00",
                        "status": "Actual",
                        "messageType": "Cancel",
                        "category": "Met",
                        "severity": "Minor",
                        "certainty": "Observed",
                        "urgency": "Past",
                        "event": "Tornado Watch",
                        "sender": "w-nws.webmaster@noaa.gov",
                        "senderName": "NWS Mobile AL",
                        "headline": "The Tornado Watch has been cancelled.",
                        "description": "The Tornado Watch has been cancelled and is no longer in effect.",
                        "instruction": null,
                        "response": "AllClear",
                        "parameters": {
                          "AWIPSidentifier": [
                            "WCNMOB"
                          ],
                          "WMOidentifier": [
                            "WWUS64 KMOB 252254"
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
                            "/O.CAN.KMOB.TO.A.0641.000000T0000Z-251126T0000Z/"
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
                        }
                      }
                    },
                    {
                      "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.cfc6c16f6a710f26ac1510695362885161a510a0.002.1",
                      "type": "Feature",
                      "geometry": null,
                      "properties": {
                        "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.cfc6c16f6a710f26ac1510695362885161a510a0.002.1",
                        "@type": "wx:Alert",
                        "id": "urn:oid:2.49.0.1.840.0.cfc6c16f6a710f26ac1510695362885161a510a0.002.1",
                        "areaDesc": "Butler, AL; Clarke, AL; Conecuh, AL; Crenshaw, AL; Monroe, AL; Washington, AL; Wilcox, AL",
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
                          "UGC": [
                            "ALC013",
                            "ALC025",
                            "ALC035",
                            "ALC041",
                            "ALC099",
                            "ALC129",
                            "ALC131"
                          ]
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
                        "ends": "2025-11-25T18:00:00-06:00",
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
                        "instruction": null,
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
                    },
                    {
                      "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.f95cf0f79f72666950dffd7631c8e3ea59badf98.001.1",
                      "type": "Feature",
                      "geometry": null,
                      "properties": {
                        "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.f95cf0f79f72666950dffd7631c8e3ea59badf98.001.1",
                        "@type": "wx:Alert",
                        "id": "urn:oid:2.49.0.1.840.0.f95cf0f79f72666950dffd7631c8e3ea59badf98.001.1",
                        "areaDesc": "Butler, AL; Choctaw, AL; Clarke, AL; Conecuh, AL; Crenshaw, AL; Monroe, AL; Washington, AL; Wilcox, AL; Greene, MS; Perry, MS; Wayne, MS",
                        "geocode": {
                          "SAME": [
                            "001013",
                            "001023",
                            "001025",
                            "001035",
                            "001041",
                            "001099",
                            "001129",
                            "001131",
                            "028041",
                            "028111",
                            "028153"
                          ],
                          "UGC": [
                            "ALC013",
                            "ALC023",
                            "ALC025",
                            "ALC035",
                            "ALC041",
                            "ALC099",
                            "ALC129",
                            "ALC131",
                            "MSC041",
                            "MSC111",
                            "MSC153"
                          ]
                        },
                        "affectedZones": [
                          "https://api.weather.gov/zones/county/ALC013",
                          "https://api.weather.gov/zones/county/ALC023",
                          "https://api.weather.gov/zones/county/ALC025",
                          "https://api.weather.gov/zones/county/ALC035",
                          "https://api.weather.gov/zones/county/ALC041",
                          "https://api.weather.gov/zones/county/ALC099",
                          "https://api.weather.gov/zones/county/ALC129",
                          "https://api.weather.gov/zones/county/ALC131",
                          "https://api.weather.gov/zones/county/MSC041",
                          "https://api.weather.gov/zones/county/MSC111",
                          "https://api.weather.gov/zones/county/MSC153"
                        ],
                        "references": [],
                        "sent": "2025-11-25T12:06:00-06:00",
                        "effective": "2025-11-25T12:06:00-06:00",
                        "onset": "2025-11-25T12:06:00-06:00",
                        "expires": "2025-11-25T18:00:00-06:00",
                        "ends": "2025-11-25T18:00:00-06:00",
                        "status": "Actual",
                        "messageType": "Alert",
                        "category": "Met",
                        "severity": "Extreme",
                        "certainty": "Possible",
                        "urgency": "Future",
                        "event": "Tornado Watch",
                        "sender": "w-nws.webmaster@noaa.gov",
                        "senderName": "NWS Mobile AL",
                        "headline": "Tornado Watch issued November 25 at 12:06PM CST until November 25 at 6:00PM CST by NWS Mobile AL",
                        "description": "THE NATIONAL WEATHER SERVICE HAS ISSUED TORNADO WATCH 641 IN\nEFFECT UNTIL 6 PM CST THIS EVENING FOR THE FOLLOWING AREAS\n\nIN ALABAMA THIS WATCH INCLUDES 8 COUNTIES\n\nIN SOUTH CENTRAL ALABAMA\n\nBUTLER                CONECUH               CRENSHAW\nMONROE                WILCOX\n\nIN SOUTHWEST ALABAMA\n\nCHOCTAW               CLARKE                WASHINGTON\n\nIN MISSISSIPPI THIS WATCH INCLUDES 3 COUNTIES\n\nIN SOUTHEAST MISSISSIPPI\n\nGREENE                PERRY                 WAYNE\n\nTHIS INCLUDES THE CITIES OF BEAUMONT, BRANTLEY, BUTLER, CAMDEN,\nCHATOM, EVERGREEN, GREENVILLE, GROVE HILL, HOMEWOOD, JACKSON,\nLEAKESVILLE, LISMAN, LUVERNE, MCLAIN, MILLRY, MONROEVILLE,\nNEW AUGUSTA, PINE HILL, RICHTON, SILAS, THOMASVILLE,\nAND WAYNESBORO.",
                        "instruction": null,
                        "response": "Monitor",
                        "parameters": {
                          "AWIPSidentifier": [
                            "WCNMOB"
                          ],
                          "WMOidentifier": [
                            "WWUS64 KMOB 251806"
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
                            "/O.NEW.KMOB.TO.A.0641.251125T1806Z-251126T0000Z/"
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
                    },
                    {
                      "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.8a7adfb84cdeb7c9c1183801c7ac53357ed67f0b.002.1",
                      "type": "Feature",
                      "geometry": null,
                      "properties": {
                        "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.8a7adfb84cdeb7c9c1183801c7ac53357ed67f0b.002.1",
                        "@type": "wx:Alert",
                        "id": "urn:oid:2.49.0.1.840.0.8a7adfb84cdeb7c9c1183801c7ac53357ed67f0b.002.1",
                        "areaDesc": "Choctaw; Washington; Clarke; Wilcox; Monroe; Conecuh; Butler; Crenshaw; Escambia; Covington; Mobile Inland; Baldwin Inland; Wayne; Perry; Greene; Stone; George",
                        "geocode": {
                          "SAME": [
                            "001023",
                            "001129",
                            "001025",
                            "001131",
                            "001099",
                            "001035",
                            "001013",
                            "001041",
                            "001053",
                            "001039",
                            "001097",
                            "001003",
                            "028153",
                            "028111",
                            "028041",
                            "028131",
                            "028039"
                          ],
                          "UGC": [
                            "ALZ051",
                            "ALZ052",
                            "ALZ053",
                            "ALZ054",
                            "ALZ055",
                            "ALZ056",
                            "ALZ057",
                            "ALZ058",
                            "ALZ059",
                            "ALZ060",
                            "ALZ261",
                            "ALZ262",
                            "MSZ067",
                            "MSZ075",
                            "MSZ076",
                            "MSZ078",
                            "MSZ079"
                          ]
                        },
                        "affectedZones": [
                          "https://api.weather.gov/zones/forecast/ALZ051",
                          "https://api.weather.gov/zones/forecast/ALZ052",
                          "https://api.weather.gov/zones/forecast/ALZ053",
                          "https://api.weather.gov/zones/forecast/ALZ054",
                          "https://api.weather.gov/zones/forecast/ALZ055",
                          "https://api.weather.gov/zones/forecast/ALZ056",
                          "https://api.weather.gov/zones/forecast/ALZ057",
                          "https://api.weather.gov/zones/forecast/ALZ058",
                          "https://api.weather.gov/zones/forecast/ALZ059",
                          "https://api.weather.gov/zones/forecast/ALZ060",
                          "https://api.weather.gov/zones/forecast/ALZ261",
                          "https://api.weather.gov/zones/forecast/ALZ262",
                          "https://api.weather.gov/zones/forecast/MSZ067",
                          "https://api.weather.gov/zones/forecast/MSZ075",
                          "https://api.weather.gov/zones/forecast/MSZ076",
                          "https://api.weather.gov/zones/forecast/MSZ078",
                          "https://api.weather.gov/zones/forecast/MSZ079"
                        ],
                        "references": [
                          {
                            "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.227f383b983ce78bb1ffc98cd9581029b6ec7526.001.1",
                            "identifier": "urn:oid:2.49.0.1.840.0.227f383b983ce78bb1ffc98cd9581029b6ec7526.001.1",
                            "sender": "w-nws.webmaster@noaa.gov",
                            "sent": "2025-11-24T04:13:00-06:00"
                          }
                        ],
                        "sent": "2025-11-24T07:53:00-06:00",
                        "effective": "2025-11-24T07:53:00-06:00",
                        "onset": "2025-11-24T07:53:00-06:00",
                        "expires": "2025-11-24T10:00:00-06:00",
                        "ends": "2025-11-24T10:00:00-06:00",
                        "status": "Actual",
                        "messageType": "Update",
                        "category": "Met",
                        "severity": "Moderate",
                        "certainty": "Likely",
                        "urgency": "Expected",
                        "event": "Dense Fog Advisory",
                        "sender": "w-nws.webmaster@noaa.gov",
                        "senderName": "NWS Mobile AL",
                        "headline": "Dense Fog Advisory issued November 24 at 7:53AM CST until November 24 at 10:00AM CST by NWS Mobile AL",
                        "description": "* WHAT...Visibility one quarter mile or less in dense fog.\n\n* WHERE...Portions of south central and southwest Alabama and\nsoutheast Mississippi.\n\n* WHEN...Until 10 AM CST this morning.\n\n* IMPACTS...Low visibility could make driving conditions hazardous.",
                        "instruction": "If driving, slow down, use your headlights, and leave plenty of\ndistance ahead of you.",
                        "response": "Execute",
                        "parameters": {
                          "AWIPSidentifier": [
                            "NPWMOB"
                          ],
                          "WMOidentifier": [
                            "WWUS74 KMOB 241353"
                          ],
                          "NWSheadline": [
                            "DENSE FOG ADVISORY NOW IN EFFECT UNTIL 10 AM CST THIS MORNING"
                          ],
                          "BLOCKCHANNEL": [
                            "EAS",
                            "NWEM",
                            "CMAS"
                          ],
                          "VTEC": [
                            "/O.EXT.KMOB.FG.Y.0034.000000T0000Z-251124T1600Z/"
                          ],
                          "eventEndingTime": [
                            "2025-11-24T10:00:00-06:00"
                          ]
                        },
                        "scope": "Public",
                        "code": "IPAWSv1.0",
                        "language": "en-US",
                        "web": "http://www.weather.gov",
                        "eventCode": {
                          "SAME": [
                            "NWS"
                          ],
                          "NationalWeatherService": [
                            "FGY"
                          ]
                        }
                      }
                    },
                    {
                      "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.227f383b983ce78bb1ffc98cd9581029b6ec7526.001.1",
                      "type": "Feature",
                      "geometry": null,
                      "properties": {
                        "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.227f383b983ce78bb1ffc98cd9581029b6ec7526.001.1",
                        "@type": "wx:Alert",
                        "id": "urn:oid:2.49.0.1.840.0.227f383b983ce78bb1ffc98cd9581029b6ec7526.001.1",
                        "areaDesc": "Choctaw; Washington; Clarke; Wilcox; Monroe; Conecuh; Butler; Crenshaw; Escambia; Covington; Mobile Inland; Baldwin Inland; Wayne; Perry; Greene; Stone; George",
                        "geocode": {
                          "SAME": [
                            "001023",
                            "001129",
                            "001025",
                            "001131",
                            "001099",
                            "001035",
                            "001013",
                            "001041",
                            "001053",
                            "001039",
                            "001097",
                            "001003",
                            "028153",
                            "028111",
                            "028041",
                            "028131",
                            "028039"
                          ],
                          "UGC": [
                            "ALZ051",
                            "ALZ052",
                            "ALZ053",
                            "ALZ054",
                            "ALZ055",
                            "ALZ056",
                            "ALZ057",
                            "ALZ058",
                            "ALZ059",
                            "ALZ060",
                            "ALZ261",
                            "ALZ262",
                            "MSZ067",
                            "MSZ075",
                            "MSZ076",
                            "MSZ078",
                            "MSZ079"
                          ]
                        },
                        "affectedZones": [
                          "https://api.weather.gov/zones/forecast/ALZ051",
                          "https://api.weather.gov/zones/forecast/ALZ052",
                          "https://api.weather.gov/zones/forecast/ALZ053",
                          "https://api.weather.gov/zones/forecast/ALZ054",
                          "https://api.weather.gov/zones/forecast/ALZ055",
                          "https://api.weather.gov/zones/forecast/ALZ056",
                          "https://api.weather.gov/zones/forecast/ALZ057",
                          "https://api.weather.gov/zones/forecast/ALZ058",
                          "https://api.weather.gov/zones/forecast/ALZ059",
                          "https://api.weather.gov/zones/forecast/ALZ060",
                          "https://api.weather.gov/zones/forecast/ALZ261",
                          "https://api.weather.gov/zones/forecast/ALZ262",
                          "https://api.weather.gov/zones/forecast/MSZ067",
                          "https://api.weather.gov/zones/forecast/MSZ075",
                          "https://api.weather.gov/zones/forecast/MSZ076",
                          "https://api.weather.gov/zones/forecast/MSZ078",
                          "https://api.weather.gov/zones/forecast/MSZ079"
                        ],
                        "references": [],
                        "sent": "2025-11-24T04:13:00-06:00",
                        "effective": "2025-11-24T04:13:00-06:00",
                        "onset": "2025-11-24T04:13:00-06:00",
                        "expires": "2025-11-24T08:00:00-06:00",
                        "ends": "2025-11-24T08:00:00-06:00",
                        "status": "Actual",
                        "messageType": "Alert",
                        "category": "Met",
                        "severity": "Moderate",
                        "certainty": "Likely",
                        "urgency": "Expected",
                        "event": "Dense Fog Advisory",
                        "sender": "w-nws.webmaster@noaa.gov",
                        "senderName": "NWS Mobile AL",
                        "headline": "Dense Fog Advisory issued November 24 at 4:13AM CST until November 24 at 8:00AM CST by NWS Mobile AL",
                        "description": "* WHAT...Visibility one quarter mile or less in dense fog.\n\n* WHERE...Portions of south central and southwest Alabama and\nsoutheast Mississippi.\n\n* WHEN...Until 8 AM CST this morning.\n\n* IMPACTS...Low visibility could make driving conditions hazardous.",
                        "instruction": "If driving, slow down, use your headlights, and leave plenty of\ndistance ahead of you.",
                        "response": "Execute",
                        "parameters": {
                          "AWIPSidentifier": [
                            "NPWMOB"
                          ],
                          "WMOidentifier": [
                            "WWUS74 KMOB 241013"
                          ],
                          "NWSheadline": [
                            "DENSE FOG ADVISORY IN EFFECT UNTIL 8 AM CST THIS MORNING"
                          ],
                          "BLOCKCHANNEL": [
                            "EAS",
                            "NWEM",
                            "CMAS"
                          ],
                          "VTEC": [
                            "/O.NEW.KMOB.FG.Y.0034.251124T1013Z-251124T1400Z/"
                          ],
                          "eventEndingTime": [
                            "2025-11-24T08:00:00-06:00"
                          ]
                        },
                        "scope": "Public",
                        "code": "IPAWSv1.0",
                        "language": "en-US",
                        "web": "http://www.weather.gov",
                        "eventCode": {
                          "SAME": [
                            "NWS"
                          ],
                          "NationalWeatherService": [
                            "FGY"
                          ]
                        },
                        "replacedBy": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.8a7adfb84cdeb7c9c1183801c7ac53357ed67f0b.002.1",
                        "replacedAt": "2025-11-24T07:53:00-06:00"
                      }
                    },
                    {
                      "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.1f729ae100f0dda9c47e7918761de1c3b06eb9ba.001.1",
                      "type": "Feature",
                      "geometry": null,
                      "properties": {
                        "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.1f729ae100f0dda9c47e7918761de1c3b06eb9ba.001.1",
                        "@type": "wx:Alert",
                        "id": "urn:oid:2.49.0.1.840.0.1f729ae100f0dda9c47e7918761de1c3b06eb9ba.001.1",
                        "areaDesc": "Choctaw; Washington; Clarke; Wilcox; Monroe; Conecuh; Butler; Crenshaw; Escambia; Covington; Mobile Inland; Baldwin Inland; Mobile Central; Baldwin Central; Mobile Coastal; Baldwin Coastal; Escambia Inland; Escambia Coastal; Santa Rosa Inland; Santa Rosa Coastal; Okaloosa Inland; Okaloosa Coastal; Wayne; Perry; Greene; Stone; George",
                        "geocode": {
                          "SAME": [
                            "001023",
                            "001129",
                            "001025",
                            "001131",
                            "001099",
                            "001035",
                            "001013",
                            "001041",
                            "001053",
                            "001039",
                            "001097",
                            "001003",
                            "012033",
                            "012113",
                            "012091",
                            "028153",
                            "028111",
                            "028041",
                            "028131",
                            "028039"
                          ],
                          "UGC": [
                            "ALZ051",
                            "ALZ052",
                            "ALZ053",
                            "ALZ054",
                            "ALZ055",
                            "ALZ056",
                            "ALZ057",
                            "ALZ058",
                            "ALZ059",
                            "ALZ060",
                            "ALZ261",
                            "ALZ262",
                            "ALZ263",
                            "ALZ264",
                            "ALZ265",
                            "ALZ266",
                            "FLZ201",
                            "FLZ202",
                            "FLZ203",
                            "FLZ204",
                            "FLZ205",
                            "FLZ206",
                            "MSZ067",
                            "MSZ075",
                            "MSZ076",
                            "MSZ078",
                            "MSZ079"
                          ]
                        },
                        "affectedZones": [
                          "https://api.weather.gov/zones/forecast/ALZ051",
                          "https://api.weather.gov/zones/forecast/ALZ052",
                          "https://api.weather.gov/zones/forecast/ALZ053",
                          "https://api.weather.gov/zones/forecast/ALZ054",
                          "https://api.weather.gov/zones/forecast/ALZ055",
                          "https://api.weather.gov/zones/forecast/ALZ056",
                          "https://api.weather.gov/zones/forecast/ALZ057",
                          "https://api.weather.gov/zones/forecast/ALZ058",
                          "https://api.weather.gov/zones/forecast/ALZ059",
                          "https://api.weather.gov/zones/forecast/ALZ060",
                          "https://api.weather.gov/zones/forecast/ALZ261",
                          "https://api.weather.gov/zones/forecast/ALZ262",
                          "https://api.weather.gov/zones/forecast/ALZ263",
                          "https://api.weather.gov/zones/forecast/ALZ264",
                          "https://api.weather.gov/zones/forecast/ALZ265",
                          "https://api.weather.gov/zones/forecast/ALZ266",
                          "https://api.weather.gov/zones/forecast/FLZ201",
                          "https://api.weather.gov/zones/forecast/FLZ202",
                          "https://api.weather.gov/zones/forecast/FLZ203",
                          "https://api.weather.gov/zones/forecast/FLZ204",
                          "https://api.weather.gov/zones/forecast/FLZ205",
                          "https://api.weather.gov/zones/forecast/FLZ206",
                          "https://api.weather.gov/zones/forecast/MSZ067",
                          "https://api.weather.gov/zones/forecast/MSZ075",
                          "https://api.weather.gov/zones/forecast/MSZ076",
                          "https://api.weather.gov/zones/forecast/MSZ078",
                          "https://api.weather.gov/zones/forecast/MSZ079"
                        ],
                        "references": [
                          {
                            "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.7cff66890f92ba99240a5d1bfb4dd83a3bbcc5e5.001.1",
                            "identifier": "urn:oid:2.49.0.1.840.0.7cff66890f92ba99240a5d1bfb4dd83a3bbcc5e5.001.1",
                            "sender": "w-nws.webmaster@noaa.gov",
                            "sent": "2025-11-22T06:16:00-06:00"
                          }
                        ],
                        "sent": "2025-11-22T07:16:00-06:00",
                        "effective": "2025-11-22T07:16:00-06:00",
                        "onset": "2025-11-22T07:16:00-06:00",
                        "expires": "2025-11-22T07:31:23-06:00",
                        "ends": "2025-11-22T09:00:00-06:00",
                        "status": "Actual",
                        "messageType": "Cancel",
                        "category": "Met",
                        "severity": "Minor",
                        "certainty": "Observed",
                        "urgency": "Past",
                        "event": "Dense Fog Advisory",
                        "sender": "w-nws.webmaster@noaa.gov",
                        "senderName": "NWS Mobile AL",
                        "headline": "The Dense Fog Advisory has been cancelled.",
                        "description": "The Dense Fog Advisory has been cancelled and is no longer in effect.",
                        "instruction": null,
                        "response": "AllClear",
                        "parameters": {
                          "AWIPSidentifier": [
                            "NPWMOB"
                          ],
                          "WMOidentifier": [
                            "WWUS74 KMOB 221316"
                          ],
                          "NWSheadline": [
                            "DENSE FOG ADVISORY IS CANCELLED"
                          ],
                          "BLOCKCHANNEL": [
                            "EAS",
                            "NWEM",
                            "CMAS"
                          ],
                          "VTEC": [
                            "/O.CAN.KMOB.FG.Y.0033.000000T0000Z-251122T1500Z/"
                          ],
                          "eventEndingTime": [
                            "2025-11-22T09:00:00-06:00"
                          ],
                          "expiredReferences": [
                            "w-nws.webmaster@noaa.gov,urn:oid:2.49.0.1.840.0.dec98330004a75af0cee6b1e9ed75d7f0b1babe9.001.1,2025-11-21T22:00:00-06:00"
                          ]
                        },
                        "scope": "Public",
                        "code": "IPAWSv1.0",
                        "language": "en-US",
                        "web": "http://www.weather.gov",
                        "eventCode": {
                          "SAME": [
                            "NWS"
                          ],
                          "NationalWeatherService": [
                            "FGY"
                          ]
                        }
                      }
                    },
                    {
                      "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.7cff66890f92ba99240a5d1bfb4dd83a3bbcc5e5.001.1",
                      "type": "Feature",
                      "geometry": null,
                      "properties": {
                        "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.7cff66890f92ba99240a5d1bfb4dd83a3bbcc5e5.001.1",
                        "@type": "wx:Alert",
                        "id": "urn:oid:2.49.0.1.840.0.7cff66890f92ba99240a5d1bfb4dd83a3bbcc5e5.001.1",
                        "areaDesc": "Choctaw; Washington; Clarke; Wilcox; Monroe; Conecuh; Butler; Crenshaw; Escambia; Covington; Mobile Inland; Baldwin Inland; Mobile Central; Baldwin Central; Mobile Coastal; Baldwin Coastal; Escambia Inland; Escambia Coastal; Santa Rosa Inland; Santa Rosa Coastal; Okaloosa Inland; Okaloosa Coastal; Wayne; Perry; Greene; Stone; George",
                        "geocode": {
                          "SAME": [
                            "001023",
                            "001129",
                            "001025",
                            "001131",
                            "001099",
                            "001035",
                            "001013",
                            "001041",
                            "001053",
                            "001039",
                            "001097",
                            "001003",
                            "012033",
                            "012113",
                            "012091",
                            "028153",
                            "028111",
                            "028041",
                            "028131",
                            "028039"
                          ],
                          "UGC": [
                            "ALZ051",
                            "ALZ052",
                            "ALZ053",
                            "ALZ054",
                            "ALZ055",
                            "ALZ056",
                            "ALZ057",
                            "ALZ058",
                            "ALZ059",
                            "ALZ060",
                            "ALZ261",
                            "ALZ262",
                            "ALZ263",
                            "ALZ264",
                            "ALZ265",
                            "ALZ266",
                            "FLZ201",
                            "FLZ202",
                            "FLZ203",
                            "FLZ204",
                            "FLZ205",
                            "FLZ206",
                            "MSZ067",
                            "MSZ075",
                            "MSZ076",
                            "MSZ078",
                            "MSZ079"
                          ]
                        },
                        "affectedZones": [
                          "https://api.weather.gov/zones/forecast/ALZ051",
                          "https://api.weather.gov/zones/forecast/ALZ052",
                          "https://api.weather.gov/zones/forecast/ALZ053",
                          "https://api.weather.gov/zones/forecast/ALZ054",
                          "https://api.weather.gov/zones/forecast/ALZ055",
                          "https://api.weather.gov/zones/forecast/ALZ056",
                          "https://api.weather.gov/zones/forecast/ALZ057",
                          "https://api.weather.gov/zones/forecast/ALZ058",
                          "https://api.weather.gov/zones/forecast/ALZ059",
                          "https://api.weather.gov/zones/forecast/ALZ060",
                          "https://api.weather.gov/zones/forecast/ALZ261",
                          "https://api.weather.gov/zones/forecast/ALZ262",
                          "https://api.weather.gov/zones/forecast/ALZ263",
                          "https://api.weather.gov/zones/forecast/ALZ264",
                          "https://api.weather.gov/zones/forecast/ALZ265",
                          "https://api.weather.gov/zones/forecast/ALZ266",
                          "https://api.weather.gov/zones/forecast/FLZ201",
                          "https://api.weather.gov/zones/forecast/FLZ202",
                          "https://api.weather.gov/zones/forecast/FLZ203",
                          "https://api.weather.gov/zones/forecast/FLZ204",
                          "https://api.weather.gov/zones/forecast/FLZ205",
                          "https://api.weather.gov/zones/forecast/FLZ206",
                          "https://api.weather.gov/zones/forecast/MSZ067",
                          "https://api.weather.gov/zones/forecast/MSZ075",
                          "https://api.weather.gov/zones/forecast/MSZ076",
                          "https://api.weather.gov/zones/forecast/MSZ078",
                          "https://api.weather.gov/zones/forecast/MSZ079"
                        ],
                        "references": [],
                        "sent": "2025-11-22T06:16:00-06:00",
                        "effective": "2025-11-22T06:16:00-06:00",
                        "onset": "2025-11-22T06:16:00-06:00",
                        "expires": "2025-11-22T09:00:00-06:00",
                        "ends": "2025-11-22T09:00:00-06:00",
                        "status": "Actual",
                        "messageType": "Alert",
                        "category": "Met",
                        "severity": "Moderate",
                        "certainty": "Likely",
                        "urgency": "Expected",
                        "event": "Dense Fog Advisory",
                        "sender": "w-nws.webmaster@noaa.gov",
                        "senderName": "NWS Mobile AL",
                        "headline": "Dense Fog Advisory issued November 22 at 6:16AM CST until November 22 at 9:00AM CST by NWS Mobile AL",
                        "description": "* WHAT...Visibility one quarter mile or less in dense fog.\n\n* WHERE...Portions of south central and southwest Alabama, northwest\nFlorida, and southeast Mississippi.\n\n* WHEN...Until 9 AM CST this morning.\n\n* IMPACTS...Low visibility could make driving conditions hazardous.",
                        "instruction": "If driving, slow down, use your headlights, and leave plenty of\ndistance ahead of you.",
                        "response": "Execute",
                        "parameters": {
                          "AWIPSidentifier": [
                            "NPWMOB"
                          ],
                          "WMOidentifier": [
                            "WWUS74 KMOB 221216"
                          ],
                          "NWSheadline": [
                            "DENSE FOG ADVISORY REMAINS IN EFFECT UNTIL 9 AM CST THIS MORNING"
                          ],
                          "BLOCKCHANNEL": [
                            "EAS",
                            "NWEM",
                            "CMAS"
                          ],
                          "VTEC": [
                            "/O.CON.KMOB.FG.Y.0033.000000T0000Z-251122T1500Z/"
                          ],
                          "eventEndingTime": [
                            "2025-11-22T09:00:00-06:00"
                          ],
                          "expiredReferences": [
                            "w-nws.webmaster@noaa.gov,urn:oid:2.49.0.1.840.0.dec98330004a75af0cee6b1e9ed75d7f0b1babe9.001.1,2025-11-21T22:00:00-06:00"
                          ]
                        },
                        "scope": "Public",
                        "code": "IPAWSv1.0",
                        "language": "en-US",
                        "web": "http://www.weather.gov",
                        "eventCode": {
                          "SAME": [
                            "NWS"
                          ],
                          "NationalWeatherService": [
                            "FGY"
                          ]
                        },
                        "replacedBy": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.1f729ae100f0dda9c47e7918761de1c3b06eb9ba.001.1",
                        "replacedAt": "2025-11-22T07:16:00-06:00"
                      }
                    },
                    {
                      "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.dec98330004a75af0cee6b1e9ed75d7f0b1babe9.001.1",
                      "type": "Feature",
                      "geometry": null,
                      "properties": {
                        "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.dec98330004a75af0cee6b1e9ed75d7f0b1babe9.001.1",
                        "@type": "wx:Alert",
                        "id": "urn:oid:2.49.0.1.840.0.dec98330004a75af0cee6b1e9ed75d7f0b1babe9.001.1",
                        "areaDesc": "Choctaw; Washington; Clarke; Wilcox; Monroe; Conecuh; Butler; Crenshaw; Escambia; Covington; Mobile Inland; Baldwin Inland; Mobile Central; Baldwin Central; Mobile Coastal; Baldwin Coastal; Escambia Inland; Escambia Coastal; Santa Rosa Inland; Santa Rosa Coastal; Okaloosa Inland; Okaloosa Coastal; Wayne; Perry; Greene; Stone; George",
                        "geocode": {
                          "SAME": [
                            "001023",
                            "001129",
                            "001025",
                            "001131",
                            "001099",
                            "001035",
                            "001013",
                            "001041",
                            "001053",
                            "001039",
                            "001097",
                            "001003",
                            "012033",
                            "012113",
                            "012091",
                            "028153",
                            "028111",
                            "028041",
                            "028131",
                            "028039"
                          ],
                          "UGC": [
                            "ALZ051",
                            "ALZ052",
                            "ALZ053",
                            "ALZ054",
                            "ALZ055",
                            "ALZ056",
                            "ALZ057",
                            "ALZ058",
                            "ALZ059",
                            "ALZ060",
                            "ALZ261",
                            "ALZ262",
                            "ALZ263",
                            "ALZ264",
                            "ALZ265",
                            "ALZ266",
                            "FLZ201",
                            "FLZ202",
                            "FLZ203",
                            "FLZ204",
                            "FLZ205",
                            "FLZ206",
                            "MSZ067",
                            "MSZ075",
                            "MSZ076",
                            "MSZ078",
                            "MSZ079"
                          ]
                        },
                        "affectedZones": [
                          "https://api.weather.gov/zones/forecast/ALZ051",
                          "https://api.weather.gov/zones/forecast/ALZ052",
                          "https://api.weather.gov/zones/forecast/ALZ053",
                          "https://api.weather.gov/zones/forecast/ALZ054",
                          "https://api.weather.gov/zones/forecast/ALZ055",
                          "https://api.weather.gov/zones/forecast/ALZ056",
                          "https://api.weather.gov/zones/forecast/ALZ057",
                          "https://api.weather.gov/zones/forecast/ALZ058",
                          "https://api.weather.gov/zones/forecast/ALZ059",
                          "https://api.weather.gov/zones/forecast/ALZ060",
                          "https://api.weather.gov/zones/forecast/ALZ261",
                          "https://api.weather.gov/zones/forecast/ALZ262",
                          "https://api.weather.gov/zones/forecast/ALZ263",
                          "https://api.weather.gov/zones/forecast/ALZ264",
                          "https://api.weather.gov/zones/forecast/ALZ265",
                          "https://api.weather.gov/zones/forecast/ALZ266",
                          "https://api.weather.gov/zones/forecast/FLZ201",
                          "https://api.weather.gov/zones/forecast/FLZ202",
                          "https://api.weather.gov/zones/forecast/FLZ203",
                          "https://api.weather.gov/zones/forecast/FLZ204",
                          "https://api.weather.gov/zones/forecast/FLZ205",
                          "https://api.weather.gov/zones/forecast/FLZ206",
                          "https://api.weather.gov/zones/forecast/MSZ067",
                          "https://api.weather.gov/zones/forecast/MSZ075",
                          "https://api.weather.gov/zones/forecast/MSZ076",
                          "https://api.weather.gov/zones/forecast/MSZ078",
                          "https://api.weather.gov/zones/forecast/MSZ079"
                        ],
                        "references": [],
                        "sent": "2025-11-21T22:00:00-06:00",
                        "effective": "2025-11-21T22:00:00-06:00",
                        "onset": "2025-11-21T22:00:00-06:00",
                        "expires": "2025-11-22T06:00:00-06:00",
                        "ends": "2025-11-22T09:00:00-06:00",
                        "status": "Actual",
                        "messageType": "Alert",
                        "category": "Met",
                        "severity": "Moderate",
                        "certainty": "Likely",
                        "urgency": "Expected",
                        "event": "Dense Fog Advisory",
                        "sender": "w-nws.webmaster@noaa.gov",
                        "senderName": "NWS Mobile AL",
                        "headline": "Dense Fog Advisory issued November 21 at 10:00PM CST until November 22 at 9:00AM CST by NWS Mobile AL",
                        "description": "* WHAT...Visibility one quarter mile or less in dense fog.\n\n* WHERE...Portions of south central and southwest Alabama, northwest\nFlorida, and southeast Mississippi.\n\n* WHEN...Until 9 AM CST Saturday.\n\n* IMPACTS...Low visibility could make driving conditions hazardous.",
                        "instruction": "If driving, slow down, use your headlights, and leave plenty of\ndistance ahead of you.",
                        "response": "Execute",
                        "parameters": {
                          "AWIPSidentifier": [
                            "NPWMOB"
                          ],
                          "WMOidentifier": [
                            "WWUS74 KMOB 220400"
                          ],
                          "NWSheadline": [
                            "DENSE FOG ADVISORY IN EFFECT UNTIL 9 AM CST SATURDAY"
                          ],
                          "BLOCKCHANNEL": [
                            "EAS",
                            "NWEM",
                            "CMAS"
                          ],
                          "VTEC": [
                            "/O.NEW.KMOB.FG.Y.0033.251122T0400Z-251122T1500Z/"
                          ],
                          "eventEndingTime": [
                            "2025-11-22T09:00:00-06:00"
                          ]
                        },
                        "scope": "Public",
                        "code": "IPAWSv1.0",
                        "language": "en-US",
                        "web": "http://www.weather.gov",
                        "eventCode": {
                          "SAME": [
                            "NWS"
                          ],
                          "NationalWeatherService": [
                            "FGY"
                          ]
                        },
                        "replacedBy": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.1f729ae100f0dda9c47e7918761de1c3b06eb9ba.001.1",
                        "replacedAt": "2025-11-22T07:16:00-06:00"
                      }
                    },
                    {
                      "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.78446f612d18c86517e88e78c0e7c49ac7d0c698.002.1",
                      "type": "Feature",
                      "geometry": null,
                      "properties": {
                        "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.78446f612d18c86517e88e78c0e7c49ac7d0c698.002.1",
                        "@type": "wx:Alert",
                        "id": "urn:oid:2.49.0.1.840.0.78446f612d18c86517e88e78c0e7c49ac7d0c698.002.1",
                        "areaDesc": "Choctaw; Washington; Clarke; Mobile Inland; Baldwin Inland; Mobile Central; Baldwin Central; Mobile Coastal; Baldwin Coastal; Escambia Inland; Escambia Coastal; Santa Rosa Inland; Santa Rosa Coastal; Wayne; Perry; Greene; Stone; George",
                        "geocode": {
                          "SAME": [
                            "001023",
                            "001129",
                            "001025",
                            "001097",
                            "001003",
                            "012033",
                            "012113",
                            "028153",
                            "028111",
                            "028041",
                            "028131",
                            "028039"
                          ],
                          "UGC": [
                            "ALZ051",
                            "ALZ052",
                            "ALZ053",
                            "ALZ261",
                            "ALZ262",
                            "ALZ263",
                            "ALZ264",
                            "ALZ265",
                            "ALZ266",
                            "FLZ201",
                            "FLZ202",
                            "FLZ203",
                            "FLZ204",
                            "MSZ067",
                            "MSZ075",
                            "MSZ076",
                            "MSZ078",
                            "MSZ079"
                          ]
                        },
                        "affectedZones": [
                          "https://api.weather.gov/zones/forecast/ALZ051",
                          "https://api.weather.gov/zones/forecast/ALZ052",
                          "https://api.weather.gov/zones/forecast/ALZ053",
                          "https://api.weather.gov/zones/forecast/ALZ261",
                          "https://api.weather.gov/zones/forecast/ALZ262",
                          "https://api.weather.gov/zones/forecast/ALZ263",
                          "https://api.weather.gov/zones/forecast/ALZ264",
                          "https://api.weather.gov/zones/forecast/ALZ265",
                          "https://api.weather.gov/zones/forecast/ALZ266",
                          "https://api.weather.gov/zones/forecast/FLZ201",
                          "https://api.weather.gov/zones/forecast/FLZ202",
                          "https://api.weather.gov/zones/forecast/FLZ203",
                          "https://api.weather.gov/zones/forecast/FLZ204",
                          "https://api.weather.gov/zones/forecast/MSZ067",
                          "https://api.weather.gov/zones/forecast/MSZ075",
                          "https://api.weather.gov/zones/forecast/MSZ076",
                          "https://api.weather.gov/zones/forecast/MSZ078",
                          "https://api.weather.gov/zones/forecast/MSZ079"
                        ],
                        "references": [
                          {
                            "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.931d36ef99ffe037d6c3afdfaf60a58807ae6f19.001.1",
                            "identifier": "urn:oid:2.49.0.1.840.0.931d36ef99ffe037d6c3afdfaf60a58807ae6f19.001.1",
                            "sender": "w-nws.webmaster@noaa.gov",
                            "sent": "2025-11-20T06:57:00-06:00"
                          }
                        ],
                        "sent": "2025-11-20T08:53:00-06:00",
                        "effective": "2025-11-20T08:53:00-06:00",
                        "onset": "2025-11-20T08:53:00-06:00",
                        "expires": "2025-11-20T10:00:00-06:00",
                        "ends": "2025-11-20T10:00:00-06:00",
                        "status": "Actual",
                        "messageType": "Update",
                        "category": "Met",
                        "severity": "Moderate",
                        "certainty": "Likely",
                        "urgency": "Expected",
                        "event": "Dense Fog Advisory",
                        "sender": "w-nws.webmaster@noaa.gov",
                        "senderName": "NWS Mobile AL",
                        "headline": "Dense Fog Advisory issued November 20 at 8:53AM CST until November 20 at 10:00AM CST by NWS Mobile AL",
                        "description": "* WHAT...Visibility one quarter mile or less in dense fog.\n\n* WHERE...Portions of southwest Alabama, northwest Florida, and\nsoutheast Mississippi.\n\n* WHEN...Until 10 AM CST this morning.\n\n* IMPACTS...Low visibility could make driving conditions hazardous.",
                        "instruction": "If driving, slow down, use your headlights, and leave plenty of\ndistance ahead of you.",
                        "response": "Execute",
                        "parameters": {
                          "AWIPSidentifier": [
                            "NPWMOB"
                          ],
                          "WMOidentifier": [
                            "WWUS74 KMOB 201453"
                          ],
                          "NWSheadline": [
                            "DENSE FOG ADVISORY REMAINS IN EFFECT UNTIL 10 AM CST THIS MORNING"
                          ],
                          "BLOCKCHANNEL": [
                            "EAS",
                            "NWEM",
                            "CMAS"
                          ],
                          "VTEC": [
                            "/O.EXT.KMOB.FG.Y.0031.000000T0000Z-251120T1600Z/"
                          ],
                          "eventEndingTime": [
                            "2025-11-20T10:00:00-06:00"
                          ],
                          "expiredReferences": [
                            "w-nws.webmaster@noaa.gov,urn:oid:2.49.0.1.840.0.81f097bd1d13a0e1209547bf40ee080f80550b3e.001.1,2025-11-19T23:00:00-06:00 w-nws.webmaster@noaa.gov,urn:oid:2.49.0.1.840.0.4056e25e124a1a84da6fded45439cc6531d13f93.001.1,2025-11-19T15:03:00-06:00"
                          ]
                        },
                        "scope": "Public",
                        "code": "IPAWSv1.0",
                        "language": "en-US",
                        "web": "http://www.weather.gov",
                        "eventCode": {
                          "SAME": [
                            "NWS"
                          ],
                          "NationalWeatherService": [
                            "FGY"
                          ]
                        }
                      }
                    },
                    {
                      "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.931d36ef99ffe037d6c3afdfaf60a58807ae6f19.001.1",
                      "type": "Feature",
                      "geometry": null,
                      "properties": {
                        "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.931d36ef99ffe037d6c3afdfaf60a58807ae6f19.001.1",
                        "@type": "wx:Alert",
                        "id": "urn:oid:2.49.0.1.840.0.931d36ef99ffe037d6c3afdfaf60a58807ae6f19.001.1",
                        "areaDesc": "Choctaw; Washington; Clarke; Wilcox; Monroe; Conecuh; Butler; Crenshaw; Escambia; Covington; Mobile Inland; Baldwin Inland; Mobile Central; Baldwin Central; Mobile Coastal; Baldwin Coastal; Escambia Inland; Escambia Coastal; Santa Rosa Inland; Santa Rosa Coastal; Okaloosa Inland; Okaloosa Coastal; Wayne; Perry; Greene; Stone; George",
                        "geocode": {
                          "SAME": [
                            "001023",
                            "001129",
                            "001025",
                            "001131",
                            "001099",
                            "001035",
                            "001013",
                            "001041",
                            "001053",
                            "001039",
                            "001097",
                            "001003",
                            "012033",
                            "012113",
                            "012091",
                            "028153",
                            "028111",
                            "028041",
                            "028131",
                            "028039"
                          ],
                          "UGC": [
                            "ALZ051",
                            "ALZ052",
                            "ALZ053",
                            "ALZ054",
                            "ALZ055",
                            "ALZ056",
                            "ALZ057",
                            "ALZ058",
                            "ALZ059",
                            "ALZ060",
                            "ALZ261",
                            "ALZ262",
                            "ALZ263",
                            "ALZ264",
                            "ALZ265",
                            "ALZ266",
                            "FLZ201",
                            "FLZ202",
                            "FLZ203",
                            "FLZ204",
                            "FLZ205",
                            "FLZ206",
                            "MSZ067",
                            "MSZ075",
                            "MSZ076",
                            "MSZ078",
                            "MSZ079"
                          ]
                        },
                        "affectedZones": [
                          "https://api.weather.gov/zones/forecast/ALZ051",
                          "https://api.weather.gov/zones/forecast/ALZ052",
                          "https://api.weather.gov/zones/forecast/ALZ053",
                          "https://api.weather.gov/zones/forecast/ALZ054",
                          "https://api.weather.gov/zones/forecast/ALZ055",
                          "https://api.weather.gov/zones/forecast/ALZ056",
                          "https://api.weather.gov/zones/forecast/ALZ057",
                          "https://api.weather.gov/zones/forecast/ALZ058",
                          "https://api.weather.gov/zones/forecast/ALZ059",
                          "https://api.weather.gov/zones/forecast/ALZ060",
                          "https://api.weather.gov/zones/forecast/ALZ261",
                          "https://api.weather.gov/zones/forecast/ALZ262",
                          "https://api.weather.gov/zones/forecast/ALZ263",
                          "https://api.weather.gov/zones/forecast/ALZ264",
                          "https://api.weather.gov/zones/forecast/ALZ265",
                          "https://api.weather.gov/zones/forecast/ALZ266",
                          "https://api.weather.gov/zones/forecast/FLZ201",
                          "https://api.weather.gov/zones/forecast/FLZ202",
                          "https://api.weather.gov/zones/forecast/FLZ203",
                          "https://api.weather.gov/zones/forecast/FLZ204",
                          "https://api.weather.gov/zones/forecast/FLZ205",
                          "https://api.weather.gov/zones/forecast/FLZ206",
                          "https://api.weather.gov/zones/forecast/MSZ067",
                          "https://api.weather.gov/zones/forecast/MSZ075",
                          "https://api.weather.gov/zones/forecast/MSZ076",
                          "https://api.weather.gov/zones/forecast/MSZ078",
                          "https://api.weather.gov/zones/forecast/MSZ079"
                        ],
                        "references": [
                          {
                            "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.81f097bd1d13a0e1209547bf40ee080f80550b3e.001.1",
                            "identifier": "urn:oid:2.49.0.1.840.0.81f097bd1d13a0e1209547bf40ee080f80550b3e.001.1",
                            "sender": "w-nws.webmaster@noaa.gov",
                            "sent": "2025-11-19T23:00:00-06:00"
                          }
                        ],
                        "sent": "2025-11-20T06:57:00-06:00",
                        "effective": "2025-11-20T06:57:00-06:00",
                        "onset": "2025-11-20T06:57:00-06:00",
                        "expires": "2025-11-20T09:00:00-06:00",
                        "ends": "2025-11-20T09:00:00-06:00",
                        "status": "Actual",
                        "messageType": "Update",
                        "category": "Met",
                        "severity": "Moderate",
                        "certainty": "Likely",
                        "urgency": "Expected",
                        "event": "Dense Fog Advisory",
                        "sender": "w-nws.webmaster@noaa.gov",
                        "senderName": "NWS Mobile AL",
                        "headline": "Dense Fog Advisory issued November 20 at 6:57AM CST until November 20 at 9:00AM CST by NWS Mobile AL",
                        "description": "* WHAT...Visibility one quarter mile or less in dense fog.\n\n* WHERE...Portions of south central and southwest Alabama, northwest\nFlorida, and southeast Mississippi.\n\n* WHEN...Until 9 AM CST this morning.\n\n* IMPACTS...Low visibility could make driving conditions hazardous.",
                        "instruction": "If driving, slow down, use your headlights, and leave plenty of\ndistance ahead of you.",
                        "response": "Execute",
                        "parameters": {
                          "AWIPSidentifier": [
                            "NPWMOB"
                          ],
                          "WMOidentifier": [
                            "WWUS74 KMOB 201257"
                          ],
                          "NWSheadline": [
                            "DENSE FOG ADVISORY REMAINS IN EFFECT UNTIL 9 AM CST THIS MORNING"
                          ],
                          "BLOCKCHANNEL": [
                            "EAS",
                            "NWEM",
                            "CMAS"
                          ],
                          "VTEC": [
                            "/O.CON.KMOB.FG.Y.0031.000000T0000Z-251120T1500Z/"
                          ],
                          "eventEndingTime": [
                            "2025-11-20T09:00:00-06:00"
                          ],
                          "expiredReferences": [
                            "w-nws.webmaster@noaa.gov,urn:oid:2.49.0.1.840.0.4056e25e124a1a84da6fded45439cc6531d13f93.001.1,2025-11-19T15:03:00-06:00"
                          ]
                        },
                        "scope": "Public",
                        "code": "IPAWSv1.0",
                        "language": "en-US",
                        "web": "http://www.weather.gov",
                        "eventCode": {
                          "SAME": [
                            "NWS"
                          ],
                          "NationalWeatherService": [
                            "FGY"
                          ]
                        },
                        "replacedBy": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.78446f612d18c86517e88e78c0e7c49ac7d0c698.002.1",
                        "replacedAt": "2025-11-20T08:53:00-06:00"
                      }
                    },
                    {
                      "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.81f097bd1d13a0e1209547bf40ee080f80550b3e.001.1",
                      "type": "Feature",
                      "geometry": null,
                      "properties": {
                        "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.81f097bd1d13a0e1209547bf40ee080f80550b3e.001.1",
                        "@type": "wx:Alert",
                        "id": "urn:oid:2.49.0.1.840.0.81f097bd1d13a0e1209547bf40ee080f80550b3e.001.1",
                        "areaDesc": "Choctaw; Washington; Clarke; Wilcox; Monroe; Conecuh; Butler; Crenshaw; Escambia; Covington; Mobile Inland; Baldwin Inland; Mobile Central; Baldwin Central; Mobile Coastal; Baldwin Coastal; Escambia Inland; Escambia Coastal; Santa Rosa Inland; Santa Rosa Coastal; Okaloosa Inland; Okaloosa Coastal; Wayne; Perry; Greene; Stone; George",
                        "geocode": {
                          "SAME": [
                            "001023",
                            "001129",
                            "001025",
                            "001131",
                            "001099",
                            "001035",
                            "001013",
                            "001041",
                            "001053",
                            "001039",
                            "001097",
                            "001003",
                            "012033",
                            "012113",
                            "012091",
                            "028153",
                            "028111",
                            "028041",
                            "028131",
                            "028039"
                          ],
                          "UGC": [
                            "ALZ051",
                            "ALZ052",
                            "ALZ053",
                            "ALZ054",
                            "ALZ055",
                            "ALZ056",
                            "ALZ057",
                            "ALZ058",
                            "ALZ059",
                            "ALZ060",
                            "ALZ261",
                            "ALZ262",
                            "ALZ263",
                            "ALZ264",
                            "ALZ265",
                            "ALZ266",
                            "FLZ201",
                            "FLZ202",
                            "FLZ203",
                            "FLZ204",
                            "FLZ205",
                            "FLZ206",
                            "MSZ067",
                            "MSZ075",
                            "MSZ076",
                            "MSZ078",
                            "MSZ079"
                          ]
                        },
                        "affectedZones": [
                          "https://api.weather.gov/zones/forecast/ALZ051",
                          "https://api.weather.gov/zones/forecast/ALZ052",
                          "https://api.weather.gov/zones/forecast/ALZ053",
                          "https://api.weather.gov/zones/forecast/ALZ054",
                          "https://api.weather.gov/zones/forecast/ALZ055",
                          "https://api.weather.gov/zones/forecast/ALZ056",
                          "https://api.weather.gov/zones/forecast/ALZ057",
                          "https://api.weather.gov/zones/forecast/ALZ058",
                          "https://api.weather.gov/zones/forecast/ALZ059",
                          "https://api.weather.gov/zones/forecast/ALZ060",
                          "https://api.weather.gov/zones/forecast/ALZ261",
                          "https://api.weather.gov/zones/forecast/ALZ262",
                          "https://api.weather.gov/zones/forecast/ALZ263",
                          "https://api.weather.gov/zones/forecast/ALZ264",
                          "https://api.weather.gov/zones/forecast/ALZ265",
                          "https://api.weather.gov/zones/forecast/ALZ266",
                          "https://api.weather.gov/zones/forecast/FLZ201",
                          "https://api.weather.gov/zones/forecast/FLZ202",
                          "https://api.weather.gov/zones/forecast/FLZ203",
                          "https://api.weather.gov/zones/forecast/FLZ204",
                          "https://api.weather.gov/zones/forecast/FLZ205",
                          "https://api.weather.gov/zones/forecast/FLZ206",
                          "https://api.weather.gov/zones/forecast/MSZ067",
                          "https://api.weather.gov/zones/forecast/MSZ075",
                          "https://api.weather.gov/zones/forecast/MSZ076",
                          "https://api.weather.gov/zones/forecast/MSZ078",
                          "https://api.weather.gov/zones/forecast/MSZ079"
                        ],
                        "references": [
                          {
                            "@id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.4056e25e124a1a84da6fded45439cc6531d13f93.001.1",
                            "identifier": "urn:oid:2.49.0.1.840.0.4056e25e124a1a84da6fded45439cc6531d13f93.001.1",
                            "sender": "w-nws.webmaster@noaa.gov",
                            "sent": "2025-11-19T15:03:00-06:00"
                          }
                        ],
                        "sent": "2025-11-19T23:00:00-06:00",
                        "effective": "2025-11-19T23:00:00-06:00",
                        "onset": "2025-11-19T23:00:00-06:00",
                        "expires": "2025-11-20T07:00:00-06:00",
                        "ends": "2025-11-20T09:00:00-06:00",
                        "status": "Actual",
                        "messageType": "Update",
                        "category": "Met",
                        "severity": "Moderate",
                        "certainty": "Likely",
                        "urgency": "Expected",
                        "event": "Dense Fog Advisory",
                        "sender": "w-nws.webmaster@noaa.gov",
                        "senderName": "NWS Mobile AL",
                        "headline": "Dense Fog Advisory issued November 19 at 11:00PM CST until November 20 at 9:00AM CST by NWS Mobile AL",
                        "description": "* WHAT...Visibility one quarter mile or less in dense fog.\n\n* WHERE...Portions of south central and southwest Alabama, northwest\nFlorida, and southeast Mississippi.\n\n* WHEN...Until 9 AM CST Thursday.\n\n* IMPACTS...Low visibility could make driving conditions hazardous.",
                        "instruction": "If driving, slow down, use your headlights, and leave plenty of\ndistance ahead of you.",
                        "response": "Execute",
                        "parameters": {
                          "AWIPSidentifier": [
                            "NPWMOB"
                          ],
                          "WMOidentifier": [
                            "WWUS74 KMOB 200500"
                          ],
                          "NWSheadline": [
                            "DENSE FOG ADVISORY REMAINS IN EFFECT UNTIL 9 AM CST THURSDAY"
                          ],
                          "BLOCKCHANNEL": [
                            "EAS",
                            "NWEM",
                            "CMAS"
                          ],
                          "VTEC": [
                            "/O.CON.KMOB.FG.Y.0031.000000T0000Z-251120T1500Z/"
                          ],
                          "eventEndingTime": [
                            "2025-11-20T09:00:00-06:00"
                          ]
                        },
                        "scope": "Public",
                        "code": "IPAWSv1.0",
                        "language": "en-US",
                        "web": "http://www.weather.gov",
                        "eventCode": {
                          "SAME": [
                            "NWS"
                          ],
                          "NationalWeatherService": [
                            "FGY"
                          ]
                        },
                        "replacedBy": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.78446f612d18c86517e88e78c0e7c49ac7d0c698.002.1",
                        "replacedAt": "2025-11-20T08:53:00-06:00"
                      }
                    }
                  ],
                  "title": "Watches, warnings, and advisories for 31.433058668587 N, 88.036333326417 W",
                  "updated": "2025-11-25T23:59:05+00:00",
                  "pagination": {
                    "next": "https://api.weather.gov/alerts?point=31.433058668587183,-88.0363333264173&limit=500&cursor=eyJ0IjoxNzYzNjE0ODAwLCJpIjoidXJuOm9pZDoyLjQ5LjAuMS44NDAuMC44MWYwOTdiZDFkMTNhMGUxMjA5NTQ3YmY0MGVlMDgwZjgwNTUwYjNlLjAwMS4xIn0%3D"
                  }
                }           
                """
    }
    static var sampleWatches: [WatchModel] {
        [
            WatchModel(
                number: 551,
                title: "Watch 551",
                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk.html")!,
                issued: Date(),
                validStart: Date(),
                validEnd: Date(),
                summary: """
                SEL1
                
                URGENT - IMMEDIATE BROADCAST REQUESTED
                Severe Thunderstorm Watch Number 551
                NWS Storm Prediction Center Norman OK
                115 PM MDT Mon Jul 28 2025
                
                The NWS Storm Prediction Center has issued a
                
                * Severe Thunderstorm Watch for portions of
                  Central Montana
                
                * Effective this Monday afternoon and evening from 115 PM until
                  900 PM MDT.
                
                * Primary threats include...
                  Scattered large hail and isolated very large hail events to 2.5
                    inches in diameter possible
                  Scattered damaging wind gusts to 70 mph possible
                
                SUMMARY...Scattered thunderstorm development is expected through the
                afternoon, including the potential for a few supercells.  Large hail
                of 1-2.5 inches in diameter will be possible, while severe outflow
                gusts of 60-70 mph will be possible with upscale growth into a
                cluster or two this evening.
                
                The severe thunderstorm watch area is approximately along and 60
                statute miles north and south of a line from 35 miles northwest of
                Helena MT to 75 miles east of Lewistown MT. For a complete depiction
                of the watch see the associated watch outline update (WOUS64 KWNS
                WOU1).
                
                PRECAUTIONARY/PREPAREDNESS ACTIONS...
                
                REMEMBER...A Severe Thunderstorm Watch means conditions are
                favorable for severe thunderstorms in and close to the watch area.
                Persons in these areas should be on the lookout for threatening
                weather conditions and listen for later statements and possible
                warnings. Severe thunderstorms can and occasionally do produce
                tornadoes.
                
                &&
                
                OTHER WATCH INFORMATION...CONTINUE...WW 550...
                
                AVIATION...A few severe thunderstorms with hail surface and aloft to
                2.5 inches. Extreme turbulence and surface wind gusts to 60 knots. A
                few cumulonimbi with maximum tops to 450. Mean storm motion vector
                28020.
                
                ...Thompson
                """,
                alertType: .watch
            ),
            WatchModel(
                number: 550,
                title: "Watch 550",
                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk2.html")!,
                issued: Date().addingTimeInterval(-3600),
                validStart: Date(),
                validEnd: Date(),
                summary: """
                     SEL0
                    
                       URGENT - IMMEDIATE BROADCAST REQUESTED
                       Severe Thunderstorm Watch Number 550
                       NWS Storm Prediction Center Norman OK
                       825 AM CDT Mon Jul 28 2025
                    
                       The NWS Storm Prediction Center has issued a
                    
                       * Severe Thunderstorm Watch for portions of 
                         Southwest and south central North Dakota
                    
                       * Effective this Monday morning and afternoon from 825 AM until
                         400 PM CDT.
                    
                       * Primary threats include...
                         Scattered damaging winds and isolated significant gusts to 75
                           mph likely
                         Scattered large hail events to 1.5 inches in diameter possible
                    
                       SUMMARY...A storm cluster in southwest North Dakota will likely
                       persist and spread eastward through the morning and into the
                       afternoon.  Damaging outflow gusts of 60-75 mph will be the main
                       threat, along with large hail up to 1.5 inches in diameter with the
                       strongest embedded storms.
                    
                       The severe thunderstorm watch area is approximately along and 45
                       statute miles north and south of a line from 10 miles south of
                       Dickinson ND to 25 miles south of Jamestown ND. For a complete
                       depiction of the watch see the associated watch outline update
                       (WOUS64 KWNS WOU0).
                    
                       PRECAUTIONARY/PREPAREDNESS ACTIONS...
                    
                       REMEMBER...A Severe Thunderstorm Watch means conditions are
                       favorable for severe thunderstorms in and close to the watch area.
                       Persons in these areas should be on the lookout for threatening
                       weather conditions and listen for later statements and possible
                       warnings. Severe thunderstorms can and occasionally do produce
                       tornadoes.
                    
                       &&
                    
                       AVIATION...A few severe thunderstorms with hail surface and aloft to
                       1.5 inches. Extreme turbulence and surface wind gusts to 65 knots. A
                       few cumulonimbi with maximum tops to 550. Mean storm motion vector
                       28035.
                    
                       ...Thompson
                    """,
                alertType: .watch
            ),
            WatchModel(
                number: 635,
                title: "Watch 635",
                link: URL(string: "https://www.spc.noaa.gov/products/watch/ww0635.html")!,
                issued: Date().addingTimeInterval(-3600),
                validStart: Date(),
                validEnd: Date(),
                summary: """
                     SEL5
                    
                        URGENT - IMMEDIATE BROADCAST REQUESTED
                        Tornado Watch Number 635
                        NWS Storm Prediction Center Norman OK
                        325 PM CST Fri Nov 7 2025
                    
                        The NWS Storm Prediction Center has issued a
                    
                        * Tornado Watch for portions of 
                          Northern Alabama
                          South-Central Kentucky
                          Middle into Eastern Tennessee
                    
                        * Effective this Friday afternoon and evening from 325 PM until
                          1000 PM CST.
                    
                        * Primary threats include...
                          A couple tornadoes possible
                          Scattered damaging wind gusts to 70 mph possible
                          Isolated large hail events to 1.5 inches in diameter possible
                    
                        SUMMARY...Scattered thunderstorms are forecast to develop and
                        intensify through the remainder of the afternoon and persist through
                        much of the evening, as they move west to east across the Watch
                        area.  A few of the stronger storms will likely become supercellular
                        and pose a risk for isolated large hail and perhaps a couple of
                        tornadoes.  Scattered damaging gusts (60-70 mph) are possible with
                        the stronger storms and may focus with the more organized
                        thunderstorm bands as a mix of linear and cellular storms evolve.
                    
                        The tornado watch area is approximately along and 85 statute miles
                        east and west of a line from 60 miles north northwest of Crossville
                        TN to 40 miles east of Muscle Shoals AL. For a complete depiction of
                        the watch see the associated watch outline update (WOUS64 KWNS
                        WOU5).
                    
                        PRECAUTIONARY/PREPAREDNESS ACTIONS...
                    
                        REMEMBER...A Tornado Watch means conditions are favorable for
                        tornadoes and severe thunderstorms in and close to the watch
                        area. Persons in these areas should be on the lookout for
                        threatening weather conditions and listen for later statements
                        and possible warnings.
                    
                        &&
                    
                        AVIATION...Tornadoes and a few severe thunderstorms with hail
                        surface and aloft to 1.5 inches. Extreme turbulence and surface wind
                        gusts to 60 knots. A few cumulonimbi with maximum tops to 450. Mean
                        storm motion vector 27035.
                    
                        ...Smith
                    """,
                alertType: .watch
            )
        ]
    }
    
    static var sampleWatcheDtos: [WatchDTO] {
        [
            WatchDTO(
                number: 551,
                title: "Watch 551",
                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk.html")!,
                issued: Date(),
                validStart: Date(),
                validEnd: Date(),
                summary: """
                SEL1
                
                URGENT - IMMEDIATE BROADCAST REQUESTED
                Severe Thunderstorm Watch Number 551
                NWS Storm Prediction Center Norman OK
                115 PM MDT Mon Jul 28 2025
                
                The NWS Storm Prediction Center has issued a
                
                * Severe Thunderstorm Watch for portions of
                  Central Montana
                
                * Effective this Monday afternoon and evening from 115 PM until
                  900 PM MDT.
                
                * Primary threats include...
                  Scattered large hail and isolated very large hail events to 2.5
                    inches in diameter possible
                  Scattered damaging wind gusts to 70 mph possible
                
                SUMMARY...Scattered thunderstorm development is expected through the
                afternoon, including the potential for a few supercells.  Large hail
                of 1-2.5 inches in diameter will be possible, while severe outflow
                gusts of 60-70 mph will be possible with upscale growth into a
                cluster or two this evening.
                
                The severe thunderstorm watch area is approximately along and 60
                statute miles north and south of a line from 35 miles northwest of
                Helena MT to 75 miles east of Lewistown MT. For a complete depiction
                of the watch see the associated watch outline update (WOUS64 KWNS
                WOU1).
                
                PRECAUTIONARY/PREPAREDNESS ACTIONS...
                
                REMEMBER...A Severe Thunderstorm Watch means conditions are
                favorable for severe thunderstorms in and close to the watch area.
                Persons in these areas should be on the lookout for threatening
                weather conditions and listen for later statements and possible
                warnings. Severe thunderstorms can and occasionally do produce
                tornadoes.
                
                &&
                
                OTHER WATCH INFORMATION...CONTINUE...WW 550...
                
                AVIATION...A few severe thunderstorms with hail surface and aloft to
                2.5 inches. Extreme turbulence and surface wind gusts to 60 knots. A
                few cumulonimbi with maximum tops to 450. Mean storm motion vector
                28020.
                
                ...Thompson
                """,
                type: "Severe Thunderstorm"
            ),
            WatchDTO(
                number: 550,
                title: "Watch 550",
                link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk2.html")!,
                issued: Date().addingTimeInterval(-3600),
                validStart: Date(),
                validEnd: Date(),
                summary: """
                     SEL0
                    
                       URGENT - IMMEDIATE BROADCAST REQUESTED
                       Severe Thunderstorm Watch Number 550
                       NWS Storm Prediction Center Norman OK
                       825 AM CDT Mon Jul 28 2025
                    
                       The NWS Storm Prediction Center has issued a
                    
                       * Severe Thunderstorm Watch for portions of 
                         Southwest and south central North Dakota
                    
                       * Effective this Monday morning and afternoon from 825 AM until
                         400 PM CDT.
                    
                       * Primary threats include...
                         Scattered damaging winds and isolated significant gusts to 75
                           mph likely
                         Scattered large hail events to 1.5 inches in diameter possible
                    
                       SUMMARY...A storm cluster in southwest North Dakota will likely
                       persist and spread eastward through the morning and into the
                       afternoon.  Damaging outflow gusts of 60-75 mph will be the main
                       threat, along with large hail up to 1.5 inches in diameter with the
                       strongest embedded storms.
                    
                       The severe thunderstorm watch area is approximately along and 45
                       statute miles north and south of a line from 10 miles south of
                       Dickinson ND to 25 miles south of Jamestown ND. For a complete
                       depiction of the watch see the associated watch outline update
                       (WOUS64 KWNS WOU0).
                    
                       PRECAUTIONARY/PREPAREDNESS ACTIONS...
                    
                       REMEMBER...A Severe Thunderstorm Watch means conditions are
                       favorable for severe thunderstorms in and close to the watch area.
                       Persons in these areas should be on the lookout for threatening
                       weather conditions and listen for later statements and possible
                       warnings. Severe thunderstorms can and occasionally do produce
                       tornadoes.
                    
                       &&
                    
                       AVIATION...A few severe thunderstorms with hail surface and aloft to
                       1.5 inches. Extreme turbulence and surface wind gusts to 65 knots. A
                       few cumulonimbi with maximum tops to 550. Mean storm motion vector
                       28035.
                    
                       ...Thompson
                    """,
                type: "Severe Thunderstorm"
            ),
            WatchDTO(
                number: 635,
                title: "Watch 635",
                link: URL(string: "https://www.spc.noaa.gov/products/watch/ww0635.html")!,
                issued: Date().addingTimeInterval(-3600),
                validStart: Date(),
                validEnd: Date(),
                summary: """
                     SEL5
                    
                        URGENT - IMMEDIATE BROADCAST REQUESTED
                        Tornado Watch Number 635
                        NWS Storm Prediction Center Norman OK
                        325 PM CST Fri Nov 7 2025
                    
                        The NWS Storm Prediction Center has issued a
                    
                        * Tornado Watch for portions of 
                          Northern Alabama
                          South-Central Kentucky
                          Middle into Eastern Tennessee
                    
                        * Effective this Friday afternoon and evening from 325 PM until
                          1000 PM CST.
                    
                        * Primary threats include...
                          A couple tornadoes possible
                          Scattered damaging wind gusts to 70 mph possible
                          Isolated large hail events to 1.5 inches in diameter possible
                    
                        SUMMARY...Scattered thunderstorms are forecast to develop and
                        intensify through the remainder of the afternoon and persist through
                        much of the evening, as they move west to east across the Watch
                        area.  A few of the stronger storms will likely become supercellular
                        and pose a risk for isolated large hail and perhaps a couple of
                        tornadoes.  Scattered damaging gusts (60-70 mph) are possible with
                        the stronger storms and may focus with the more organized
                        thunderstorm bands as a mix of linear and cellular storms evolve.
                    
                        The tornado watch area is approximately along and 85 statute miles
                        east and west of a line from 60 miles north northwest of Crossville
                        TN to 40 miles east of Muscle Shoals AL. For a complete depiction of
                        the watch see the associated watch outline update (WOUS64 KWNS
                        WOU5).
                    
                        PRECAUTIONARY/PREPAREDNESS ACTIONS...
                    
                        REMEMBER...A Tornado Watch means conditions are favorable for
                        tornadoes and severe thunderstorms in and close to the watch
                        area. Persons in these areas should be on the lookout for
                        threatening weather conditions and listen for later statements
                        and possible warnings.
                    
                        &&
                    
                        AVIATION...Tornadoes and a few severe thunderstorms with hail
                        surface and aloft to 1.5 inches. Extreme turbulence and surface wind
                        gusts to 60 knots. A few cumulonimbi with maximum tops to 450. Mean
                        storm motion vector 27035.
                    
                        ...Smith
                    """,
                type: "Tornado"
            )
        ]
    }
    
}

