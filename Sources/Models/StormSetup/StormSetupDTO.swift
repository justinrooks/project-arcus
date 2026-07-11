import ArcusCore
import Foundation

struct StormSetupDTO: Codable, Sendable, Equatable {
    let h3Cell: Int64
    let freshness: Freshness
    let source: Source
    let raw: Raw
    let assessment: Assessment
    let anvilEvidence: AnvilEvidence?
    let centroid: Coordinate2D?
    let surfaceHeightMslM: Double?

    var assessmentModel: StormSetupAssessment { .init(dto: self) }
}

extension StormSetupDTO {
    struct Freshness: Codable, Sendable, Equatable {
        let isStale: Bool
        let isDegraded: Bool
        let modelRunTime: Date?
        let sourceValidTime: Date?
        let forecastHour: Int?
        let fetchedAt: Date
        let expiresAt: Date
    }

    struct Source: Codable, Sendable, Equatable {
        let model: String?
        let product: String?
        let domain: String?
        let fieldSetVersion: String?
        let sourceKind: String
        let runTime: Date?
        let validTime: Date?
        let forecastHour: Int?
        let bbox: Bbox?
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

extension StormSetupDTO {
    init(response: StormSetupCurrentResponse) {
        self.init(
            h3Cell: response.setup.h3Cell,
            freshness: .init(
                isStale: response.setup.freshness.isStale,
                isDegraded: response.setup.freshness.isDegraded,
                modelRunTime: response.setup.freshness.modelRunTime,
                sourceValidTime: response.setup.freshness.sourceValidTime,
                forecastHour: response.setup.freshness.forecastHour,
                fetchedAt: response.setup.freshness.fetchedAt,
                expiresAt: response.setup.freshness.expiresAt
            ),
            source: .init(
                model: response.setup.source.model?.rawValue,
                product: response.setup.source.product?.rawValue,
                domain: response.setup.source.domain?.rawValue,
                fieldSetVersion: response.setup.source.fieldSetVersion?.rawValue,
                sourceKind: "production",
                runTime: response.setup.source.runTime,
                validTime: response.setup.source.validTime,
                forecastHour: response.setup.source.forecastHour,
                bbox: response.setup.source.bbox.map { .init(
                    toplat: $0.toplat,
                    leftlon: $0.leftlon,
                    rightlon: $0.rightlon,
                    bottomlat: $0.bottomlat
                ) },
                primaryDownloadURL: response.setup.source.primaryDownloadURL?.absoluteString
            ),
            raw: .init(
                mlcapeJkg: response.ingredients.canonical.mlcapeJkg,
                mucapeJkg: response.ingredients.canonical.mucapeJkg,
                sbcapeJkg: response.ingredients.canonical.sbcapeJkg,
                mlcinJkg: response.ingredients.canonical.mlcinJkg,
                srh01kmM2s2: response.ingredients.canonical.srh01kmM2s2,
                srh03kmM2s2: response.ingredients.canonical.srh03kmM2s2,
                shear06kmKt: response.ingredients.canonical.shear06kmKt,
                mllclM: response.ingredients.canonical.mllclM,
                tempDewPtDeltaF: response.ingredients.canonical.tempDewPtDeltaF,
                threeCapeJkg: response.ingredients.canonical.threeCapeJkg
            ),
            assessment: .init(
                overall: response.tornadoViability.overall.rawValue,
                summary: response.tornadoViability.summary,
                instability: response.tornadoViability.details.instability.rawValue,
                moisture: response.tornadoViability.details.moisture.rawValue,
                lowLevelRotation: response.tornadoViability.details.lowLevelRotation.rawValue,
                deepShear: response.tornadoViability.details.deepShear.rawValue,
                cloudBase: response.tornadoViability.details.cloudBase.rawValue,
                capInhibition: response.tornadoViability.details.inhibition.rawValue,
                limitingFactors: response.tornadoViability.limitingFactors.map(\.rawValue),
                confidence: Self.legacyConfidenceString(from: response.tornadoViability.confidence),
                primaryDrivers: [],
                stormMode: response.tornadoViability.details.stormMode.rawValue,
                stormModeHint: response.tornadoViability.details.stormMode.rawValue,
                trend: response.tornadoViability.details.stormViability.rawValue,
                compositeSignal: response.tornadoViability.details.tornadoComposite.rawValue
            ),
            anvilEvidence: nil,
            centroid: .init(latitude: response.setup.centroid.latitude, longitude: response.setup.centroid.longitude),
            surfaceHeightMslM: response.setup.surfaceHeightMslM
        )
    }

    private static func legacyConfidenceString(from confidence: SnapshotConfidence) -> String {
        switch confidence {
        case .high:
            "high"
        case .moderate:
            "medium"
        case .low, .degraded:
            "low"
        }
    }
}
