import Foundation
import ArcusCore
import Testing
@testable import SkyAware

@Suite("Mesoscale discussion payload Codable compatibility")
struct MdDTOCodableCompatibilityTests {
    @Test("legacy payload decodes when watchProbabilityText is missing")
    func legacyPayloadWithoutWatchProbabilityTextDecodes() throws {
        let json = #"""
        {
          "number": 1234,
          "title": "Mesoscale Discussion",
          "link": "https://example.com/md/1234",
          "issued": 0,
          "validStart": 0,
          "validEnd": 60,
          "areasAffected": "Central Plains",
          "summary": "Legacy persisted record",
          "concerning": "Severe potential",
          "watchProbability": 35,
          "threats": null,
          "coordinates": []
        }
        """#

        let decoded = try JSONDecoder().decode(MesoscaleDiscussionPayload.self, from: Data(json.utf8))

        #expect(decoded.watchProbability == 35)
        #expect(decoded.watchProbabilityText == "35")
        #expect(decoded.sourceURL == URL(string: "https://example.com/md/1234"))
        #expect(decoded.productID == "SPC-MD-2001-1234")
    }

    @Test("legacy app cache decodes when watchProbabilityText is missing")
    func legacyAppCacheWithoutWatchProbabilityTextDecodes() throws {
        let json = #"""
        {
          "number": 1234,
          "title": "Mesoscale Discussion",
          "link": "https://example.com/md/1234",
          "issued": 0,
          "validStart": 0,
          "validEnd": 60,
          "areasAffected": "Central Plains",
          "summary": "Legacy persisted record",
          "concerning": "Severe potential",
          "watchProbability": 35,
          "threats": null,
          "coordinates": []
        }
        """#

        let decoded = try JSONDecoder().decode(MdDTO.self, from: Data(json.utf8))

        #expect(decoded.watchProbability == 35)
        #expect(decoded.watchProbabilityText == "35")
    }

    @Test("new payload preserves watchProbabilityText on round trip")
    func roundTripPreservesWatchProbabilityText() throws {
        let original = MesoscaleDiscussionPayload(
            number: 1235,
            title: "Mesoscale Discussion",
            sourceURL: URL(string: "https://example.com/md/1235")!,
            issued: Date(timeIntervalSince1970: 0),
            validStart: Date(timeIntervalSince1970: 0),
            validEnd: Date(timeIntervalSince1970: 60),
            areasAffected: "Central Plains",
            summary: "Round-trip",
            concerning: nil,
            watchProbability: nil,
            watchProbabilityText: "Unknown",
            threats: nil,
            coordinates: []
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MesoscaleDiscussionPayload.self, from: encoded)

        #expect(decoded.watchProbability == nil)
        #expect(decoded.watchProbabilityText == "Unknown")
    }

    @Test("app adapter preserves presentation fields from the shared payload")
    func appAdapterPreservesPresentationFields() {
        let sourceURL = URL(string: "https://example.com/md/1236")!
        let payload = MesoscaleDiscussionPayload(
            number: 1236,
            title: "Mesoscale Discussion",
            sourceURL: sourceURL,
            issued: Date(timeIntervalSince1970: 1_800_000_000),
            validStart: Date(timeIntervalSince1970: 1_800_000_000),
            validEnd: Date(timeIntervalSince1970: 1_800_003_600),
            areasAffected: "Central Plains",
            summary: "Adapter",
            concerning: "Severe potential",
            watchProbability: 35,
            watchProbabilityText: "35%",
            threats: .init(peakWindMPH: 60, hailRangeInches: 1.5, tornadoStrength: nil),
            coordinates: [.init(latitude: 39, longitude: -100)]
        )

        let adapter = MdDTO(payload: payload)

        #expect(adapter.id == 1236)
        #expect(adapter.link == sourceURL)
        #expect(adapter.alertType == .mesoscale)
        #expect(adapter.watchProbability == 35)
        #expect(adapter.watchProbabilityText == "35%")
        #expect(adapter.threats == MDThreats(peakWindMPH: 60, hailRangeInches: 1.5, tornadoStrength: nil))
        #expect(adapter.coordinates == [Coordinate2D(latitude: 39, longitude: -100)])
    }
}
