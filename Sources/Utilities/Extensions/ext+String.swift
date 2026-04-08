//
//  ext+String.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/5/25.
//

import Foundation

extension String {
    // MARK: String to date converters
    /// Parses SPC/NWS date strings like "202508052000" (UTC) into a Date
    func asUTCDate() -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        formatter.timeZone = .utc
        return formatter.date(from: self)
    }
    
    /// Parses an RFC1123 string into a Date
    func fromRFC1123String() -> Date? {
        rfcConvert(self, format: "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'")
    }
    
    func fromRFC822() -> Date? {
        rfcConvert(self, format: "EEE, dd MMM yyyy HH:mm:ss zzz")
    }
    
    /// Parses a 6 digit day and time into a valid date object based on the current date
    /// - Parameter issueDate: 121630 where 12 is the day of the month and 1630 is the time
    /// - Returns: valid date object in utc time
    public func parseSPCValidTime(relativeTo issueDate: Date = .now) -> Date? {
        guard self.count == 6 else { return nil }  // must be DDHHmm
        
        let dayStr = String(self.prefix(2))
        let timeStr = String(self.suffix(4))
        
        guard
            let day = Int(dayStr),
            let hour = Int(timeStr.prefix(2)),
            let minute = Int(timeStr.suffix(2))
        else { return nil }
        
        // Extract month and year from the issue date
        var comps = Calendar(identifier: .gregorian)
            .dateComponents(in: .utc, from: issueDate)
        
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        
        // Handle month rollover (e.g. issue on 31st, valid date = 01 next month)
        let calendar = Calendar(identifier: .gregorian)
        if let issueDay = calendar.dateComponents(in: .utc, from: issueDate).day,
           day < issueDay {
            comps.month = (comps.month ?? 1) + 1
        }
        
        return calendar.date(from: comps)
    }
    
    /// Converts a SPC issued string into a valid date object
    /// - Parameter text: string that looks like: 0651 PM CST Sat Nov 08 2025
    /// - Returns: Valid date object in UTC time
    public func parseAsIssuedDate() -> Date? {
        let tz: TimeZone = self.uppercased().contains("CDT")
            ? .init(abbreviation: "CDT")!
            : .init(abbreviation: "CST")!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = tz
        formatter.dateFormat = "hhmm a z EEE MMM dd yyyy"
        
        guard let localDate = formatter.date(from: self) else { return nil }

        // This returns the UTC somehow already?
        return localDate
    }
    
    /// Parse a single VTEC string into a VTECDescriptor.
    /// Returns nil if the string doesn't match the expected format.
    func parseVTEC() -> VTECDescriptor? {
//        guard let raw else { return nil }
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Strip leading/trailing "/" if present
        let core: String
        if trimmed.hasPrefix("/") && trimmed.hasSuffix("/") && trimmed.count >= 2 {
            core = String(trimmed.dropFirst().dropLast())
        } else {
            core = trimmed
        }

        // Expected format:
        // ACTION.STATUS.OFFICE.PHEN.SIG.EVENTNUM.BEGINTIME-ENDTIME
        // e.g. O.CON.KBOU.CW.Y.0001.260123T1000Z-260125T1600Z
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 7 else {
            // Unexpected format
            return nil
        }

        let action        = String(parts[0])  // "O"
        let status        = String(parts[1])  // "CON"
        let office        = String(parts[2])  // "KBOU"
        let phenomenon    = String(parts[3])  // "CW"
        let significance  = String(parts[4])  // "Y"
        let eventNumber   = String(parts[5])  // "0001"
        let timePart      = String(parts[6])  // "260123T1000Z-260125T1600Z" or "000000T0000Z-..."

        let timeParts = timePart.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard timeParts.count == 2 else {
            return nil
        }

        let beginToken = String(timeParts[0]) // "260123T1000Z" or "000000T0000Z"
        let endToken   = String(timeParts[1]) // "260125T1600Z"

        return VTECDescriptor(
            raw: trimmed,
            action: action,
            status: status,
            office: office,
            phenomenon: phenomenon,
            significance: significance,
            eventNumber: eventNumber,
            beginTimeToken: beginToken,
            endTimeToken: endToken
        )
    }
    
    // MARK: Helpers
    private func rfcConvert(_ date: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .utc // TimeZone(secondsFromGMT: 0)
        return formatter.date(from: date)
    }
}
