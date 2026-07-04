import Foundation

enum StormSetupSignal: String, Codable, Sendable, Equatable {
    case strong
    case supportive
    case conditional
    case weak
    case unknown

    init(normalized value: String?) {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "strong": self = .strong
        case "supportive": self = .supportive
        case "conditional": self = .conditional
        case "weak": self = .weak
        default: self = .unknown
        }
    }
}

enum StormSetupConfidence: String, Codable, Sendable, Equatable {
    case low, medium, high, unknown

    init(normalized value: String?) {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        default: self = .unknown
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = .init(normalized: try? container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct StormSetupAssessment: Codable, Sendable, Equatable {
    let h3Cell: Int64
    let freshness: Freshness
    let source: Source
    let raw: Raw
    let assessment: ReadableAssessment
    let anvilEvidence: AnvilEvidence?
    let centroid: Coordinate2D?
    let surfaceHeightMslM: Double

    init(dto: StormSetupDTO) {
        h3Cell = dto.h3Cell
        freshness = .init(dto: dto.freshness)
        source = .init(dto: dto.source)
        raw = .init(dto: dto.raw)
        assessment = .init(dto: dto.assessment)
        anvilEvidence = dto.anvilEvidence.map(AnvilEvidence.init(dto:))
        centroid = dto.centroid
        surfaceHeightMslM = dto.surfaceHeightMslM
    }
}

extension StormSetupAssessment {
    struct Freshness: Codable, Sendable, Equatable {
        let isStale: Bool
        let isDegraded: Bool
        let modelRunTime: Date
        let sourceValidTime: Date
        let forecastHour: Int
        let fetchedAt: Date
        let expiresAt: Date

        init(dto: StormSetupDTO.Freshness) {
            isStale = dto.isStale
            isDegraded = dto.isDegraded
            modelRunTime = dto.modelRunTime
            sourceValidTime = dto.sourceValidTime
            forecastHour = dto.forecastHour
            fetchedAt = dto.fetchedAt
            expiresAt = dto.expiresAt
        }
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

        init(dto: StormSetupDTO.Source) {
            model = dto.model
            product = dto.product
            domain = dto.domain
            fieldSetVersion = dto.fieldSetVersion
            sourceKind = dto.sourceKind
            runTime = dto.runTime
            validTime = dto.validTime
            forecastHour = dto.forecastHour
            bbox = .init(dto: dto.bbox)
        }
    }

    struct Bbox: Codable, Sendable, Equatable {
        let toplat: Double
        let leftlon: Double
        let rightlon: Double
        let bottomlat: Double

        init(dto: StormSetupDTO.Bbox) {
            toplat = dto.toplat
            leftlon = dto.leftlon
            rightlon = dto.rightlon
            bottomlat = dto.bottomlat
        }
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

        init(dto: StormSetupDTO.Raw) {
            mlcapeJkg = dto.mlcapeJkg
            mucapeJkg = dto.mucapeJkg
            sbcapeJkg = dto.sbcapeJkg
            mlcinJkg = dto.mlcinJkg
            srh01kmM2s2 = dto.srh01kmM2s2
            srh03kmM2s2 = dto.srh03kmM2s2
            shear06kmKt = dto.shear06kmKt
            mllclM = dto.mllclM
            tempDewPtDeltaF = dto.tempDewPtDeltaF
            threeCapeJkg = dto.threeCapeJkg
        }
    }

    struct ReadableAssessment: Codable, Sendable, Equatable {
        let overall: StormSetupSignal
        let summary: String?
        let instability: StormSetupSignal
        let moisture: StormSetupSignal
        let lowLevelRotation: StormSetupSignal
        let deepShear: StormSetupSignal
        let cloudBase: StormSetupSignal
        let capInhibition: StormSetupSignal
        let limitingFactors: [String]
        let confidence: StormSetupConfidence
        let primaryDrivers: [String]
        let stormMode: StormSetupSignal
        let stormModeHint: StormSetupSignal
        let trend: StormSetupSignal
        let compositeSignal: StormSetupSignal

        init(dto: StormSetupDTO.Assessment) {
            overall = .init(normalized: dto.overall)
            summary = dto.summary?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            instability = .init(normalized: dto.instability)
            moisture = .init(normalized: dto.moisture)
            lowLevelRotation = .init(normalized: dto.lowLevelRotation)
            deepShear = .init(normalized: dto.deepShear)
            cloudBase = .init(normalized: dto.cloudBase)
            capInhibition = .init(normalized: dto.capInhibition)
            limitingFactors = dto.limitingFactors ?? []
            confidence = .init(normalized: dto.confidence)
            primaryDrivers = dto.primaryDrivers ?? []
            stormMode = .init(normalized: dto.stormMode)
            stormModeHint = .init(normalized: dto.stormModeHint)
            trend = .init(normalized: dto.trend)
            compositeSignal = .init(normalized: dto.compositeSignal)
        }
    }

    struct AnvilEvidence: Codable, Sendable, Equatable {
        let status: String?
        let scp: Support
        let stp: Support
        let ship: Support
        let diagnostics: Diagnostics

        init(dto: StormSetupDTO.AnvilEvidence) {
            status = dto.status?.trimmingCharacters(in: .whitespacesAndNewlines)
            scp = .init(dto: dto.scp ?? .init(support: nil))
            stp = .init(dto: dto.stp ?? .init(support: nil))
            ship = .init(dto: dto.ship ?? .init(support: nil))
            diagnostics = .init(dto: dto.diagnostics ?? .init(
                hasEffectiveLayer: nil,
                hasStormMotion: nil,
                qualityProfileLevelCount: nil,
                warnings: nil
            ))
        }
    }

    struct Support: Codable, Sendable, Equatable {
        let support: StormSetupSignal

        init(dto: StormSetupDTO.AnvilEvidence.Support) {
            support = .init(normalized: dto.support)
        }
    }

    struct Diagnostics: Codable, Sendable, Equatable {
        let hasEffectiveLayer: Bool?
        let hasStormMotion: Bool?
        let qualityProfileLevelCount: Int?
        let warnings: [String]

        init(dto: StormSetupDTO.AnvilEvidence.Diagnostics) {
            hasEffectiveLayer = dto.hasEffectiveLayer
            hasStormMotion = dto.hasStormMotion
            qualityProfileLevelCount = dto.qualityProfileLevelCount
            warnings = dto.warnings ?? []
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
