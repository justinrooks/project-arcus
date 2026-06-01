import Foundation
import Testing
@testable import SkyAware

@Suite("MdDTO Codable Compatibility")
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

        let decoded = try JSONDecoder().decode(MdDTO.self, from: Data(json.utf8))

        #expect(decoded.watchProbability == 35)
        #expect(decoded.watchProbabilityText == "35")
    }

    @Test("new payload preserves watchProbabilityText on round trip")
    func roundTripPreservesWatchProbabilityText() throws {
        let original = MdDTO(
            number: 1235,
            title: "Mesoscale Discussion",
            link: URL(string: "https://example.com/md/1235")!,
            issued: Date(timeIntervalSince1970: 0),
            validStart: Date(timeIntervalSince1970: 0),
            validEnd: Date(timeIntervalSince1970: 60),
            areasAffected: "Central Plains",
            summary: "Round-trip",
            watchProbability: "Unknown",
            threats: nil,
            coordinates: []
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MdDTO.self, from: encoded)

        #expect(decoded.watchProbability == nil)
        #expect(decoded.watchProbabilityText == "Unknown")
    }
}
