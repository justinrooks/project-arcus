//
//  GeoJsonParser.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/30/25.
//

import Foundation
import OSLog

enum GeoJsonParser {
    /// Decodes the provided Data into a GeoJSONFeatureCollection DTO
    /// - Parameter data: data stream to decode
    /// - Returns: a populated GeoJSONFeatureCollection DTO, or empty if there's a decoding error
    @available(*, deprecated, message: "Use the Arcus instead")
    static func decode(from data: Data) -> GeoJSONFeatureCollection {
        let decoder = DecoderFactory.base
        let logger = Logger.parsingGeoJson
        do {
            return try decoder.decode(GeoJSONFeatureCollection.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            logger.error("GeoJSON decoding failed; returning an empty collection: Data corrupted – \(context.debugDescription, privacy: .public)")
            return .empty
        } catch let DecodingError.keyNotFound(key, context) {
            logger.error("GeoJSON decoding failed; returning an empty collection: Missing key '\(key.stringValue, privacy: .public)' – \(context.debugDescription, privacy: .public)")
            return .empty
        } catch let DecodingError.typeMismatch(type, context) {
            logger.error("GeoJSON decoding failed; returning an empty collection: Type mismatch for type '\(type, privacy: .public)' – \(context.debugDescription, privacy: .public)")
            return .empty
        } catch let DecodingError.valueNotFound(value, context) {
            logger.error("GeoJSON decoding failed; returning an empty collection: Missing value '\(value, privacy: .public)' – \(context.debugDescription, privacy: .public)")
            return .empty
        } catch {
            logger.error("Unexpected GeoJSON decode error; returning an empty collection: \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }
}
