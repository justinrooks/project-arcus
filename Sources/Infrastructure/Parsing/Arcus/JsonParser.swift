//
//  JsonParser.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation
import OSLog

enum JsonParser {
    /// Decodes the provided Data into a GeoJSONFeatureCollection DTO
    /// - Parameter data: data stream to decode
    /// - Returns: a populated GeoJSONFeatureCollection DTO, or empty if there's a decoding error
    static func decode<T: Decodable>(from data: Data) -> T? {
        let decoder = DecoderFactory.iso8601
        let logger = Logger.parsingJson
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            logger.error("JSON decoding failed: Data corrupted – \(context.debugDescription, privacy: .public)")
            return nil
        } catch let DecodingError.keyNotFound(key, context) {
            logger.error("JSON decoding failed: Missing key '\(key.stringValue, privacy: .public)' – \(context.debugDescription, privacy: .public)")
            return nil
        } catch let DecodingError.typeMismatch(type, context) {
            logger.error("JSON decoding failed: Type mismatch for type '\(type, privacy: .public)' – \(context.debugDescription, privacy: .public)")
            return nil
        } catch let DecodingError.valueNotFound(value, context) {
            logger.error("JSON decoding failed: Missing value '\(value, privacy: .public)' – \(context.debugDescription, privacy: .public)")
            return nil
        } catch {
            logger.error("Unexpected JSON decode error: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
