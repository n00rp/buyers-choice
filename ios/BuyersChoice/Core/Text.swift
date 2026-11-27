import Foundation

/// Textfunktioner som motsvarar portalens (fold, fmtD, prettyName m.fl.), så att sökning och texter blir lika.
enum Txt {
    /// Gemener utan å, ä, ö och skiljetecken, för sökning.
    static func fold(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s.lowercased() {
            switch ch {
            case "å", "ä", "à": out.append("a")
            case "ö": out.append("o")
            case "é", "è": out.append("e")
            case "ü": out.append("u")
            default:
                if ch.isASCII, ch.isLetter || ch.isNumber || ch == " " { out.append(ch) } else { out.append(" ") }
            }
        }
        return out.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    /// Avstånd i meter som "350 m" eller "1,2 km".
    static func dist(_ m: Int) -> String {
        if m < 1000 { return "\(m) m" }
        return String(format: "%.1f km", Double(m) / 1000).replacingOccurrences(of: ".", with: ",")
    }

    /// Tal med mellanslag som tusentalsavgränsare.
    static func num(_ n: Int) -> String {
        let s = String(n)
        var out = ""
        for (i, ch) in s.enumerated() {
            if i > 0, (s.count - i) % 3 == 0 { out.append(" ") }
            out.append(ch)
        }
        return out
    }

    static func decimal(_ d: Double) -> String {
        let s = d == d.rounded() ? String(Int(d)) : String(d)
        return s.replacingOccurrences(of: ".", with: ",")
    }

    private static let smallWords: Set<String> = ["i", "och", "vid", "för", "på", "av", "med", "till", "m", "fl", "om", "inom", "samt", "del", "mm", "nr"]

    /// Plannamn i registret är ofta skrivna med versaler. Gör om dem till vanlig skrift.
    static func prettyName(_ raw: String?) -> String {
        var s = (raw ?? "").trimmingCharacters(in: .whitespaces)
        if let r = s.range(of: #"^\s*\d+\s*[-–]\s*"#, options: .regularExpression) { s.removeSubrange(r) }
        s = s.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return "" }
        if s == s.uppercased() {
            let lower = s.lowercased()
            var result = ""
            var first = true
            var token = ""
            func flush() {
                guard !token.isEmpty else { return }
                let bare = token.filter { $0.isLetter }
                if !first && smallWords.contains(bare) { result += token } else { result += token.prefix(1).uppercased() + token.dropFirst() }
                first = false
                token = ""
            }
            for ch in lower {
                if ch.isWhitespace { flush(); result.append(ch) } else { token.append(ch) }
            }
            flush()
            s = result
        }
        return s
    }

    static func capitalizedFirst(_ s: String) -> String {
        guard let f = s.first else { return s }
        return f.uppercased() + s.dropFirst()
    }

    static func clean(_ s: String?) -> String {
        (s ?? "").replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    static func shorten(_ s: String, to n: Int) -> String {
        guard s.count > n else { return s }
        var cut = String(s.prefix(n - 3))
        if let sp = cut.lastIndex(of: " ") { cut = String(cut[..<sp]) }
        return cut + " …"
    }

    private static let months = ["januari", "februari", "mars", "april", "maj", "juni", "juli", "augusti", "september", "oktober", "november", "december"]

    /// "20261127" till ett datum.
    static func ymd(_ s: String?) -> Date? {
        guard let s, s.count >= 8, let y = Int(s.prefix(4)), let m = Int(s.dropFirst(4).prefix(2)), let d = Int(s.dropFirst(6).prefix(2)) else { return nil }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: d))
    }

    static func date(_ d: Date, year: Bool) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: d)
        return "\(c.day ?? 1) \(months[(c.month ?? 1) - 1])" + (year ? " \(c.year ?? 0)" : "")
    }
}
