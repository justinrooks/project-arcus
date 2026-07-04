import Foundation
import Testing
@testable import SkyAware

@Suite("Storm Setup Mapping")
struct StormSetupMappingTests {
    @Test("complete response decodes and maps representative values")
    func completeResponseDecodesAndMaps() throws {
        let dto = try decodeDTO(completeJSON)
        let assessment = StormSetupAssessment(dto: dto)

        #expect(dto.h3Cell == 8_623_451_234_567_890)
        #expect(dto.freshness.isStale == false)
        #expect(dto.freshness.isDegraded == false)
        #expect(dto.freshness.forecastHour == 3)
        #expect(dto.source.primaryDownloadURL == "https://example.invalid/storm-setup")
        #expect(dto.raw.mlcapeJkg == 1_850)
        #expect(dto.raw.tempDewPtDeltaF == 4.5)
        #expect(assessment.assessment.summary == "The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation.")
        #expect(assessment.assessment.overall == .strong)
        #expect(assessment.assessment.confidence == .high)
        #expect(assessment.assessment.lowLevelRotation == .conditional)
        #expect(assessment.assessment.deepShear == .strong)
        #expect(assessment.assessment.cloudBase == .weak)
        #expect(assessment.assessment.limitingFactors == ["capping"])
        #expect(assessment.assessment.primaryDrivers == ["instability", "shear"])
        #expect(assessment.anvilEvidence?.scp.support == .supportive)
        #expect(assessment.anvilEvidence?.diagnostics.hasEffectiveLayer == true)
        #expect(assessment.anvilEvidence?.diagnostics.qualityProfileLevelCount == 3)
        #expect(assessment.anvilEvidence?.diagnostics.warnings == ["watch heating"])
    }

    @Test("partial response tolerates missing optional fields")
    func partialResponseToleratesMissingOptionalFields() throws {
        let dto = try decodeDTO(partialJSON)
        let assessment = StormSetupAssessment(dto: dto)

        #expect(dto.raw.mucapeJkg == nil)
        #expect(dto.raw.shear06kmKt == nil)
        #expect(dto.anvilEvidence == nil)
        #expect(assessment.assessment.overall == .unknown)
        #expect(assessment.assessment.limitingFactors.isEmpty)
        #expect(assessment.assessment.primaryDrivers.isEmpty)
    }

    @Test("freshness flags and timestamps are preserved")
    func staleDegradedResponsePreservesFreshness() throws {
        let dto = try decodeDTO(staleDegradedJSON)
        let assessment = StormSetupAssessment(dto: dto)

        #expect(assessment.freshness.isStale == true)
        #expect(assessment.freshness.isDegraded == true)
        #expect(assessment.freshness.modelRunTime == iso("2026-06-01T18:00:00Z"))
        #expect(assessment.freshness.sourceValidTime == iso("2026-06-01T21:00:00Z"))
        #expect(assessment.freshness.forecastHour == 3)
        #expect(assessment.freshness.fetchedAt == iso("2026-06-01T21:08:00Z"))
        #expect(assessment.freshness.expiresAt == iso("2026-06-01T22:00:00Z"))
    }

    @Test("unknown category decodes as unknown")
    func unknownCategoryMapsToUnknown() throws {
        let dto = try decodeDTO(unknownCategoryJSON)
        let assessment = StormSetupAssessment(dto: dto)

        #expect(assessment.assessment.overall == .unknown)
        #expect(assessment.assessment.stormMode == .unknown)
        #expect(assessment.assessment.trend == .unknown)
    }

    @Test("mixed-case confidence normalizes to high")
    func mixedCaseConfidenceMapsToHigh() throws {
        let dto = try decodeDTO(completeJSON.replacingOccurrences(
            of: "\"confidence\": \"high\"",
            with: "\"confidence\": \" High \""
        ))
        let assessment = StormSetupAssessment(dto: dto)

        #expect(assessment.assessment.confidence == .high)
    }

    @Test("missing summary decodes as nil")
    func missingSummaryDecodesAsNil() throws {
        let dto = try decodeDTO(completeJSON.replacingOccurrences(
            of: "    \"summary\": \"The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation.\",\n",
            with: ""
        ))
        let assessment = StormSetupAssessment(dto: dto)

        #expect(assessment.assessment.summary == nil)
    }

    @Test("whitespace-only summary decodes as nil")
    func whitespaceOnlySummaryDecodesAsNil() throws {
        let dto = try decodeDTO(completeJSON.replacingOccurrences(
            of: "\"summary\": \"The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation.\"",
            with: "\"summary\": \"   \""
        ))
        let assessment = StormSetupAssessment(dto: dto)

        #expect(assessment.assessment.summary == nil)
    }

    @Test("missing confidence decodes as unknown")
    func missingConfidenceDecodesAsUnknown() throws {
        let dto = try decodeDTO(completeJSON.replacingOccurrences(
            of: "    \"confidence\": \"high\",\n",
            with: ""
        ))
        let assessment = StormSetupAssessment(dto: dto)

        #expect(assessment.assessment.confidence == .unknown)
    }

    @Test("future confidence decodes as unknown")
    func futureConfidenceDecodesAsUnknown() throws {
        let dto = try decodeDTO(completeJSON.replacingOccurrences(
            of: "\"confidence\": \"high\"",
            with: "\"confidence\": \"exceptional-new-value\""
        ))
        let assessment = StormSetupAssessment(dto: dto)

        #expect(assessment.assessment.confidence == .unknown)
    }

    @Test("transport-only keys do not reach the domain model")
    func transportOnlyKeysDoNotReachDomainModel() throws {
        let dto = try decodeDTO(completeJSON)
        let assessment = StormSetupAssessment(dto: dto)

        #expect(dto.source.primaryDownloadURL == "https://example.invalid/storm-setup")

        let encoded = try JSONEncoder().encode(assessment)
        let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let source = try #require(json["source"] as? [String: Any])
        let raw = try #require(json["raw"] as? [String: Any])

        #expect(source["primaryDownloadURL"] == nil)
        #expect(raw["diagnostics"] == nil)
    }

    @Test("partial anvil evidence tolerates omitted support blocks")
    func partialAnvilEvidenceToleratesOmittedSupportBlocks() throws {
        let dto = try decodeDTO(partialAnvilEvidenceJSON)
        let assessment = StormSetupAssessment(dto: dto)

        #expect(dto.anvilEvidence?.scp == nil)
        #expect(dto.anvilEvidence?.stp == nil)
        #expect(dto.anvilEvidence?.ship?.support == "weak")
        #expect(assessment.anvilEvidence?.scp.support == .unknown)
        #expect(assessment.anvilEvidence?.stp.support == .unknown)
        #expect(assessment.anvilEvidence?.ship.support == .weak)
        #expect(assessment.anvilEvidence?.diagnostics.warnings == [
            "storm-motion calculation unavailable"
        ])
    }
}

private let completeJSON = #"""
{
  "h3Cell": 8623451234567890,
  "freshness": {
    "isStale": false,
    "isDegraded": false,
    "modelRunTime": "2026-06-01T18:00:00Z",
    "sourceValidTime": "2026-06-01T21:00:00Z",
    "forecastHour": 3,
    "fetchedAt": "2026-06-01T21:03:00Z",
    "expiresAt": "2026-06-01T22:00:00Z"
  },
  "source": {
    "model": "HRRR",
    "product": "Storm Setup",
    "domain": "severe",
    "fieldSetVersion": "1",
    "sourceKind": "production",
    "runTime": "2026-06-01T18:00:00Z",
    "validTime": "2026-06-01T21:00:00Z",
    "forecastHour": 3,
    "bbox": {
      "toplat": 41.5,
      "leftlon": -104.3,
      "rightlon": -96.2,
      "bottomlat": 36.8
    },
    "primaryDownloadURL": "https://example.invalid/storm-setup"
  },
  "raw": {
    "mlcapeJkg": 1850,
    "mucapeJkg": 2200.5,
    "sbcapeJkg": 1700,
    "mlcinJkg": -42,
    "srh01kmM2s2": 125.5,
    "srh03kmM2s2": 175,
    "shear06kmKt": 42,
    "mllclM": 980,
    "tempDewPtDeltaF": 4.5,
    "threeCapeJkg": 95,
    "diagnostics": {
      "inventory": {
        "debugOnly": true
      },
      "debug": [
        "ignored"
      ]
    }
  },
  "assessment": {
    "overall": " strong ",
    "summary": "The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation.",
    "instability": "supportive",
    "moisture": "supportive",
    "lowLevelRotation": " conditional ",
    "deepShear": "strong",
    "cloudBase": "weak",
    "capInhibition": "weak",
    "limitingFactors": [
      "capping"
    ],
    "confidence": "high",
    "primaryDrivers": [
      "instability",
      "shear"
    ],
    "stormMode": "supportive",
    "stormModeHint": "supportive",
    "trend": "conditional",
    "compositeSignal": "strong"
  },
  "anvilEvidence": {
    "status": "available",
    "scp": {
      "support": "supportive"
    },
    "stp": {
      "support": "conditional"
    },
    "ship": {
      "support": "weak"
    },
    "diagnostics": {
      "hasEffectiveLayer": true,
      "hasStormMotion": false,
      "qualityProfileLevelCount": 3,
      "warnings": [
        "watch heating"
      ]
    }
  },
  "centroid": {
    "latitude": 39.5,
    "longitude": -100.0
  },
  "surfaceHeightMslM": 1132.4
}
"""#

private let partialJSON = #"""
{
  "h3Cell": 8623451234567890,
  "freshness": {
    "isStale": false,
    "isDegraded": false,
    "modelRunTime": "2026-06-01T18:00:00Z",
    "sourceValidTime": "2026-06-01T21:00:00Z",
    "forecastHour": 3,
    "fetchedAt": "2026-06-01T21:03:00Z",
    "expiresAt": "2026-06-01T22:00:00Z"
  },
  "source": {
    "model": "HRRR",
    "product": "Storm Setup",
    "domain": "severe",
    "fieldSetVersion": "1",
    "sourceKind": "production",
    "runTime": "2026-06-01T18:00:00Z",
    "validTime": "2026-06-01T21:00:00Z",
    "forecastHour": 3,
    "bbox": {
      "toplat": 41.5,
      "leftlon": -104.3,
      "rightlon": -96.2,
      "bottomlat": 36.8
    }
  },
  "raw": {
    "mlcapeJkg": 1200
  },
  "assessment": {
    "limitingFactors": [],
    "primaryDrivers": []
  },
  "surfaceHeightMslM": 1132.4
}
"""#

private let partialAnvilEvidenceJSON = #"""
{
  "h3Cell": 8623451234567890,
  "freshness": {
    "isStale": false,
    "isDegraded": false,
    "modelRunTime": "2026-06-01T18:00:00Z",
    "sourceValidTime": "2026-06-01T21:00:00Z",
    "forecastHour": 3,
    "fetchedAt": "2026-06-01T21:03:00Z",
    "expiresAt": "2026-06-01T22:00:00Z"
  },
  "source": {
    "model": "HRRR",
    "product": "Storm Setup",
    "domain": "severe",
    "fieldSetVersion": "1",
    "sourceKind": "production",
    "runTime": "2026-06-01T18:00:00Z",
    "validTime": "2026-06-01T21:00:00Z",
    "forecastHour": 3,
    "bbox": {
      "toplat": 41.5,
      "leftlon": -104.3,
      "rightlon": -96.2,
      "bottomlat": 36.8
    },
    "primaryDownloadURL": "https://example.invalid/storm-setup"
  },
  "raw": {
    "mlcapeJkg": 1850,
    "mucapeJkg": 2200.5,
    "sbcapeJkg": 1700,
    "mlcinJkg": -42,
    "srh01kmM2s2": 125.5,
    "srh03kmM2s2": 175,
    "shear06kmKt": 42,
    "mllclM": 980,
    "tempDewPtDeltaF": 4.5,
    "threeCapeJkg": 95
  },
  "assessment": {
    "overall": "strong",
    "summary": "The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation.",
    "instability": "supportive",
    "moisture": "supportive",
    "lowLevelRotation": "conditional",
    "deepShear": "strong",
    "cloudBase": "weak",
    "capInhibition": "weak",
    "limitingFactors": [
      "capping"
    ],
    "confidence": "high",
    "primaryDrivers": [
      "instability",
      "shear"
    ],
    "stormMode": "supportive",
    "stormModeHint": "supportive",
    "trend": "conditional",
    "compositeSignal": "strong"
  },
  "anvilEvidence": {
    "status": "degraded",
    "ship": {
      "support": "weak"
    },
    "diagnostics": {
      "hasEffectiveLayer": false,
      "hasStormMotion": false,
      "qualityProfileLevelCount": 36,
      "warnings": [
        "storm-motion calculation unavailable"
      ]
    }
  },
  "centroid": {
    "latitude": 39.5,
    "longitude": -100.0
  },
  "surfaceHeightMslM": 1132.4
}
"""#

private let staleDegradedJSON = #"""
{
  "h3Cell": 8623451234567890,
  "freshness": {
    "isStale": true,
    "isDegraded": true,
    "modelRunTime": "2026-06-01T18:00:00Z",
    "sourceValidTime": "2026-06-01T21:00:00Z",
    "forecastHour": 3,
    "fetchedAt": "2026-06-01T21:08:00Z",
    "expiresAt": "2026-06-01T22:00:00Z"
  },
  "source": {
    "model": "HRRR",
    "product": "Storm Setup",
    "domain": "severe",
    "fieldSetVersion": "1",
    "sourceKind": "production",
    "runTime": "2026-06-01T18:00:00Z",
    "validTime": "2026-06-01T21:00:00Z",
    "forecastHour": 3,
    "bbox": {
      "toplat": 41.5,
      "leftlon": -104.3,
      "rightlon": -96.2,
      "bottomlat": 36.8
    }
  },
  "raw": {
    "mlcapeJkg": 1600
  },
  "assessment": {
    "overall": "conditional"
  },
  "surfaceHeightMslM": 1132.4
}
"""#

private let unknownCategoryJSON = #"""
{
  "h3Cell": 8623451234567890,
  "freshness": {
    "isStale": false,
    "isDegraded": false,
    "modelRunTime": "2026-06-01T18:00:00Z",
    "sourceValidTime": "2026-06-01T21:00:00Z",
    "forecastHour": 3,
    "fetchedAt": "2026-06-01T21:03:00Z",
    "expiresAt": "2026-06-01T22:00:00Z"
  },
  "source": {
    "model": "HRRR",
    "product": "Storm Setup",
    "domain": "severe",
    "fieldSetVersion": "1",
    "sourceKind": "production",
    "runTime": "2026-06-01T18:00:00Z",
    "validTime": "2026-06-01T21:00:00Z",
    "forecastHour": 3,
    "bbox": {
      "toplat": 41.5,
      "leftlon": -104.3,
      "rightlon": -96.2,
      "bottomlat": 36.8
    }
  },
  "raw": {
    "mlcapeJkg": 1800
  },
  "assessment": {
    "overall": "exceptional-new-value",
    "stormMode": "exceptional-new-value",
    "trend": "exceptional-new-value"
  },
  "surfaceHeightMslM": 1132.4
}
"""#

private func decodeDTO(_ json: String) throws -> StormSetupDTO {
    try DecoderFactory.iso8601.decode(StormSetupDTO.self, from: Data(json.utf8))
}

private func iso(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)!
}
