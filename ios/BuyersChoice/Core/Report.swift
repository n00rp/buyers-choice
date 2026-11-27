import Foundation

/// Texterna i grundrapporten, i samma ordalag som portalen. Neutral information med källa, inga betyg.
struct EnvTexts {
    var leq: String?
    var max: String?
    var leqLow: String?
    var maxLow: String?
    var no2: Double?
    var pm10: Double?
    var radon: String?
    var sky: String
    var flood: String
    var foro: String
    var flyg: String?
    var fm: String?
    var fg: String

    static let radonNames: [String: String] = [
        "normal_ra_berg_jord": "Normalriskområde, berg och jord",
        "lag_ra_i_lera_silt": "Lågriskområde, lera eller silt",
        "hog_ra_i _berggrund": "Högriskområde, höga radiumhalter i berggrunden",
        "normal_ra_goteborgsmoranen": "Normalriskområde, Göteborgsmoränen",
        "hog_ra_i_pegmatit": "Högriskområde, lokala pegmatitgångar",
        "hog_ra_i_moran": "Högriskområde, höga radiumhalter i morän",
    ]

    static func band(_ b: [Int]?, unit: String = "dBA") -> String? {
        guard let b, b.count == 2 else { return nil }
        let t = b[1] >= 100 ? "över \(b[0])" : b[0] == 0 ? "under \(b[1])" : "\(b[0])–\(b[1])"
        return t + " " + unit
    }

    init(meta m: EnvMeta, row r: EnvRow) {
        func pick(_ arr: [[Int]], _ i: Int?) -> [Int]? { i.flatMap { arr.indices.contains($0) ? arr[$0] : nil } }
        func d(_ v: Int?, inside: String, near: String, none: String?) -> String? {
            guard let v else { return none }
            return v == 0 ? inside : near.replacingOccurrences(of: "{d}", with: Txt.dist(v))
        }
        leq = EnvTexts.band(pick(m.leqBands, r.leq))
        max = EnvTexts.band(pick(m.maxBands, r.lmax))
        leqLow = EnvTexts.band(pick(m.leqBands, r.leqLow))
        maxLow = EnvTexts.band(pick(m.maxBands, r.lmaxLow))
        no2 = r.no2
        pm10 = r.pm10x10.map { $0 / 10 }
        if let i = r.radon, m.radon.indices.contains(i) { radon = EnvTexts.radonNames[m.radon[i]] ?? m.radon[i] }
        sky = d(r.skyfall, inside: "Adresspunkten ligger vid en skyfallsled.",
                near: "Adresspunkten ligger inte i en skyfallsled. Närmaste skyfallsled går ungefär {d} bort.",
                none: "Ingen skyfallsled inom 1 km.")!
        flood = d(r.flood, inside: "Adresspunkten ligger inom område med risk för översvämning och höga vattenstånd.",
                  near: "Närmaste riskområde för översvämning och höga vattenstånd ligger ungefär {d} bort.",
                  none: "Inget riskområde för översvämning inom 2 km.")!
        foro = d(r.foro, inside: "Adresspunkten ligger inom ett riskområde för förorenade områden.",
                 near: "Närmaste riskområde för förorenade områden ligger ungefär {d} bort.",
                 none: "Inget riskområde för förorenade områden inom 1 km.")!
        flyg = d(r.flyg, inside: "Adresspunkten ligger inom område med tillstånd för civilt flyg.",
                 near: "Område med tillstånd för civilt flyg ligger ungefär {d} bort.", none: nil)
        fm = d(r.fm, inside: "Adresspunkten ligger inom Försvarsmaktens påverkansområde för buller eller annan risk.",
               near: "Försvarsmaktens påverkansområde för buller ligger ungefär {d} bort.", none: nil)
        if let g = r.farligtGods {
            fg = "Transportled för farligt gods eller farlig verksamhet ligger ungefär \(Txt.dist(g)) bort." + (g <= 150 ? " Inom 150 m ska riskfrågor beaktas vid ny planläggning." : "")
        } else {
            fg = "Ingen transportled för farligt gods eller farlig verksamhet inom 500 m."
        }
    }
}

struct GeoText {
    let big: String
    let sub: String
    let text: String

    init?(_ g: GeoInfo?) {
        guard let g else { return nil }
        switch g {
        case let .covered(c, latest, earliest):
            big = c == 1 ? "1 utredning" : "\(c) utredningar"
            sub = latest.map { c == 1 ? "Från \($0)" : "Senaste från \($0)" } ?? "Täcker adresspunkten"
            var when = ""
            if let latest {
                if c == 1 { when = ", gjord \(latest)" } else { when = ", gjorda " + (earliest == nil || earliest == latest ? latest : "\(earliest!)–\(latest)") }
            }
            text = (c == 1 ? "En geoteknisk utredning" : "\(c) geotekniska utredningar") + " täcker adresspunkten\(when). Utredningarna beskriver jord, berg och stabilitet för ett område och görs oftast inför en detaljplan eller ett bygge. Kommunen lämnar ut dem på begäran."
        case let .nearest(m):
            if let m {
                big = Txt.dist(m); sub = "Till närmaste utredning"
                text = "Ingen geoteknisk utredning täcker adresspunkten. Närmaste utredning ligger ungefär \(Txt.dist(m)) bort."
            } else {
                big = "Ingen"; sub = "Inom 250 m"
                text = "Ingen geoteknisk utredning finns registrerad inom 250 m från adresspunkten."
            }
        }
    }
}

/// En rad under Planer i området: utpekat i översiktsplanen eller ett samhällsbyggnadsprojekt.
struct FutureItem: Identifiable {
    let id: String
    let feature: FutureFeature
    let m: Int
    let isProject: Bool

    var distanceText: String { m == 0 ? "Vid adressen" : Txt.dist(m) }

    static func list(row: EnvRow, data: FutureData, kommun K: Kommun) -> [FutureItem] {
        var items: [FutureItem] = []
        var seen = Set<String>()
        for (idx, (id, m)) in row.framtid.enumerated() {
            guard data.features.indices.contains(id) else { continue }
            let f = data.features[id]
            if K.has(.op) {
                let key = f.title + "|" + f.k
                if seen.contains(key) { continue }
                seen.insert(key)
            }
            items.append(FutureItem(id: "\(id)-\(idx)", feature: f, m: m, isProject: !K.has(.op)))
        }
        if !K.has(.op) { items.sort { $0.m < $1.m } }
        return items
    }

    /// Rader med rubrik och text för den utfällda vyn.
    func details(_ data: FutureData, kommun K: Kommun) -> [(String, String)] {
        let f = feature
        func ok(_ s: String) -> Bool { Txt.clean(s).count > 3 }
        if isProject {
            return [("Typ", f.k), ("Status", f.t), ("Tidsplan", f.b), ("Ansvarig", f.a.isEmpty ? "" : "Kommunens \(f.a)verksamhet"),
                    ("Avstånd", m == 0 ? "Vid adressen" : "\(Txt.dist(m)) från adresspunkten")].filter { !$0.1.isEmpty }
        }
        var rows: [(String, String)] = [
            ("Typ", [f.c, f.k, f.t != f.k ? f.t : ""].filter { !$0.isEmpty }.joined(separator: " · ")),
            ("Beskrivning", ok(f.b) ? f.b : ""),
            ("Översiktsplanen anger", ok(f.r) ? f.r : ""),
            ("Utredningsläge", ok(f.u) ? f.u : ""),
            ("Om kategorin", ok(f.gb) ? f.gb : ""),
            ("Avstånd", m == 0 ? "Vid adressen" : "\(Txt.dist(m)) från adresspunkten"),
            ("Beslut", "Översiktsplan för Göteborg, \(Txt.lowerFirst(data.beslut ?? "Antagen av kommunfullmäktige 2022-05-19")). Översiktsplanen är vägledande och inte juridiskt bindande."),
            ("Ansvarig", Txt.capitalizedFirst(f.a)),
        ].filter { !$0.1.isEmpty }
        let chapters = f.links.filter { $0.1.isEmpty }.map { Txt.capitalizedFirst(Txt.clean($0.0).replacingOccurrences(of: #"^Läs mer\s+(om\s+)?"#, with: "", options: [.regularExpression, .caseInsensitive])) }
        if !chapters.isEmpty { rows.append(("Läs mer i planen", chapters.joined(separator: ". "))) }
        return rows.map { ($0.0, Txt.clean($0.1)) }
    }

    var summary: String {
        let f = feature
        if isProject { return [f.t, f.b].filter { !$0.isEmpty }.joined(separator: ". ") }
        let sub = [f.n.isEmpty ? "" : f.k, f.t != f.k ? f.t : ""].filter { !$0.isEmpty }.joined(separator: " · ")
        let txt = Txt.clean(Txt.clean(f.b).count > 3 ? f.b : f.r)
        return (sub.isEmpty ? "" : sub + ". ") + Txt.shorten(txt, to: 200)
    }

    var links: [(String, URL)] { feature.links.compactMap { l in URL(string: l.1).flatMap { $0.scheme == "https" ? (Txt.clean(l.0), $0) : nil } } }
}

/// Pågående planarbete nära adressen (Göteborgs projektdatabas).
struct PlanWorkItem: Identifiable {
    static let steps = ["tidigt", "samrad", "granskning", "antagande", "lagakraft", "bygge"]
    static let short = ["tidigt": "Tidigt skede", "samrad": "Samråd", "granskning": "Granskning", "antagande": "Antagande", "lagakraft": "Laga kraft", "bygge": "Byggs"]
    static let shown: Set<String> = Set(steps + ["overklagad", "pausad", "okand"])
    static let radius = 1500

    let work: PlanWork
    let m: Int
    var id: String { work.id }

    /// Steg 0–5 för stapeln, eller nil om skedet inte ingår i stegen.
    var stepIndex: Int? { PlanWorkItem.steps.firstIndex(of: work.fas == "overklagad" ? "antagande" : work.fas) }

    var isBuilding: Bool { work.fas == "bygge" || work.fas == "lagakraft" }

    static func near(_ a: Address, data: PlanWorkData?) -> [PlanWorkItem] {
        guard let data else { return [] }
        return data.items.compactMap { w in
            let m = Int(hypot(w.e - a.e, w.n - a.n).rounded())
            return m <= radius && shown.contains(w.fas) ? PlanWorkItem(work: w, m: m) : nil
        }.sorted { $0.m < $1.m }
    }

    struct Synpunkter { let open: Bool; let past: Bool; let text: String }

    func synpunkter(today: Date = Date()) -> Synpunkter? {
        guard let f = Txt.ymd(work.syn.0), let t = Txt.ymd(work.syn.1) else { return nil }
        let cal = Calendar(identifier: .gregorian)
        let d = cal.startOfDay(for: today)
        let differentYear = cal.component(.year, from: f) != cal.component(.year, from: t)
        let span = "\(Txt.date(f, year: differentYear))–\(Txt.date(t, year: true))"
        if d > t { return Synpunkter(open: false, past: true, text: "Synpunkter kunde lämnas \(span).") }
        if d >= f { return Synpunkter(open: true, past: false, text: "Det går att lämna synpunkter till och med \(Txt.date(t, year: true)).") }
        return Synpunkter(open: false, past: false, text: "Det går att lämna synpunkter \(span).")
    }

    /// Projektnamnet utan stadsdelen först, t.ex. "Amhult - Bostäder" blir "bostäder".
    var shortName: String {
        let s = work.namn.replacingOccurrences(of: #"^[^–-]+\s[–-]\s"#, with: "", options: .regularExpression)
        return Txt.lowerFirst(s)
    }
}

/// Frågor till visningen, utifrån planerna, miljön och området.
struct Question: Identifiable {
    let id: String
    let text: String
    let detail: String

    @MainActor
    static func build(address a: Address, store: DataStore, plans pl: [PlanInfo], meta m: EnvMeta?, row r: EnvRow?,
                      future: [FutureItem], work: [PlanWorkItem]) -> [Question] {
        var Q: [Question] = []
        let K = store.kommun(a)
        let main = pl.first { $0.group == .plan }
        if let main {
            Q.append(.init(id: "plan", text: "Vad tillåter \(main.typ.lowercased()) \(main.bet) på tomten?", detail: "Till exempel byggrätt, våningar och prickmark. Det står i plankartan."))
        } else {
            Q.append(.init(id: "plan", text: "Hur prövas bygglov här när det saknas detaljplan?", detail: "Fråga \(K.has(.miljo) ? "stadsbyggnadskontoret" : "kommunen") vad som gäller för platsen."))
        }
        if pl.contains(where: { $0.group == .fast }) {
            Q.append(.init(id: "fast", text: "Gäller tomtindelningen eller fastighetsplanen fortfarande?", detail: "Äldre fastighetsindelning kan påverka möjligheten att stycka av."))
        }
        Q.append(.init(id: "serv", text: "Finns servitut eller ledningsrätter på fastigheten?", detail: "Uppgifterna finns hos Lantmäteriet och mäklaren."))
        Q.append(.init(id: "tax", text: "Vilket taxeringsvärde och värdeår har fastigheten?", detail: "Behövs för att räkna ut fastighetsavgiften."))
        var t: EnvTexts?
        if let m, let r {
            t = EnvTexts(meta: m, row: r)
            if let i = r.leq, m.leqBands.indices.contains(i), m.leqBands[i].first ?? 0 >= 55, let leq = t?.leq {
                Q.append(.init(id: "buller", text: "Hur hörs trafiken inomhus och på uteplatsen?", detail: "Beräknad nivå nära huset: \(leq) mot gatan\(t?.leqLow.map { ", \($0) på lugnaste sidan" } ?? "")."))
            }
            if let s = r.skyfall, s <= 150 {
                Q.append(.init(id: "sky", text: "Har det samlats vatten på tomten eller i källaren vid kraftiga regn?", detail: "Närmaste skyfallsled: \(s == 0 ? "vid adressen" : Txt.dist(s))."))
            }
            if let s = r.flood, s <= 500 {
                Q.append(.init(id: "flood", text: "Vad gäller för höga vattenstånd och försäkring?", detail: "Riskområde för översvämning: \(s == 0 ? "vid adressen" : Txt.dist(s))."))
            }
            if let s = r.foro, s <= 300 {
                Q.append(.init(id: "foro", text: "Finns kända markföroreningar på eller nära fastigheten?", detail: "Riskområde för förorenade områden: \(s == 0 ? "vid adressen" : Txt.dist(s))."))
            }
        }
        if K.has(.stops), let s0 = store.nearby(store.service(a).stops, to: a, limit: 1).first {
            let L = store.service(a).lines
            var names: [String] = []
            for i in s0.place.lines where L.indices.contains(i) && !names.contains(L[i].name) { names.append(L[i].name) }
            Q.append(.init(id: "kollektiv", text: "Hur ofta går \(names.isEmpty ? "bussarna" : "linjerna") från \(s0.place.name), och hur fungerar det i rusningstid?",
                           detail: "Närmaste hållplats, \(Txt.dist(s0.m)) bort\(names.isEmpty ? "" : ". Linjer som passerar: " + names.joined(separator: ", "))."))
        }
        Q.append(.init(id: "radon", text: "Finns en radonmätning, och när gjordes den?", detail: t?.radon.map { "Markradon enligt översiktsplanen: \($0.lowercased())." } ?? ""))
        if let r, case let .covered(c, latest, _)? = r.geo {
            Q.append(.init(id: "geo", text: "Vad visar den geotekniska utredningen för området?", detail: "\(c == 1 ? "En utredning" : "\(c) utredningar") täcker adresspunkten\(latest.map { ", den senaste från \($0)" } ?? ""). Kommunen lämnar ut dem."))
        }
        if let g = r?.farligtGods, g <= 150 {
            Q.append(.init(id: "fg", text: "Vad transporteras på den närliggande leden för farligt gods?", detail: "Avstånd: \(Txt.dist(g))."))
        }
        for (i, x) in work.filter({ $0.m <= 1000 && !$0.isBuilding }).prefix(2).enumerated() {
            let sy = x.synpunkter()
            let fas = (PlanWorkItem.short[x.work.fas] ?? "okänt skede").lowercased()
            Q.append(.init(id: "pa\(i)", text: "Vet säljaren något om planarbetet \(x.shortName)?",
                           detail: "\(x.work.slag), \(fas), \(Txt.dist(x.m)) bort.\(sy.map { $0.past ? "" : " " + $0.text } ?? "")"))
        }
        if let x = work.first(where: { $0.m <= 500 && $0.isBuilding }) {
            Q.append(.init(id: "pab", text: "När väntas bygget av \(x.shortName) vara klart, och hur påverkar det trafik och utsikt?",
                           detail: "\(PlanWorkItem.short[x.work.fas] ?? ""), \(Txt.dist(x.m)) bort."))
        }
        for (i, x) in future.filter({ $0.m <= 1000 }).prefix(2).enumerated() {
            let f = x.feature
            Q.append(.init(id: "fut\(i)", text: "Vet säljaren något om \(f.n.isEmpty ? f.k.lowercased() : f.n)?",
                           detail: "\(x.isProject ? "Samhällsbyggnadsprojekt hos kommunen" : "Utpekat i översiktsplanen"), \(x.m == 0 ? "vid adressen" : Txt.dist(x.m)) bort."))
        }
        return Q
    }
}

extension Txt {
    static func lowerFirst(_ s: String) -> String {
        guard let f = s.first else { return s }
        return f.lowercased() + s.dropFirst()
    }
}
