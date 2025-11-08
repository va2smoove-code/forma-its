import Foundation

// What the UI needs after parsing
struct ParsedInput {
    var cleanTitle: String
    var when: Date?
    var importance: TodayView.Task.Importance
}

// Manual parser only (NSDataDetector + simple rules)
enum RuleParser {
    static func parse(_ text: String, base: Date = Date()) -> ParsedInput {
        // Importance
        var working = " \(text) "
        var importance: TodayView.Task.Importance = .normal
        func strip(_ k: String) { working = working.replacingOccurrences(of: " \(k) ", with: " ") }
        let lower = working.lowercased()
        if lower.contains(" !high ") || lower.contains(" urgent ") || lower.contains(" high ") {
            importance = .high; strip("!high"); strip("urgent"); strip("high")
        } else if lower.contains(" !low ") || lower.contains(" low ") {
            importance = .low; strip("!low"); strip("low")
        }
        var cleaned = working.trimmingCharacters(in: .whitespacesAndNewlines)

        // Dates/times via NSDataDetector
        let ns = cleaned as NSString
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        var pickedDate: Date? = nil
        let range = NSRange(location: 0, length: ns.length)
        detector?.enumerateMatches(in: cleaned, options: [], range: range) { match, _, _ in
            guard let m = match, let d = m.date else { return }
            if pickedDate == nil { pickedDate = d }
            if let r = Range(m.range, in: cleaned) { cleaned.removeSubrange(r) }
        }

        // Fallback words if detector missed
        if pickedDate == nil {
            let cal = Calendar.current
            let lowerC = cleaned.lowercased()
            func stripWord(_ w: String) { cleaned = cleaned.replacingOccurrences(of: w, with: "") }
            if lowerC.contains("today") {
                pickedDate = cal.startOfDay(for: base); stripWord("today")
            } else if lowerC.contains("tomorrow") {
                pickedDate = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: base))
                stripWord("tomorrow")
            } else {
                let pairs = zip(cal.weekdaySymbols, cal.shortWeekdaySymbols).map { ($0.0.lowercased(), $0.1.lowercased()) }
                func next(_ target: Int) -> Date {
                    let wd = cal.component(.weekday, from: base)
                    var delta = target - wd; if delta <= 0 { delta += 7 }
                    return cal.startOfDay(for: cal.date(byAdding: .day, value: delta, to: base)!)
                }
                for (i, (full, short)) in pairs.enumerated() {
                    if lowerC.contains(full) || lowerC.contains(" " + short) {
                        pickedDate = next(i + 1)
                        cleaned = cleaned.replacingOccurrences(of: full, with: "")
                        cleaned = cleaned.replacingOccurrences(of: " " + short, with: "")
                        break
                    }
                }
            }
        }

        let finalTitle = cleaned
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedInput(
            cleanTitle: finalTitle.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : finalTitle,
            when: pickedDate,
            importance: importance
        )
    }
}

// Convenience facade so the UI calls Parser.parse(...)
enum Parser {
    static func parse(_ text: String) -> ParsedInput { RuleParser.parse(text) }
}
