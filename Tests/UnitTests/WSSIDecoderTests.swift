import Foundation
import Testing
@testable import SkyAware

@Suite("WSSI decoder")
struct WSSIDecoderTests {
    private let issue = "2026-11-11 2116Z"
    private let exterior = "[[[-100,40],[-100,41],[-99,41],[-99,40],[-100,40]]]"

    private func response(source: String = "WSSI_OVERALL_Day_1", impact: String = "MAJOR",
                          start: String = "21Z 11/11/26", end: String = "18Z 11/12/26",
                          geometry: String? = nil) -> Data {
        let shape = geometry ?? exterior
        return Data("""
        {"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326},"features":[{"attributes":{"component":"\(source.components(separatedBy: "_Day")[0])","idp_source":"\(source)","impact":"\(impact)","issue_time":"\(issue)","start_time":"\(start)","end_time":"\(end)","future_field":true},"geometry":{"rings":\(shape)}}]}
        """.utf8)
    }

    @Test("recognizes every authoritative product and period")
    func recognizesSourceValues() throws {
        for product in WSSIProduct.allCases {
            for period in WSSIPeriod.allCases {
                let value = try WSSIDecoder.decode(response(source: "\(product.rawValue)_\(period.rawValue)")).features[0]
                #expect(value.product == product)
                #expect(value.period == period)
            }
        }
    }

    @Test("decodes WGS84 longitude latitude and validity timestamps")
    func decodesCoordinatesAndDates() throws {
        let value = try #require(WSSIDecoder.decode(response()).features.first)
        #expect(value.impact == .major)
        #expect(value.polygons[0].rings[0][0] == Coordinate2D(latitude: 40, longitude: -100))
        #expect(value.validTo > value.validFrom)
        #expect(value.issuedAt.timeIntervalSince1970 == 1794431760)
        #expect(value.validFrom.timeIntervalSince1970 == 1794430800)
    }

    @Test("accepts an empty feature set without inventing publication identity")
    func acceptsEmpty() throws {
        #expect(try WSSIDecoder.decode(Data(#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326},"features":[]}"#.utf8)).features.isEmpty)
    }

    @Test("preserves a multipart hole and exterior rings")
    func decodesHolesAndParts() throws {
        let rings = "[[[-100,40],[-100,41],[-99,41],[-99,40],[-100,40]],[[-99.8,40.2],[-99.7,40.2],[-99.7,40.3],[-99.8,40.3],[-99.8,40.2]],[[-90,30],[-90,31],[-89,31],[-89,30],[-90,30]]]"
        let value = try #require(WSSIDecoder.decode(response(geometry: rings)).features.first)
        #expect(value.polygons.count == 2)
        #expect(value.polygons[0].rings.count == 2)
        #expect(value.polygons[0].rings[1][0] == Coordinate2D(latitude: 40.2, longitude: -99.8))
        #expect(value.polygons[1].rings[0][0] == Coordinate2D(latitude: 30, longitude: -90))
    }

    @Test("associates a hole whose first point touches its exterior")
    func boundaryTouchingHole() throws {
        // NOAA layer 2 has an interior ring whose first vertex equals an exterior vertex.
        let rings = "[[[-100,40],[-100,41],[-99,41],[-99,40],[-100,40]],[[-100,41],[-99.8,40.8],[-99.6,40.8],[-100,41]]]"
        let feature = try #require(WSSIDecoder.decode(response(geometry: rings)).features.first)
        #expect(feature.polygons.count == 1)
        #expect(feature.polygons[0].rings.count == 2)
        #expect(feature.polygons[0].rings[1][1] == Coordinate2D(latitude: 40.8, longitude: -99.8))
    }

    @Test("rejects unknown impact, invalid dates, malformed rings, and ArcGIS errors")
    func rejectsInvalidValues() {
        #expect(throws: WSSIDecodingError.self) { try WSSIDecoder.decode(response(impact: "UNKNOWN")) }
        #expect(throws: WSSIDecodingError.self) { try WSSIDecoder.decode(response(end: "21Z 11/11/26")) }
        #expect(throws: WSSIDecodingError.self) { try WSSIDecoder.decode(response(geometry: "[[[-100,40],[-99,40],[-99,41]]]")) }
        #expect(throws: WSSIDecodingError.self) { try WSSIDecoder.decode(Data(#"{"error":{"code":400}}"#.utf8)) }
    }

    @Test("rejects malformed source metadata and geometry")
    func rejectsMalformedSource() throws {
        let original = try #require(String(data: response(), encoding: .utf8))
        let variants = [
            original.replacingOccurrences(of: "WSSI_OVERALL_Day_1", with: "WSSI_OVERALL_BAD_Day_1"),
            original.replacingOccurrences(of: "\"component\":\"WSSI_OVERALL\"", with: "\"component\":\"SNOW_LOAD\""),
            original.replacingOccurrences(of: "\"impact\":\"MAJOR\",", with: ""),
            original.replacingOccurrences(of: "21Z 11/11/26", with: "21Z 02/30/26"),
            original.replacingOccurrences(of: "18Z 11/12/26", with: "20Z 11/11/26"),
            original.replacingOccurrences(of: "\"wkid\":4326", with: "\"wkid\":3857"),
            original.replacingOccurrences(of: "[-100,40]", with: "[-181,40]"),
            original.replacingOccurrences(of: "[-100,40]", with: "[-100,40,4]")
        ]
        for json in variants {
            #expect(throws: WSSIDecodingError.self) { try WSSIDecoder.decode(Data(json.utf8)) }
        }
        let feature = try #require((JSONSerialization.jsonObject(with: Data(original.utf8)) as? [String: Any])?["features"] as? [[String: Any]])
        var invalidFeature = try #require(feature.first)
        var attributes = try #require(invalidFeature["attributes"] as? [String: Any])
        attributes["impact"] = "UNKNOWN"
        invalidFeature["attributes"] = attributes
        let mixed: [String: Any] = ["geometryType": "esriGeometryPolygon", "spatialReference": ["wkid": 4326],
                                    "features": [try #require(feature.first), invalidFeature]]
        #expect(throws: WSSIDecodingError.self) {
            try WSSIDecoder.decode(JSONSerialization.data(withJSONObject: mixed))
        }
        #expect(throws: WSSIDecodingError.self) {
            try WSSIDecoder.decode(response(geometry: "[[[-100,40],[-99,40],[-98,40],[-100,40]]]"))
        }
        #expect(throws: WSSIDecodingError.self) {
            try WSSIDecoder.decode(response(geometry: "[[[-100,40],[-99,40],[-99,41],[-100,41],[-100,40]]]"))
        }
    }

    @Test("validates explicit geographic scopes")
    func validatesScope() throws {
        #expect(try WSSIScope(south: 36, west: -112, north: 43, east: -102).north == 43)
        #expect(throws: WSSIDecodingError.self) { try WSSIScope(south: 43, west: -112, north: 36, east: -102) }
    }

    @Test("decodes captured NOAA ArcGIS feature")
    func capturedNOAAFeature() throws {
        // WSSI-01 capture, layer 17, first feature; unrelated response schema omitted.
        let data = Data(#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/12/26 - 18Z 11/13/26","component":"ICE_ACCUMULATION","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 1915Z","start_time":"18Z 11/12/26","end_time":"18Z 11/13/26","idp_source":"ICE_ACCUMULATION_Day_2","idp_filedate":1794432788000,"idp_ingestdate":1794432848000,"st_area(shape)":2399376.316390531,"st_perimeter(shape)":5960.667008876098},"geometry":{"rings":[[[-73.09747225408333,42.899399862629394],[-73.10896980308287,42.90077214384249],[-73.1096738918228,42.90114435209841],[-73.10993229940078,42.901751576036844],[-73.10805936413568,42.910173766001144],[-73.10755119616262,42.910689498677066],[-73.10672216703804,42.91087876612312],[-73.09522347897472,42.90950643090031],[-73.09451938484492,42.90913418693722],[-73.09426105272539,42.90852696860188],[-73.09613512705428,42.90010483330529],[-73.09664330041724,42.89958909827613],[-73.09747225408333,42.899399862629394]]]}}]}"#.utf8)
        let feature = try #require(WSSIDecoder.decode(data).features.first)
        #expect(feature.product == .iceAccumulation)
        #expect(feature.period == .day2)
        #expect(feature.polygons.count == 1)
        #expect(feature.polygons[0].rings[0].count == 13)
    }

    @Test("decodes GeoJSON Polygon and MultiPolygon with holes")
    func geoJSONGeometry() throws {
        let properties = #"{"component":"WSSI_OVERALL","idp_source":"WSSI_OVERALL_Day_1","impact":"MAJOR","issue_time":"2026-11-11 2116Z","start_time":"21Z 11/11/26","end_time":"18Z 11/12/26"}"#
        let outer = #"[[-100,40],[-99,40],[-99,41],[-100,41],[-100,40]]"#
        let hole = #"[[-99.8,40.2],[-99.7,40.2],[-99.7,40.3],[-99.8,40.3],[-99.8,40.2]]"#
        for (type, coordinates) in [("Polygon", "[\(outer),\(hole)]"), ("MultiPolygon", "[[\(outer),\(hole)],[\(outer)]]")] {
            let json = #"{"type":"FeatureCollection","features":[{"type":"Feature","properties":\#(properties),"geometry":{"type":"\#(type)","coordinates":\#(coordinates)}}]}"#
            let feature = try #require(WSSIDecoder.decode(Data(json.utf8)).features.first)
            #expect(feature.polygons.count == (type == "Polygon" ? 1 : 2))
            #expect(feature.polygons[0].rings.count == 2)
        }
    }

    @Test("rejects crossing shells and holes outside or crossing the exterior")
    func rejectsInvalidTopology() throws {
        let properties = #"{"component":"WSSI_OVERALL","idp_source":"WSSI_OVERALL_Day_1","impact":"MAJOR","issue_time":"2026-11-11 2116Z","start_time":"21Z 11/11/26","end_time":"18Z 11/12/26"}"#
        let examples = [
            #"[[[-100,40],[-98,42],[-100,42],[-99,40],[-100,40]]]"#,
            #"[[[-100,40],[-99,40],[-99,41],[-100,41],[-100,40]],[[-90,30],[-89,30],[-89,31],[-90,31],[-90,30]]]"#,
            #"[[[-100,40],[-99,40],[-99,41],[-100,41],[-100,40]],[[-99.8,40.2],[-98.8,40.2],[-98.8,40.8],[-99.8,40.8],[-99.8,40.2]]]"#,
            #"[[[-100,40],[-99,40],[-99,41],[-100,41],[-100,40]],[[-99.5,40.5],[-98.5,41.5],[-100.5,41.5],[-99.5,40.5]]]"#,
            #"[[[-100,40],[-90,40],[-90,44],[-96,44],[-96,42],[-97,41],[-98,42],[-98,44],[-100,44],[-100,40]],[[-99.5,42],[-90.5,42],[-90.5,40.5],[-99.5,40.5],[-99.5,42]]]"#
        ]
        for rings in examples {
            let json = #"{"type":"FeatureCollection","features":[{"type":"Feature","properties":\#(properties),"geometry":{"type":"Polygon","coordinates":\#(rings)}}]}"#
            #expect(throws: WSSIDecodingError.self) { try WSSIDecoder.decode(Data(json.utf8)) }
        }
    }

    @Test("decodes every captured NOAA impact classification")
    func capturedImpactLevels() throws {
        // WSSI-01 attributes with one unmodified exterior ring from each captured record.
        let samples: [(String, WSSIImpact)] = [
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/12/26 - 18Z 11/13/26","component":"ICE_ACCUMULATION","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 1915Z","start_time":"18Z 11/12/26","end_time":"18Z 11/13/26","idp_source":"ICE_ACCUMULATION_Day_2","idp_filedate":1794432788000,"idp_ingestdate":1794432848000,"st_area(shape)":2399376.316390531,"st_perimeter(shape)":5960.667008876098},"geometry":{"rings":[[[-73.09747225408333,42.899399862629394],[-73.10896980308287,42.90077214384249],[-73.1096738918228,42.90114435209841],[-73.10993229940078,42.901751576036844],[-73.10805936413568,42.910173766001144],[-73.10755119616262,42.910689498677066],[-73.10672216703804,42.91087876612312],[-73.09522347897472,42.90950643090031],[-73.09451938484492,42.90913418693722],[-73.09426105272539,42.90852696860188],[-73.09613512705428,42.90010483330529],[-73.09664330041724,42.89958909827613],[-73.09747225408333,42.899399862629394]]]}}]}"#, .winterWeatherArea),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":2,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/13/26 - 18Z 11/14/26","component":"BLOWING_SNOW","impact":"MINOR","issue_time":"2026-11-11 2116Z","start_time":"18Z 11/13/26","end_time":"18Z 11/14/26","idp_source":"BLOWING_SNOW_Day_3","idp_filedate":1794432787000,"idp_ingestdate":1794432840000,"st_area(shape)":32063303749.589214,"st_perimeter(shape)":7072452.086354739},"geometry":{"rings":[[[-115.37478331131624,39.122062093222844],[-115.37409933226229,39.122436074856466],[-115.3728212488019,39.12170532003726],[-115.37307920362899,39.121087755202325],[-115.37376317639472,39.12071377477407],[-115.37455919872083,39.1209138936094],[-115.37504125446524,39.121444526636985],[-115.37478331131624,39.122062093222844]]]}}]}"#, .minor),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":3,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/13/26 - 18Z 11/14/26","component":"BLOWING_SNOW","impact":"MODERATE","issue_time":"2026-11-11 2116Z","start_time":"18Z 11/13/26","end_time":"18Z 11/14/26","idp_source":"BLOWING_SNOW_Day_3","idp_filedate":1794432787000,"idp_ingestdate":1794432840000,"st_area(shape)":17524646646.683598,"st_perimeter(shape)":3500230.2360556796},"geometry":{"rings":[[[-119.90219526324418,38.34088278603234],[-119.90153267397544,38.34127566817118],[-119.90023348459748,38.340575947499126],[-119.90046301583065,38.33994982773424],[-119.90112560060781,38.339556947564624],[-119.90242478279927,38.340256664691864],[-119.90219526324418,38.34088278603234]]]}}]}"#, .moderate),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":4,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/13/26 - 18Z 11/14/26","component":"BLOWING_SNOW","impact":"MAJOR","issue_time":"2026-11-11 2116Z","start_time":"18Z 11/13/26","end_time":"18Z 11/14/26","idp_source":"BLOWING_SNOW_Day_3","idp_filedate":1794432787000,"idp_ingestdate":1794432840000,"st_area(shape)":1861656143.872507,"st_perimeter(shape)":1507239.078194333},"geometry":{"rings":[[[-119.44779287567006,38.14901555982059],[-119.44340441057271,38.13008134637014],[-119.455440054919,38.12835521860603],[-119.45623598831189,38.12853746895738],[-119.45673372864114,38.1290589296618],[-119.46092490393914,38.147132289427255],[-119.44779287567006,38.14901555982059]]]}}]}"#, .major),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":5,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/13/26 - 18Z 11/14/26","component":"BLOWING_SNOW","impact":"EXTREME","issue_time":"2026-11-11 2116Z","start_time":"18Z 11/13/26","end_time":"18Z 11/14/26","idp_source":"BLOWING_SNOW_Day_3","idp_filedate":1794432787000,"idp_ingestdate":1794432840000,"st_area(shape)":53059552.106210224,"st_perimeter(shape)":61379.81299353339},"geometry":{"rings":[[[-119.833862122787,38.62562182884644],[-119.83296695250468,38.62663918548033],[-119.83216663623153,38.626459071962294],[-119.8316647178379,38.625939838780134],[-119.83189527135387,38.625314604934076],[-119.8325598944084,38.62492248555843],[-119.8333602008001,38.625102598725235],[-119.833862122787,38.62562182884644]]]}}]}"#, .extreme)
        ]
        for (json, expected) in samples {
            let feature = try #require(WSSIDecoder.decode(Data(json.utf8)).features.first)
            #expect(feature.impact == expected)
        }
    }

    @Test("decodes captured metadata across available NOAA layers")
    func capturedLayerMetadata() throws {
        // WSSI-01 captured attributes and one unmodified exterior ring per nonempty layer.
        // Layers 16 and 18 were empty; no positive ice fixtures exist for those periods.
        let samples: [(String, String, TimeInterval, TimeInterval, TimeInterval)] = [
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"21Z 11/11/26 - 18Z 11/12/26","component":"WSSI_OVERALL","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 2116Z","start_time":"21Z 11/11/26","end_time":"18Z 11/12/26","idp_source":"WSSI_OVERALL_Day_1","idp_filedate":1794432791000,"idp_ingestdate":1794432876000,"st_area(shape)":202547352792.66513,"st_perimeter(shape)":16118363.558276027},"geometry":{"rings":[[[-88.28872254322123,47.44353049347447],[-88.2899917926491,47.42619949370837],[-88.31561097110271,47.42705638736423],[-88.32195141512534,47.42395849715206],[-88.32014672936394,47.4487170581975],[-88.28353934218528,47.447492962355184],[-88.28872254322123,47.44353049347447]]]}}]}"#, "WSSI_OVERALL_Day_1", 1794431760, 1794430800, 1794506400),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/12/26 - 18Z 11/13/26","component":"WSSI_OVERALL","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 1916Z","start_time":"18Z 11/12/26","end_time":"18Z 11/13/26","idp_source":"WSSI_OVERALL_Day_2","idp_filedate":1794432791000,"idp_ingestdate":1794432883000,"st_area(shape)":676243601811.5238,"st_perimeter(shape)":43593359.665039554},"geometry":{"rings":[[[-73.47770464104785,41.641086181954456],[-73.49019996590145,41.642580717053704],[-73.48620059528965,41.66125558720183],[-73.47256690105348,41.659625013688995],[-73.47638685115359,41.64179916802907],[-73.47688673845639,41.64127854205177],[-73.47770464104785,41.641086181954456]]]}}]}"#, "WSSI_OVERALL_Day_2", 1794424560, 1794506400, 1794592800),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/13/26 - 18Z 11/14/26","component":"WSSI_OVERALL","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 1916Z","start_time":"18Z 11/13/26","end_time":"18Z 11/14/26","idp_source":"WSSI_OVERALL_Day_3","idp_filedate":1794432791000,"idp_ingestdate":1794432891000,"st_area(shape)":791048909103.8948,"st_perimeter(shape)":75319625.77151659},"geometry":{"rings":[[[-70.1615476359324,44.72435618979074],[-70.17555168310231,44.72619922425875],[-70.1599820044445,44.785884797431805],[-70.14713725381,44.784195039237765],[-70.14643096329934,44.78381634101469],[-70.1461860663832,44.78321259789249],[-70.1615476359324,44.72435618979074]]]}}]}"#, "WSSI_OVERALL_Day_3", 1794424560, 1794592800, 1794679200),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"19Z 11/11/26 - 18Z 11/14/26","component":"WSSI_OVERALL","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 1916Z","start_time":"19Z 11/11/26","end_time":"18Z 11/14/26","idp_source":"WSSI_OVERALL_Days_1_3","idp_filedate":1794425578000,"idp_ingestdate":1794425624000,"st_area(shape)":982976670186.4019,"st_perimeter(shape)":77932453.44630218},"geometry":{"rings":[[[-81.69455299960384,40.64906583057344],[-81.71836280578525,40.65084283887561],[-81.71368097517063,40.686968655123195],[-81.68872870957719,40.685106648469514],[-81.69330757888721,40.649841344507166],[-81.69375993363334,40.64929610343699],[-81.69455299960384,40.64906583057344]]]}}]}"#, "WSSI_OVERALL_Days_1_3", 1794424560, 1794423600, 1794679200),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"21Z 11/11/26 - 18Z 11/12/26","component":"SNOW_AMOUNT","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 2116Z","start_time":"21Z 11/11/26","end_time":"18Z 11/12/26","idp_source":"SNOW_AMOUNT_Day_1","idp_filedate":1794432789000,"idp_ingestdate":1794432860000,"st_area(shape)":202841288243.541,"st_perimeter(shape)":16046111.180003121},"geometry":{"rings":[[[-74.94420100872493,43.4349403331291],[-74.96852893711109,43.4375712554043],[-74.96924379934619,43.43793512939884],[-74.9695150204934,43.43853767209282],[-74.96589348488335,43.45620211758484],[-74.94040236486674,43.45344580075241],[-74.94420100872493,43.4349403331291]]]}}]}"#, "SNOW_AMOUNT_Day_1", 1794431760, 1794430800, 1794506400),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/12/26 - 18Z 11/13/26","component":"SNOW_AMOUNT","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 2116Z","start_time":"18Z 11/12/26","end_time":"18Z 11/13/26","idp_source":"SNOW_AMOUNT_Day_2","idp_filedate":1794432789000,"idp_ingestdate":1794432861000,"st_area(shape)":682275680072.045,"st_perimeter(shape)":43543341.47592408},"geometry":{"rings":[[[-86.64762372038112,46.46325297696427],[-86.68381960190455,46.4647875927781],[-86.67491765407009,46.56447780809472],[-86.63868322314289,46.56294272698481],[-86.64762372038112,46.46325297696427]]]}}]}"#, "SNOW_AMOUNT_Day_2", 1794431760, 1794506400, 1794592800),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/13/26 - 18Z 11/14/26","component":"SNOW_AMOUNT","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 1915Z","start_time":"18Z 11/13/26","end_time":"18Z 11/14/26","idp_source":"SNOW_AMOUNT_Day_3","idp_filedate":1794432789000,"idp_ingestdate":1794432857000,"st_area(shape)":786066021100.408,"st_perimeter(shape)":75453290.05080539},"geometry":{"rings":[[[-68.60139837399834,44.31904872511577],[-68.56661382214307,44.31413706772758],[-68.58034483716216,44.264352645489524],[-68.6151122428736,44.26926342680169],[-68.60139837399834,44.31904872511577]]]}}]}"#, "SNOW_AMOUNT_Day_3", 1794424500, 1794592800, 1794679200),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"19Z 11/11/26 - 18Z 11/14/26","component":"SNOW_AMOUNT","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 1915Z","start_time":"19Z 11/11/26","end_time":"18Z 11/14/26","idp_source":"SNOW_AMOUNT_Days_1_3","idp_filedate":1794432790000,"idp_ingestdate":1794432866000,"st_area(shape)":977134364493.933,"st_perimeter(shape)":77773505.60011713},"geometry":{"rings":[[[-86.64762372038112,46.46325297696427],[-86.68381960190455,46.4647875927781],[-86.67491765407009,46.56447780809472],[-86.63868322314289,46.56294272698481],[-86.64762372038112,46.46325297696427]]]}}]}"#, "SNOW_AMOUNT_Days_1_3", 1794424500, 1794423600, 1794679200),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"19Z 11/11/26 - 18Z 11/12/26","component":"SNOW_LOAD","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 1915Z","start_time":"19Z 11/11/26","end_time":"18Z 11/12/26","idp_source":"SNOW_LOAD_Day_1","idp_filedate":1794432790000,"idp_ingestdate":1794432873000,"st_area(shape)":15991416570.973959,"st_perimeter(shape)":3294652.1346775093},"geometry":{"rings":[[[-74.48878094940984,43.46593899804435],[-74.46445899212539,43.46324606767171],[-74.4665801606496,43.453158429670424],[-74.49089968260131,43.45585125704047],[-74.49161290720764,43.456216915401896],[-74.49188125374596,43.456820078073086],[-74.49011573902253,43.46522653293994],[-74.48961195392972,43.46574422908145],[-74.48878094940984,43.46593899804435]]]}}]}"#, "SNOW_LOAD_Day_1", 1794424500, 1794423600, 1794506400),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/12/26 - 18Z 11/13/26","component":"SNOW_LOAD","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 1915Z","start_time":"18Z 11/12/26","end_time":"18Z 11/13/26","idp_source":"SNOW_LOAD_Day_2","idp_filedate":1794432790000,"idp_ingestdate":1794432866000,"st_area(shape)":103253793618.31572,"st_perimeter(shape)":17659728.307678208},"geometry":{"rings":[[[-71.99324536511675,43.22212719801399],[-72.04162903235793,43.22816169291754],[-72.03749171375617,43.24578869309006],[-72.03697625685288,43.24630040075905],[-72.03614239209712,43.24648448320614],[-71.9889022137373,43.24059309977113],[-71.99324536511675,43.22212719801399]]]}}]}"#, "SNOW_LOAD_Day_2", 1794424500, 1794506400, 1794592800),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/13/26 - 18Z 11/14/26","component":"SNOW_LOAD","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 2116Z","start_time":"18Z 11/13/26","end_time":"18Z 11/14/26","idp_source":"SNOW_LOAD_Day_3","idp_filedate":1794432790000,"idp_ingestdate":1794432874000,"st_area(shape)":58616206648.33244,"st_perimeter(shape)":14083939.162767224},"geometry":{"rings":[[[-120.58760313257851,39.93798846441826],[-120.57426652198659,39.939941123877794],[-120.57172066413204,39.92971523580695],[-120.58505601079436,39.92776266897213],[-120.58760313257851,39.93798846441826]]]}}]}"#, "SNOW_LOAD_Day_3", 1794431760, 1794592800, 1794679200),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"21Z 11/11/26 - 18Z 11/14/26","component":"SNOW_LOAD","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 2116Z","start_time":"21Z 11/11/26","end_time":"18Z 11/14/26","idp_source":"SNOW_LOAD_Days_1_3","idp_filedate":1794432791000,"idp_ingestdate":1794432876000,"st_area(shape)":128887608663.5459,"st_perimeter(shape)":25396749.71711827},"geometry":{"rings":[[[-120.58760313257851,39.93798846441826],[-120.57426652198659,39.939941123877794],[-120.57172066413204,39.92971523580695],[-120.58505601079436,39.92776266897213],[-120.58760313257851,39.93798846441826]]]}}]}"#, "SNOW_LOAD_Days_1_3", 1794431760, 1794430800, 1794679200),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/12/26 - 18Z 11/13/26","component":"ICE_ACCUMULATION","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 1915Z","start_time":"18Z 11/12/26","end_time":"18Z 11/13/26","idp_source":"ICE_ACCUMULATION_Day_2","idp_filedate":1794432788000,"idp_ingestdate":1794432848000,"st_area(shape)":2399376.316390531,"st_perimeter(shape)":5960.667008876098},"geometry":{"rings":[[[-73.09747225408333,42.899399862629394],[-73.10896980308287,42.90077214384249],[-73.1096738918228,42.90114435209841],[-73.10993229940078,42.901751576036844],[-73.10805936413568,42.910173766001144],[-73.10755119616262,42.910689498677066],[-73.10672216703804,42.91087876612312],[-73.09522347897472,42.90950643090031],[-73.09451938484492,42.90913418693722],[-73.09426105272539,42.90852696860188],[-73.09613512705428,42.90010483330529],[-73.09664330041724,42.89958909827613],[-73.09747225408333,42.899399862629394]]]}}]}"#, "ICE_ACCUMULATION_Day_2", 1794424500, 1794506400, 1794592800),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"19Z 11/11/26 - 18Z 11/14/26","component":"ICE_ACCUMULATION","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 1915Z","start_time":"19Z 11/11/26","end_time":"18Z 11/14/26","idp_source":"ICE_ACCUMULATION_Days_1_3","idp_filedate":1794432789000,"idp_ingestdate":1794432857000,"st_area(shape)":3919590.1521702968,"st_perimeter(shape)":13916.224240063239},"geometry":{"rings":[[[-73.09747225408333,42.899399862629394],[-73.10896980308287,42.90077214384249],[-73.1096738918228,42.90114435209841],[-73.10993229940078,42.901751576036844],[-73.10805936413568,42.910173766001144],[-73.10755119616262,42.910689498677066],[-73.10672216703804,42.91087876612312],[-73.09522347897472,42.90950643090031],[-73.09451938484492,42.90913418693722],[-73.09426105272539,42.90852696860188],[-73.09613512705428,42.90010483330529],[-73.09664330041724,42.89958909827613],[-73.09747225408333,42.899399862629394]]]}}]}"#, "ICE_ACCUMULATION_Days_1_3", 1794424500, 1794423600, 1794679200),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"21Z 11/11/26 - 18Z 11/12/26","component":"BLOWING_SNOW","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 2116Z","start_time":"21Z 11/11/26","end_time":"18Z 11/12/26","idp_source":"BLOWING_SNOW_Day_1","idp_filedate":1794432787000,"idp_ingestdate":1794432835000,"st_area(shape)":907695253.1273892,"st_perimeter(shape)":964525.7638371289},"geometry":{"rings":[[[-88.12719330632063,47.477008596172446],[-88.12781253211398,47.46875877685124],[-88.12826062165915,47.46822272060472],[-88.1290948807753,47.46797561611452],[-88.17791308647561,47.46964357924095],[-88.18426112485564,47.46655111425612],[-88.18303275595972,47.48305084175046],[-88.12200123172632,47.480965811201806],[-88.12719330632063,47.477008596172446]]]}}]}"#, "BLOWING_SNOW_Day_1", 1794431760, 1794430800, 1794506400),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/12/26 - 18Z 11/13/26","component":"BLOWING_SNOW","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 2116Z","start_time":"18Z 11/12/26","end_time":"18Z 11/13/26","idp_source":"BLOWING_SNOW_Day_2","idp_filedate":1794432787000,"idp_ingestdate":1794432840000,"st_area(shape)":36264212358.97023,"st_perimeter(shape)":12812789.087163316},"geometry":{"rings":[[[-71.60011426122703,43.090494743495015],[-71.597708598049,43.10057057749343],[-71.57241103712835,43.09734822813947],[-71.57481919672456,43.087272519967165],[-71.60011426122703,43.090494743495015]]]}}]}"#, "BLOWING_SNOW_Day_2", 1794431760, 1794506400, 1794592800),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"18Z 11/13/26 - 18Z 11/14/26","component":"BLOWING_SNOW","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 2116Z","start_time":"18Z 11/13/26","end_time":"18Z 11/14/26","idp_source":"BLOWING_SNOW_Day_3","idp_filedate":1794432787000,"idp_ingestdate":1794432840000,"st_area(shape)":68747930710.03217,"st_perimeter(shape)":19602064.452322077},"geometry":{"rings":[[[-112.34760390815313,38.23531432198814],[-112.35974988448096,38.23408641051654],[-112.36842613778681,38.28698604299235],[-112.36815276966605,38.28760134362502],[-112.36746372591053,38.28796483858823],[-112.35531168954782,38.28919300313778],[-112.34664177205966,38.23629322200275],[-112.34691513299389,38.23567781829312],[-112.34760390815313,38.23531432198814]]]}}]}"#, "BLOWING_SNOW_Day_3", 1794431760, 1794592800, 1794679200),
            (#"{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326,"latestWkid":4326},"features":[{"attributes":{"objectid":1,"product":"WINTER STORM SEVERITY INDEX","valid_time":"21Z 11/11/26 - 18Z 11/14/26","component":"BLOWING_SNOW","impact":"WINTER WEATHER AREA","issue_time":"2026-11-11 2116Z","start_time":"21Z 11/11/26","end_time":"18Z 11/14/26","idp_source":"BLOWING_SNOW_Days_1_3","idp_filedate":1794432788000,"idp_ingestdate":1794432848000,"st_area(shape)":86603855335.00703,"st_perimeter(shape)":26679691.230066497},"geometry":{"rings":[[[-71.60011426122703,43.090494743495015],[-71.597708598049,43.10057057749343],[-71.57241103712835,43.09734822813947],[-71.57481919672456,43.087272519967165],[-71.60011426122703,43.090494743495015]]]}}]}"#, "BLOWING_SNOW_Days_1_3", 1794431760, 1794430800, 1794679200)
        ]
        for (json, source, issued, start, end) in samples {
            let feature = try #require(WSSIDecoder.decode(Data(json.utf8)).features.first)
            #expect("\(feature.product.rawValue)_\(feature.period.rawValue)" == source)
            #expect(feature.issuedAt.timeIntervalSince1970 == issued)
            #expect(feature.validFrom.timeIntervalSince1970 == start)
            #expect(feature.validTo.timeIntervalSince1970 == end)
        }
    }
}
