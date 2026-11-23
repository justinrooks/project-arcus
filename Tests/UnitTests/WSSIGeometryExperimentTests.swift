#if DEBUG
import CoreLocation
import Foundation
import Testing
@testable import SkyAware

struct WSSIGeometryExperimentTests {
    private typealias Experiment = WSSIGeometryExperiment

    @Test func containmentIncludesOuterBoundaryAndExcludesHoleBoundaryAndReportsOverlap() throws {
        let result = try Experiment.measure(fixture(), fixtureIdentity: "synthetic", points: [
            .init(latitude: 1, longitude: 1), .init(latitude: 5, longitude: 5),
            .init(latitude: 20, longitude: 20), .init(latitude: 0, longitude: 5),
            .init(latitude: 3, longitude: 5)
        ])
        #expect(result.matchingSeverities == [["A", "B"], ["B"], [], ["A", "B"], ["B"]])
        #expect(result.featureCount == 2)
        #expect(result.polygonCount == 2)
        #expect(result.ringCount == 3)
        #expect(result.vertexCount == 15)
        #expect(result.decodeSeconds > 0)
        #expect(result.containmentSeconds > 0)
    }

    @Test(arguments: ["wrongType", "openRing", "missingGeometry", "invalidPosition", "emptyFeatures"])
    func rejectsIncompleteGeometry(kind: String) throws {
        var json = String(decoding: fixture(), as: UTF8.self)
        switch kind {
        case "emptyFeatures":
            let range = try #require(json.range(of: "\"features\":["))
            json = String(json[..<range.lowerBound]) + "\"features\":[]}"
        case "wrongType": json = json.replacingOccurrences(of: "MultiPolygon", with: "Polygon")
        case "openRing": json = json.replacingOccurrences(of: "[0,0]]]", with: "[0,1]]]")
        case "missingGeometry": json = json.replacingOccurrences(of: "\"geometry\":", with: "\"missing\":")
        default: json = json.replacingOccurrences(of: "[10,0]", with: "[181,0]")
        }
        #expect(throws: (any Error).self) {
            try Experiment.measure(Data(json.utf8), fixtureIdentity: kind, points: [])
        }
    }

    @Test func diagonalBoundaryDoesNotAbsorbNearbyOutsidePoint() throws {
        let json = """
        {"type":"FeatureCollection","metadata":{"product":"Overall_Impact","day":1,"revision":"8afb87e2-451c-431c-8b0d-e18ea577ce0d"},"features":[{"type":"Feature","properties":{"sourceObjectId":1,"severity":"A"},"geometry":{"type":"MultiPolygon","coordinates":[[[[0,0],[10,10],[0,10],[0,0]]]]}}]}
        """
        let result = try Experiment.measure(Data(json.utf8), fixtureIdentity: "diagonal", points: [
            .init(latitude: 5, longitude: 5), .init(latitude: 5, longitude: 5.000000000001),
            .init(latitude: 5, longitude: 4.999999999999)
        ])
        #expect(result.matchingSeverities == [["A"], [], ["A"]])
    }

    @Test func decodesCapturedForgeGeometry() throws {
        let url = try #require(Bundle(for: WSSIFixtureBundleLocator.self).url(forResource: "overall-1", withExtension: "geojson"))
        let data = try Data(contentsOf: url)
        let result = try Experiment.measure(data, fixtureIdentity: "overall-1", points: [.init(latitude: 40, longitude: -100)])
        #expect(result.metadata.revision.uuidString.lowercased() == "8afb87e2-451c-431c-8b0d-e18ea577ce0d")
        #expect(result.featureCount == 5)
        #expect(result.polygonCount == 478)
        #expect(result.ringCount == 639)
        #expect(result.vertexCount == 55_440)
        #expect(result.bodyBytes == 2_205_798)
        let observation = "Simulator only; not physical-device performance. Fixture: \(result.fixtureIdentity), revision: \(result.metadata.revision). Features: \(result.featureCount), polygons: \(result.polygonCount), rings: \(result.ringCount), vertices: \(result.vertexCount), body bytes: \(result.bodyBytes). Decode: \(result.decodeSeconds)s; containment: \(result.containmentSeconds)s. Sampled process footprint bytes before decode / with geometry / after geometry release: \(String(describing: result.footprintBeforeDecode)) / \(String(describing: result.footprintWithGeometry)) / \(String(describing: result.footprintAfterGeometryRelease)). Samples are not peak memory."
        Attachment.record(observation, named: "WSSI simulator observation.txt")
    }

    private func fixture() -> Data {
        Data("""
        {"type":"FeatureCollection","metadata":{"product":"Overall_Impact","day":1,"revision":"8afb87e2-451c-431c-8b0d-e18ea577ce0d"},"features":[
        {"type":"Feature","properties":{"sourceObjectId":1,"severity":"A"},"geometry":{"type":"MultiPolygon","coordinates":[[[[0,0],[10,0],[10,10],[0,10],[0,0]],[[3,3],[7,3],[7,7],[3,7],[3,3]]]]}},
        {"type":"Feature","properties":{"sourceObjectId":2,"severity":"B"},"geometry":{"type":"MultiPolygon","coordinates":[[[[0,0],[10,0],[10,10],[0,10],[0,0]]]]}}
        ]}
        """.utf8)
    }
}
private final class WSSIFixtureBundleLocator: NSObject {}
#endif
