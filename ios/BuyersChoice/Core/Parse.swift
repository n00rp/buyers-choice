import Foundation

/// Läser portalens kompakta JSON-format. Filerna är listor av listor för att hållas små,
/// så de läses med JSONSerialization och plockas isär här.
enum Parse {
    static func json(_ data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    static func int(_ v: Any?) -> Int? {
        guard let v, !(v is NSNull) else { return nil }
        if let i = v as? Int { return i }
        if let d = v as? Double { return Int(d.rounded()) }
        return nil
    }

    static func double(_ v: Any?) -> Double? {
        guard let v, !(v is NSNull) else { return nil }
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        return nil
    }

    static func str(_ v: Any?) -> String? {
        guard let v, !(v is NSNull) else { return nil }
        if let s = v as? String { return s }
        if let i = v as? Int { return String(i) }
        return nil
    }

    static func at(_ a: [Any], _ i: Int) -> Any? { i < a.count ? a[i] : nil }

    /// Index -1 betyder att uppgift saknas i miljöfilerna.
    static func index(_ v: Any?) -> Int? {
        guard let i = int(v), i >= 0 else { return nil }
        return i
    }

    // MARK: Adresser

    struct KommunData {
        let base: Int
        let count: Int
        let pfx: String
        let plans: [PlanRecord]
        let service: Service
    }

    struct Dataset {
        let addresses: [Address]
        let streets: [Street]
        let streetMap: [String: [Int]]
        let kommuner: [KommunData]
    }

    static func dataset(files: [(adresser: Data, planer: Data, service: Data)]) throws -> Dataset {
        var addresses: [Address] = []
        addresses.reserveCapacity(120_000)
        var streets: [Street] = []
        var streetMap: [String: [Int]] = [:]
        var kommuner: [KommunData] = []

        for (km, f) in files.enumerated() {
            let K = Kommun.all[km]
            guard let a = try json(f.adresser) as? [String: Any],
                  let o = a["o"] as? [Any], let e0 = double(at(o, 0)), let n0 = double(at(o, 1)),
                  let s = a["s"] as? [Any] else { throw DataError.format("adresser.json") }
            let base = addresses.count
            for item in s {
                guard let st = item as? [Any], let name = str(at(st, 0)), let rows = at(st, 1) as? [Any] else { continue }
                let po = str(at(st, 2)) ?? K.namn
                let first = addresses.count
                let si = streets.count
                for rowAny in rows {
                    guard let r = rowAny as? [Any], r.count >= 3 else { continue }
                    let nrRaw = str(r[0]) ?? ""
                    let plans = r.count > 3 ? r[3...].compactMap { int($0) } : []
                    addresses.append(Address(
                        id: addresses.count,
                        label: nrRaw.isEmpty ? name : "\(name) \(nrRaw)",
                        street: si, kommun: km, local: addresses.count - base,
                        nr: Txt.fold(nrRaw).replacingOccurrences(of: " ", with: ""),
                        e: (double(r[1]) ?? 0) + e0, n: (double(r[2]) ?? 0) + n0,
                        plans: plans))
                }
                let folded = Txt.fold(name)
                streets.append(Street(name: name, folded: folded, first: first, count: addresses.count - first, kommun: km, postort: po))
                streetMap[folded.replacingOccurrences(of: " ", with: ""), default: []].append(si)
            }

            guard let p = try json(f.planer) as? [String: Any], let pl = p["p"] as? [Any] else { throw DataError.format("planer.json") }
            let plans: [PlanRecord] = pl.map { any in
                let r = any as? [Any] ?? []
                return PlanRecord(bet: str(at(r, 0)) ?? "", typ: str(at(r, 1)) ?? "", name: str(at(r, 2)) ?? "",
                                  url: str(at(r, 3)) ?? "", besk: str(at(r, 4)) ?? "", lk: str(at(r, 5)) ?? "")
            }
            let service = try parseService(f.service)
            kommuner.append(KommunData(base: base, count: addresses.count - base, pfx: p["pfx"] as? String ?? "", plans: plans, service: service))
        }
        return Dataset(addresses: addresses, streets: streets, streetMap: streetMap, kommuner: kommuner)
    }

    static func parseService(_ data: Data) throws -> Service {
        guard let s = try json(data) as? [String: Any] else { throw DataError.format("service.json") }
        func rows(_ k: String) -> [[Any]] { (s[k] as? [Any] ?? []).compactMap { $0 as? [Any] } }
        func base(_ r: [Any], _ kind: Place.Kind, _ i: Int) -> Place {
            Place(id: "\(kind)-\(i)", kind: kind, name: str(at(r, 0)) ?? "", e: double(at(r, 1)) ?? 0, n: double(at(r, 2)) ?? 0)
        }
        var out = Service()
        out.stops = rows("stops").enumerated().map { i, r in
            var p = base(r, .stop, i)
            p.lines = (at(r, 3) as? [Any] ?? []).compactMap { int($0) }
            return p
        }
        out.schools = rows("schools").enumerated().map { i, r in
            var p = base(r, .school, i)
            p.level = str(at(r, 3)) ?? ""
            p.grades = str(at(r, 4)) ?? ""
            p.address = str(at(r, 5)) ?? ""
            p.code = str(at(r, 6)) ?? ""
            p.kommunName = str(at(r, 8)) ?? ""
            return p
        }
        out.preschools = rows("pre").enumerated().map { i, r in
            var p = base(r, .preschool, i)
            p.address = str(at(r, 3)) ?? ""
            p.code = str(at(r, 4)) ?? ""
            p.subtype = str(at(r, 5)) ?? ""
            p.kommunName = str(at(r, 6)) ?? ""
            return p
        }
        out.shops = rows("shops").enumerated().map { i, r in
            var p = base(r, .shop, i)
            p.address = str(at(r, 3)) ?? ""
            return p
        }
        out.pharmacies = rows("pharm").enumerated().map { i, r in
            var p = base(r, .pharmacy, i)
            p.address = str(at(r, 3)) ?? ""
            return p
        }
        out.lines = rows("lines").map { Line(name: str(at($0, 0)) ?? "", type: str(at($0, 1)) ?? "", desc: str(at($0, 2)) ?? "") }
        return out
    }

    // MARK: Miljö

    static func envMeta(_ data: Data) throws -> EnvMeta {
        guard let m = try json(data) as? [String: Any] else { throw DataError.format("miljo-meta.json") }
        func bands(_ k: String) -> [[Int]] { (m[k] as? [Any] ?? []).map { ($0 as? [Any] ?? []).compactMap { int($0) } } }
        return EnvMeta(leqBands: bands("leqb"), maxBands: bands("maxb"),
                       radon: (m["radon"] as? [Any] ?? []).compactMap { str($0) }, block: int(m["block"]) ?? 5000)
    }

    static func envRow(_ any: Any?) -> EnvRow {
        let r = any as? [Any] ?? []
        var e = EnvRow()
        e.leq = index(at(r, 0))
        e.lmax = index(at(r, 1))
        e.no2 = double(at(r, 2))
        e.pm10x10 = double(at(r, 3))
        e.radon = index(at(r, 4))
        e.skyfall = int(at(r, 5))
        e.flood = int(at(r, 6))
        e.foro = int(at(r, 7))
        e.flyg = int(at(r, 8))
        e.fm = int(at(r, 9))
        e.farligtGods = int(at(r, 10))
        let ids = (at(r, 11) as? [Any] ?? []).compactMap { int($0) }
        var fr: [(Int, Int)] = []
        var i = 0
        while i + 1 < ids.count { fr.append((ids[i], ids[i + 1])); i += 2 }
        e.framtid = fr.map { (id: $0.0, m: $0.1) }
        e.fastighet = str(at(r, 12))
        e.area = int(at(r, 13))
        e.leqLow = index(at(r, 14))
        e.lmaxLow = index(at(r, 15))
        if let g = at(r, 16) as? [Any], let c = int(at(g, 0)) {
            e.geo = c > 0 ? .covered(count: c, latest: str(at(g, 1)), earliest: str(at(g, 2))) : .nearest(int(at(g, 1)))
        }
        return e
    }

    // MARK: Framtid

    static func future(_ data: Data) throws -> FutureData {
        guard let d = try json(data) as? [String: Any] else { throw DataError.format("framtid.json") }
        let feats: [FutureFeature] = (d["f"] as? [Any] ?? []).map { any in
            let f = any as? [String: Any] ?? [:]
            let links: [(String, String)] = (f["lk"] as? [Any] ?? []).compactMap {
                guard let l = $0 as? [Any] else { return nil }
                return (str(at(l, 0)) ?? "", str(at(l, 1)) ?? "")
            }
            return FutureFeature(n: str(f["n"]) ?? "", k: str(f["k"]) ?? "", t: str(f["t"]) ?? "", r: str(f["r"]) ?? "",
                                 b: str(f["b"]) ?? "", u: str(f["u"]) ?? "", gb: str(f["gb"]) ?? "", c: str(f["c"]) ?? "",
                                 a: str(f["a"]) ?? "", links: links, geometry: geometry(f["g"]))
        }
        return FutureData(src: str(d["src"]) ?? "", url: str(d["url"]), beslut: str(d["beslut"]), features: feats)
    }

    static func geometry(_ any: Any?) -> Geometry? {
        guard let g = any as? [String: Any], let type = g["type"] as? String, let c = g["coordinates"] else { return nil }
        func pt(_ v: Any) -> [Double] { (v as? [Any] ?? []).compactMap { double($0) } }
        func line(_ v: Any) -> [[Double]] { (v as? [Any] ?? []).map(pt) }
        func poly(_ v: Any) -> [[[Double]]] { (v as? [Any] ?? []).map(line) }
        switch type {
        case "Point": return .point(pt(c))
        case "LineString": return .line(line(c))
        case "MultiLineString": return .multiLine(poly(c))
        case "Polygon": return .polygon(poly(c))
        case "MultiPolygon": return .multiPolygon((c as? [Any] ?? []).map(poly))
        default: return nil
        }
    }

    // MARK: Planarbete

    static func planWork(_ data: Data) throws -> PlanWorkData {
        guard let d = try json(data) as? [String: Any], let kol = d["kol"] as? [String] else { throw DataError.format("planarbete.json") }
        let c = Dictionary(uniqueKeysWithValues: kol.enumerated().map { ($1, $0) })
        func v(_ r: [Any], _ k: String) -> Any? { c[k].flatMap { at(r, $0) } }
        let items: [PlanWork] = (d["p"] as? [Any] ?? []).compactMap { any in
            guard let r = any as? [Any] else { return nil }
            let syn = v(r, "synpunkter") as? [Any]
            return PlanWork(namn: str(v(r, "namn")) ?? "", slag: str(v(r, "slag")) ?? "", steg: str(v(r, "steg")) ?? "",
                            fas: str(v(r, "fas")) ?? "okand", e: double(v(r, "x")) ?? 0, n: double(v(r, "y")) ?? 0,
                            lank: str(v(r, "lank")).flatMap(URL.init(string:)),
                            syn: (syn.flatMap { str(at($0, 0)) }, syn.flatMap { str(at($0, 1)) }),
                            ungefar: (int(v(r, "ungefar")) ?? 0) != 0 || (v(r, "ungefar") as? Bool ?? false))
        }
        let phases = (d["faser"] as? [String: Any] ?? [:]).compactMapValues { $0 as? String }
        return PlanWorkData(updated: str(d["uppdaterad"]), phases: phases, items: items)
    }
}

enum DataError: LocalizedError {
    case format(String)
    case http(String, Int)

    var errorDescription: String? {
        switch self {
        case .format(let f): return "Filen \(f) har ett okänt format."
        case .http(let f, let code): return "Filen \(f) kunde inte hämtas (\(code))."
        }
    }
}
