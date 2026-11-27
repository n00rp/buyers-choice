import Foundation

enum SearchHit: Hashable, Identifiable {
    case address(Int)
    case street(Int)
    var id: String {
        switch self {
        case .address(let i): return "a\(i)"
        case .street(let i): return "s\(i)"
        }
    }
}

/// Samma sökning som portalen: gatunamn från ordets början och valfritt nummer.
enum AddressSearch {
    private static let pattern = try! NSRegularExpression(pattern: #"^(.*?[a-z])\s*(\d+\s?[a-z]?)?$"#)

    static func search(_ q: String, streets: [Street], addresses: [Address], limit: Int = 8) -> [SearchHit] {
        let f = Txt.fold(q)
        guard f.count >= 2 else { return [] }
        let ns = f as NSString
        guard let m = pattern.firstMatch(in: f, range: NSRange(location: 0, length: ns.length)) else { return [] }
        let sq = ns.substring(with: m.range(at: 1))
        let nq = m.range(at: 2).location == NSNotFound ? "" : ns.substring(with: m.range(at: 2)).replacingOccurrences(of: " ", with: "")

        var hits: [(Int, Int)] = []   // (rang, gata)
        for (i, st) in streets.enumerated() {
            guard let r = st.folded.range(of: sq) else { continue }
            if r.lowerBound == st.folded.startIndex {
                hits.append((0, i))
            } else if st.folded[st.folded.index(before: r.lowerBound)] == " " || st.folded.contains(" " + sq) {
                hits.append((1, i))
            }
        }
        hits.sort { x, y in
            let a = streets[x.1], b = streets[y.1]
            if x.0 != y.0 { return x.0 < y.0 }
            if a.folded.count != b.folded.count { return a.folded.count < b.folded.count }
            return a.folded < b.folded
        }

        var out: [SearchHit] = []
        if nq.isEmpty, hits.count > 1, streets[hits[0].1].folded != sq {
            for (_, si) in hits.prefix(limit) {
                let st = streets[si]
                out.append(st.count == 1 ? .address(st.first) : .street(si))
            }
            return out
        }
        for (_, si) in hits {
            let st = streets[si]
            for k in st.first..<(st.first + st.count) where out.count < limit {
                if !nq.isEmpty && !addresses[k].nr.hasPrefix(nq) { continue }
                out.append(.address(k))
            }
            if out.count >= limit { break }
        }
        return out
    }
}

/// Annonslänkar till Hemnet och Booli. Inget hämtas från annonsen, länken öppnas hos annonsören.
struct AdLink: Equatable {
    let url: URL
    let site: String

    static func parse(_ raw: String) -> AdLink? {
        var v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.hasPrefix("www.") { v = "https://" + v }
        guard let u = URL(string: v), u.scheme == "https", let host = u.host?.lowercased() else { return nil }
        let h = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        switch h {
        case "hemnet.se": return AdLink(url: u, site: "Hemnet")
        case "booli.se": return AdLink(url: u, site: "Booli")
        default: return nil
        }
    }

    static func looksLikeURL(_ v: String) -> Bool {
        v.range(of: #"^\s*(https?://|www\.)|\b(hemnet|booli)\.se\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static let knownBooli = ["3188597": "Vildkaprifolen 5"]

    /// Försöker läsa adressen ur länkens sista del, t.ex. "villa-5rum-torslanda-goteborg-kommun-vildkaprifolen-5-12345".
    @MainActor func address(in store: DataStore) -> Address? {
        if site == "Booli" {
            guard let r = url.path.range(of: #"\d{5,}"#, options: .regularExpression), let label = AdLink.knownBooli[String(url.path[r])] else { return nil }
            return store.address(key: label)
        }
        let seg = (url.path.split(separator: "/").last.map(String.init) ?? "").lowercased()
        let t = seg.split(separator: "-").map(String.init)
        guard t.count >= 3 else { return nil }
        var i = t.count - 2
        while i >= 1 {
            defer { i -= 1 }
            guard t[i].range(of: #"^\d+[a-z]?$"#, options: .regularExpression) != nil else { continue }
            var L = min(4, i)
            while L >= 1 {
                defer { L -= 1 }
                let key = Txt.fold(t[(i - L)..<i].joined(separator: " ")).replacingOccurrences(of: " ", with: "")
                guard let sis = store.streetMap[key] else { continue }
                let rest = t[(i + 1)...].joined(separator: " ") + " " + t[0..<(i - L)].joined(separator: " ")
                let hit = sis.filter { si in
                    let st = store.streets[si]
                    return rest.contains(Txt.fold(Kommun.all[st.kommun].namn)) || rest.contains(Txt.fold(st.postort))
                }
                for si in (hit.isEmpty ? sis : hit) {
                    let st = store.streets[si]
                    for k in st.first..<(st.first + st.count) where store.addresses[k].nr == t[i] {
                        return store.addresses[k]
                    }
                }
            }
        }
        return nil
    }
}
