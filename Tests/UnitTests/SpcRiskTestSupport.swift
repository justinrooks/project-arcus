import Testing
@testable import SkyAware
import SwiftData
import Foundation
import CoreLocation

struct MockClient: SpcClient {
    enum Mode {
        case success(Data)
        case failure(Error)
    }

    var mode: Mode

    func fetchRssData(for product: RssProduct) async throws -> Data {
        throw SpcError.missingRssData
    }

    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data {
        switch product {
        case .tornado:
            switch mode {
            case .success(let data):
                return data
            case .failure(let error):
                throw error
            }
        default:
            throw SpcError.missingGeoJsonData
        }
    }
}

struct CategoricalMockClient: SpcClient {
    let categoricalData: Data

    func fetchRssData(for product: RssProduct) async throws -> Data {
        throw SpcError.missingRssData
    }

    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data {
        guard product == .categorical else {
            throw SpcError.missingGeoJsonData
        }
        return categoricalData
    }
}
