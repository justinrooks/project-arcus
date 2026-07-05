import Foundation
import Testing
@testable import SkyAware

@Suite("Storm Setup Profile Analysis DTO")
struct StormSetupProfileAnalysisDTOTests {
    @Test("rich payload decodes the required response contract and request identity")
    func richPayloadDecodesTheRequiredResponseContractAndRequestIdentity() throws {
        let dto = try decodeDTO(StormSetupProfileAnalysisTestFixtures.richJSON)

        #expect(dto.request?.runTime == iso("2026-06-01T18:00:00Z"))
        #expect(dto.request?.validTime == iso("2026-06-01T21:00:00Z"))
        #expect(dto.request?.forecastHour == 3)
        #expect(dto.response.mlcape == 1_850)
        #expect(dto.response.mucape == 2_200.5)
        #expect(dto.response.mlcin == -42)

        let negativeZero = try #require(dto.response.mllclMetersAgl)
        #expect(negativeZero == 0)
        #expect(negativeZero.sign == .minus)

        #expect(dto.response.scp == 0.7e0)
        #expect(dto.response.stpFixed == 1.2)
        #expect(dto.response.stpCin == 0.9)
        #expect(dto.response.ship == 2.1)
        #expect(dto.response.effectiveSrh == 1.35e2)
        #expect(dto.response.effectiveBulkShearMs == 2.45e1)
        #expect(dto.response.effectiveLayer?.status == "available")
        #expect(dto.response.effectiveLayer?.basePressureMb == 9.15e2)
        #expect(dto.response.effectiveLayer?.topPressureMb == 7.5e2)
        #expect(dto.response.effectiveLayer?.baseMetersAgl == 8.5e2)
        #expect(dto.response.effectiveLayer?.topMetersAgl == 1.8e3)
        #expect(dto.response.stormMotion?.status == "available")
        #expect(dto.response.stormMotion?.bunkersRight?.uMs == 8.4)
        #expect(dto.response.stormMotion?.bunkersRight?.vMs == -4.2)
        #expect(dto.response.stormMotion?.bunkersRight?.speedMs == 9.4)
        #expect(dto.response.stormMotion?.bunkersRight?.uKt == 16.3)
        #expect(dto.response.stormMotion?.bunkersRight?.vKt == -8.2)
        #expect(dto.response.stormMotion?.bunkersRight?.speedKt == 18.3)
        #expect(dto.response.stormMotion?.bunkersRight?.directionTowardDeg == 215)
        #expect(dto.response.stormMotion?.uMs == 6.2)
        #expect(dto.response.stormMotion?.vMs == -2.4)
        #expect(dto.response.stormMotion?.speedMs == 6.6)
        #expect(dto.response.stormMotion?.uKt == 12.1)
        #expect(dto.response.stormMotion?.vKt == -4.7)
        #expect(dto.response.stormMotion?.speedKt == 12.8)
        #expect(dto.response.stormMotion?.directionTowardDeg == 201)
        #expect(dto.response.quality?.profileLevelCount == 36)
        #expect(dto.response.quality?.warnings == [
            "profile trimmed",
            "debug ignored"
        ])

        let encoded = try JSONEncoder().encode(dto)
        let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let request = try #require(json["request"] as? [String: Any])

        #expect(request["profile"] == nil)
        #expect(request["location"] == nil)
        #expect(request["debug"] == nil)
        #expect(json["debug"] == nil)
    }

    @Test("sparse payload tolerates missing optional response fields")
    func sparsePayloadToleratesMissingOptionalResponseFields() throws {
        let dto = try decodeDTO(StormSetupProfileAnalysisTestFixtures.sparseJSON)

        #expect(dto.request?.runTime == nil)
        #expect(dto.request?.validTime == nil)
        #expect(dto.request?.forecastHour == nil)
        #expect(dto.response.mlcape == nil)
        #expect(dto.response.mucape == nil)
        #expect(dto.response.mlcin == nil)
        #expect(dto.response.mllclMetersAgl == nil)
        #expect(dto.response.scp == nil)
        #expect(dto.response.stpFixed == nil)
        #expect(dto.response.stpCin == nil)
        #expect(dto.response.ship == nil)
        #expect(dto.response.effectiveSrh == nil)
        #expect(dto.response.effectiveBulkShearMs == nil)
        #expect(dto.response.effectiveLayer?.status == "notFound")
        #expect(dto.response.effectiveLayer?.basePressureMb == nil)
        #expect(dto.response.effectiveLayer?.topPressureMb == nil)
        #expect(dto.response.effectiveLayer?.baseMetersAgl == nil)
        #expect(dto.response.effectiveLayer?.topMetersAgl == nil)
        #expect(dto.response.stormMotion == nil)
        #expect(dto.response.quality == nil)
    }
}

private func decodeDTO(_ json: String) throws -> StormSetupProfileAnalysisDTO {
    try DecoderFactory.iso8601.decode(StormSetupProfileAnalysisDTO.self, from: Data(json.utf8))
}

private func iso(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)!
}
