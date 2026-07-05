import Foundation

struct StormSetupProfileAnalysisDTO: Codable, Sendable, Equatable {
    let request: Request?
    let response: Response
}

extension StormSetupProfileAnalysisDTO {
    struct Request: Codable, Sendable, Equatable {
        let runTime: Date?
        let validTime: Date?
        let forecastHour: Int?
    }

    struct Response: Codable, Sendable, Equatable {
        let mlcape: Double?
        let mucape: Double?
        let mlcin: Double?
        let mllclMetersAgl: Double?
        let scp: Double?
        let stpFixed: Double?
        let stpCin: Double?
        let ship: Double?
        let effectiveSrh: Double?
        let effectiveBulkShearMs: Double?
        let effectiveLayer: EffectiveLayer?
        let stormMotion: StormMotion?
        let quality: Quality?
    }

    struct EffectiveLayer: Codable, Sendable, Equatable {
        let status: String?
        let basePressureMb: Double?
        let topPressureMb: Double?
        let baseMetersAgl: Double?
        let topMetersAgl: Double?
    }

    struct StormMotion: Codable, Sendable, Equatable {
        let status: String?
        let bunkersRight: StormMotionVector?
        let uMs: Double?
        let vMs: Double?
        let speedMs: Double?
        let uKt: Double?
        let vKt: Double?
        let speedKt: Double?
        let directionTowardDeg: Double?
    }

    struct StormMotionVector: Codable, Sendable, Equatable {
        let uMs: Double?
        let vMs: Double?
        let speedMs: Double?
        let uKt: Double?
        let vKt: Double?
        let speedKt: Double?
        let directionTowardDeg: Double?
    }

    struct Quality: Codable, Sendable, Equatable {
        let profileLevelCount: Int?
        let warnings: [String]?
    }
}
