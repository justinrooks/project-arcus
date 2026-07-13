import ArcusCore
import Foundation

protocol AirQualityQuerying: Sendable {
    func fetchCurrentAirQuality(h3Cell: Int64) async throws -> AirQualityCurrentResponse?
}
