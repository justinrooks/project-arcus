import Foundation

struct StormSetupDTO: Codable, Sendable, Equatable {
    let h3Cell: Int64
    let freshness: Freshness
    let source: Source
    let raw: Raw
    let assessment: Assessment
    let anvilEvidence: AnvilEvidence?
    let centroid: Coordinate2D?
    let surfaceHeightMslM: Double

    var assessmentModel: StormSetupAssessment { .init(dto: self) }
}

extension StormSetupDTO {
    struct Freshness: Codable, Sendable, Equatable {
        let isStale: Bool
        let isDegraded: Bool
        let modelRunTime: Date
        let sourceValidTime: Date
        let forecastHour: Int
        let fetchedAt: Date
        let expiresAt: Date
    }

    struct Source: Codable, Sendable, Equatable {
        let model: String
        let product: String
        let domain: String
        let fieldSetVersion: String
        let sourceKind: String
        let runTime: Date
        let validTime: Date
        let forecastHour: Int
        let bbox: Bbox
        let primaryDownloadURL: String?
    }

    struct Bbox: Codable, Sendable, Equatable {
        let toplat: Double
        let leftlon: Double
        let rightlon: Double
        let bottomlat: Double
    }

    struct Raw: Codable, Sendable, Equatable {
        let mlcapeJkg: Double?
        let mucapeJkg: Double?
        let sbcapeJkg: Double?
        let mlcinJkg: Double?
        let srh01kmM2s2: Double?
        let srh03kmM2s2: Double?
        let shear06kmKt: Double?
        let mllclM: Double?
        let tempDewPtDeltaF: Double?
        let threeCapeJkg: Double?
    }

    struct Assessment: Codable, Sendable, Equatable {
        let overall: String?
        let summary: String?
        let instability: String?
        let moisture: String?
        let lowLevelRotation: String?
        let deepShear: String?
        let cloudBase: String?
        let capInhibition: String?
        let limitingFactors: [String]?
        let confidence: String?
        let primaryDrivers: [String]?
        let stormMode: String?
        let stormModeHint: String?
        let trend: String?
        let compositeSignal: String?
    }

    struct AnvilEvidence: Codable, Sendable, Equatable {
        let status: String?
        let scp: Support?
        let stp: Support?
        let ship: Support?
        let diagnostics: Diagnostics?

        struct Support: Codable, Sendable, Equatable {
            let support: String?
        }

        struct Diagnostics: Codable, Sendable, Equatable {
            let hasEffectiveLayer: Bool?
            let hasStormMotion: Bool?
            let qualityProfileLevelCount: Int?
            let warnings: [String]?
        }
    }
}
