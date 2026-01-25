//
//  SpcParser.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/5/25.
//

import Foundation
import OSLog

final class RSSFeedParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    // MARK: - Properties
    private let logger = Logger.parsingRss
    private var feed: RSS?
    private var currentChannel: Channel?
    private var currentItem: Item?
    
    private var currentElement: String = ""
    private var currentText: String = "" // Accumulates text/CDATA for the current element
    
    // Flags to manage parsing context
    private var inChannel: Bool = false
    private var inItem: Bool = false
    private var inDescriptionContent: Bool = false // Tracks if we are inside a <description> tag
    
    // MARK: - Initialization & Parsing
    
    func parse(data: Data) throws -> RSS? {
        feed = RSS() // Initialize the top-level feed object
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        
        guard parser.parse() else {
            logger.error("XML Parsing failed: \(parser.parserError?.localizedDescription ?? "Unknown error", privacy: .public)")
            throw SpcError.parsingError
        }
        return feed
    }
    
    // MARK: - XMLParserDelegate Methods
    
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = "" // Reset text buffer for the new element
        
        if elementName == "channel" {
            inChannel = true
            currentChannel = Channel()
        } else if elementName == "item" {
            inItem = true
            currentItem = Item()
        } else if elementName == "description" {
            inDescriptionContent = true // Start accumulating all content for description
        } else if elementName == "guid" && inItem {
            currentItem?.guid = GUID(value: nil, isPermaLink: attributeDict["isPermaLink"])
        } else if elementName == "atom:link" && inChannel && !inItem { // Ensure it's channel's atom:link
            currentChannel?.atomLink?.href = attributeDict["href"]
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // Accumulate text only for elements whose content we care about
        // 'description' is a special case as it accumulates all text/CDATA
        let elementsToAccumulate = [
            "title", "link", "pubDate", "lastBuildDate", "rating", "docs", "ttl",
            "guid" // For GUID's text content
        ]
        
        if inDescriptionContent || elementsToAccumulate.contains(currentElement) {
            currentText += string
        }
    }
    
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if inDescriptionContent {
            if let cdataString = String(data: CDATABlock, encoding: .utf8) {
                let cleanDesc = extractPreText(from: cdataString) ?? cdataString
                currentText += cleanDesc
            }
        }
    }
    
    func extractPreText(from html: String) -> String? {
        guard let preStart = html.range(of: "<pre>"),
              let preEnd = html.range(of: "</pre>", range: preStart.upperBound..<html.endIndex) else {
            return nil
        }
        let preContent = html[preStart.upperBound..<preEnd.lowerBound]
        return preContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        // Trim current accumulated text. Apply consistently.
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle assignment based on context
        if inItem { // If we are inside an <item>
            assignItemProperty(elementName: elementName, text: trimmedText)
        } else if inChannel { // If we are inside <channel> but NOT an <item>
            assignChannelProperty(elementName: elementName, text: trimmedText)
        }
        
        // Reset flags and finalize objects for closing tags
        if elementName == "channel" {
            feed?.channel = currentChannel
            inChannel = false
            currentChannel = nil
        } else if elementName == "item" {
            // CRITICAL CHANGE: Append item to currentChannel's items array
            if let item = currentItem {
                currentChannel?.items.append(item)
            }
            inItem = false
            currentItem = nil
        } else if elementName == "description" {
            inDescriptionContent = false // Reset description content flag after assigning
        }
        
        currentText = "" // Clear buffer for the next element
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        logger.error("XML Parse Error: \(parseError.localizedDescription, privacy: .public)")
    }
    
    // MARK: - Private Assignment Helpers (Unchanged, as their internal logic was fine)
    
    private func assignChannelProperty(elementName: String, text: String) {
        switch elementName {
        case "title":         currentChannel?.title = text
        case "link":          currentChannel?.link = text
        case "description":   currentChannel?.description = text // This is the channel's description
        case "pubDate":       currentChannel?.pubDate = text
        case "lastBuildDate": currentChannel?.lastBuildDate = text
        case "rating":        currentChannel?.rating = text
        case "docs":          currentChannel?.docs = text
        case "ttl":           currentChannel?.ttl = text
        default: break
        }
    }
    
    private func assignItemProperty(elementName: String, text: String) {
        switch elementName {
        case "link":          currentItem?.link = text
        case "title":         currentItem?.title = text
        case "description":   currentItem?.description = text // This is the item's description
        case "pubDate":       currentItem?.pubDate = text
        case "guid":          currentItem?.guid?.value = text
        default: break
        }
    }
}
