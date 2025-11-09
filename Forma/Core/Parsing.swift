//
//  Parsing.swift
//  Forma
//
//  Purpose:
//  - Lightweight, UI-independent parser for task input.
//  - Avoids referencing view-layer types.
//
//  Created by Forma.
//

import Foundation

// MARK: - Output (UI-agnostic)

struct ParsedInput {
    var cleanTitle: String
    var when: Date?
    var importance: Importance
}

enum Importance: String, Codable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"
}

// MARK: - Rule-based Parser

enum RuleParser {
    /// Very small hybrid parser (rules + NSDataDetector).
    static func parse(_ text: String, base: Date = Date()) -> ParsedInput {
        var working = text

        // Importance keywords
        var importance: Importance = .normal
        func strip(_ needle: String) {
            working = working.replacingOccurrences(of: needle, with: "", options: [.caseInsensitive])
        }

        let lower = working.lowercased()
        if lower.contains("urgent") || lower.contains(" high") || lower.hasSuffix("!high") {
            importance = .high
            strip("urgent"); strip("high"); strip("!high")
        } else if lower.contains(" low") || lower.hasSuffix("!low") {
            importance = .low
            strip("low"); strip("!low")
        }

        // Date detection
        let cleaned = working.trimmingCharacters(in: .whitespacesAndNewlines) as NSString
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        var pickedDate: Date? = nil
        detector?.enumerateMatches(in: cleaned as String,
                                   options: [],
                                   range: NSRange(location: 0, length: cleaned.length)) { match, _, stop in
            if let d = match?.date { pickedDate = d; stop.pointee = true }
        }

        return ParsedInput(cleanTitle: cleaned as String, when: pickedDate, importance: importance)
    }
}
