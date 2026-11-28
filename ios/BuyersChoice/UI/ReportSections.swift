import SwiftUI

// MARK: - Översikt

struct OverviewSection: View {
    let model: ReportModel
    let plans: [PlanInfo]
    @Environment(DataStore.self) private var store

    var body: some View {
        let a = model.address
        let K = store.kommun(a)
        let S = store.service(a)
        let main = plans.first { $0.group == .plan }
        let stops = store.nearby(S.stops, to: a, limit: 6)
        let schools = store.nearby(S.schools, to: a, limit: 1) { $0.level == "gr" }
        let pre = store.nearby(S.preschools, to: a, limit: 1)
        let in500 = stops.filter { $0.m <= 500 }.count

        VStack(spacing: 12) {
            // Mörkt kort för gällande plan, som i portalen.
            Card(fill: Theme.dark) {
                Eyebrow("Gällande plan", color: Color.white.opacity(0.65))
                FitText(main.map(\.title) ?? "Ingen detaljplan", sizes: [26, 23, 20, 17], color: .white) { BCFont.display($0) }
                Text(main.map { m in
                    "\(m.bet)\(m.name.isEmpty ? "" : ", " + m.typ.lowercased()). " + (plans.count > 1 ? "Totalt \(plans.count) planbeslut gäller på adressen." : "Det är det enda planbeslutet på adressen.")
                } ?? "Adresspunkten ligger utanför gällande detaljplaner. Då gäller översiktsplanen och plan- och bygglagens regler.")
                    .font(BCFont.body(15)).foregroundStyle(Color.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 12) {
                if K.has(.stops) {
                    smallCard("Kollektivtrafik", stops.first.map { "\($0.place.name), \(Txt.dist($0.m))" } ?? "Ingen hållplats i underlaget",
                              in500 > 1 ? "\(in500) hållplatser inom 500 m." : in500 == 1 ? "Den enda inom 500 m." : "Ingen hållplats inom 500 m.")
                } else {
                    smallCard("Fastighet", model.row?.fastighet ?? "–",
                              model.row?.area.map { "\(Txt.num($0)) m² enligt fastighetsgränsen." } ?? "Enligt \(K.org)s fastighetskarta.")
                }
                smallCard("Skola och förskola", schools.first?.place.name ?? "–",
                          [schools.first.map { "Grundskola \(Txt.dist($0.m))." }, pre.first.map { "Förskola \(Txt.dist($0.m))." }].compactMap { $0 }.joined(separator: " "))
            }

            EnvStrip(model: model)
        }
    }

    private func smallCard(_ eyebrow: String, _ big: String, _ text: String) -> some View {
        Card(padding: 16) {
            Eyebrow(eyebrow)
            FitText(big, sizes: [18, 16, 14])
            Text(text).font(BCFont.small).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

struct EnvStrip: View {
    let model: ReportModel
    @Environment(DataStore.self) private var store

    var body: some View {
        let K = store.kommun(model.address)
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            if let m = model.meta, let r = model.row {
                if K.has(.miljo) {
                    let t = EnvTexts(meta: m, row: r)
                    tile("Trafikbuller", t.leq ?? "–", t.leq == nil ? "Ingen beräkning nära adressen" : (t.leqLow != nil && t.leqLow != t.leq ? "Mot gatan, \(t.leqLow!) på lugnaste sidan" : "Ekvivalent nivå nära huset"))
                    tile("Kvävedioxid", t.no2.map { "\(Txt.decimal($0)) µg/m³" } ?? "–", "Årsmedel, normen är 40")
                    tile("Skyfallsled", r.skyfall.map { $0 == 0 ? "Vid adressen" : Txt.dist($0) } ?? "Över 1 km", "Avstånd till närmaste")
                    let rad = t.radon?.components(separatedBy: ", ")
                    tile("Markradon", rad?.first ?? "–", rad.map { $0.dropFirst().joined(separator: ", ") }.flatMap { $0.isEmpty ? nil : $0 } ?? "Enligt översiktsplanen")
                } else {
                    if let g = GeoText(r.geo) { tile("Geotekniska utredningar", g.big, g.sub) }
                    if let p = store.nearby(store.service(model.address).preschools, to: model.address, limit: 1).first {
                        tile("Närmaste förskola", Txt.dist(p.m), p.place.name)
                    }
                    let nf = r.framtid.filter { $0.m <= 1500 }.count
                    tile("Projekt i närheten", nf > 0 ? "\(nf)" : "Inga", "Inom 1,5 km")
                    tile("Buller, luft, skyfall", "Saknas", "Inte öppna data i \(K.namn)")
                }
            } else if model.loading {
                ForEach(0..<4, id: \.self) { _ in tile("Laddar", "…", " ") }.redacted(reason: .placeholder)
            }
        }
    }

    private func tile(_ k: String, _ v: String, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(k).font(BCFont.medium(13)).foregroundStyle(Theme.muted)
            FitText(v, sizes: [20, 18, 16, 14, 12])
            Text(s).font(BCFont.caption).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .padding(14)
        .background(Theme.subtle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Fastighet och detaljplan

struct PropertySection: View {
    let model: ReportModel
    let plans: [PlanInfo]
    @Environment(DataStore.self) private var store

    var body: some View {
        let a = model.address
        let K = store.kommun(a)
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Fastighet och detaljplan",
                         lead: plans.isEmpty ? "Adresspunkten ligger inte inom någon gällande plan i \(K.genitiv) planregister."
                         : "\(plans.count == 1 ? "Ett planbeslut" : "\(plans.count) planbeslut") gäller där adresspunkten ligger. Öppna plankartan för att se bestämmelserna, till exempel hur mycket som får byggas.")

            Card {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], alignment: .leading, spacing: 16) {
                    figure("Fastighetsbeteckning", model.row?.fastighet ?? (model.loading ? "…" : "–"), model.row?.fastighet == nil ? "Hittades inte" : "\(Txt.capitalizedFirst(K.genitiv)) fastighetskarta")
                    figure("Fastighetens area", model.row?.area.map { "\(Txt.num($0)) m²" } ?? "–", "Beräknad ur fastighetsgränsen")
                    figure("Planbeslut på adressen", "\(plans.count)", "Detaljplaner och fastighetsindelning")
                    figure("Kommun", K.namn, "\(K.org)s adressregister")
                }
                SourceText("Fastigheten är den yta i \(K.genitiv) fastighetskarta som adresspunkten ligger i. För en bostadsrätt är det föreningens fastighet, och arean gäller hela fastigheten. Jämför arean med tomtarean i annonsen.")
            }

            if plans.isEmpty {
                Notice(text: "Utan detaljplan prövas bygglov mot översiktsplanen och plan- och bygglagens allmänna regler. \(K.has(.miljo) ? "Stadsbyggnadskontoret" : K.org) kan svara på vad som gäller för just den här platsen.")
            }
            ForEach(PlanInfo.Group.allCases, id: \.self) { g in
                let list = plans.filter { $0.group == g }
                if !list.isEmpty {
                    Text(g.title).font(BCFont.serif(20)).foregroundStyle(Theme.text).padding(.top, 4)
                    ForEach(list) { p in planCard(p) }
                }
            }
            SourceText(K.has(.miljo)
                ? "Källa: Göteborgs Stad, stadsbyggnadskontorets karttjänst över gällande planer (planer-v3). Adresspunkten har jämförts med planernas gränser. En fastighet kan sträcka sig över fler planer än den som adresspunkten ligger i."
                : "Källa: \(K.org), karttjänsten över gällande detaljplaner, med länk till plankarta och planbeskrivning. Kommunen anger att gränserna är ungefärliga. Adresspunkten har jämförts med planernas gränser.")
        }
    }

    private func figure(_ k: String, _ v: String, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(k).font(BCFont.small).foregroundStyle(Theme.muted)
            FitText(v, sizes: [19, 17, 15, 13])
            Text(s).font(BCFont.caption).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func planCard(_ p: PlanInfo) -> some View {
        Card(padding: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(p.title).font(BCFont.semibold(16)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text(p.bet).font(BCFont.caption).foregroundStyle(Theme.muted)
            }
            Text([p.name.isEmpty ? "" : p.typ + ".", p.lagaKraft.isEmpty ? "" : "Laga kraft \(p.lagaKraft).", p.about].filter { !$0.isEmpty }.joined(separator: " "))
                .font(BCFont.small).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            if p.url != nil || p.besk != nil {
                HStack(spacing: 8) {
                    if let u = p.url { Link(destination: u) { Label("Plankarta", systemImage: "doc.richtext") }.buttonStyle(PillButtonStyle()) }
                    if let u = p.besk { Link(destination: u) { Label("Planbeskrivning", systemImage: "doc.text") }.buttonStyle(PillButtonStyle()) }
                }
                .font(BCFont.semibold(14))
            }
        }
    }
}

// MARK: - Miljö och risk

struct EnvironmentSection: View {
    let model: ReportModel
    @Environment(DataStore.self) private var store

    var body: some View {
        let K = store.kommun(model.address)
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Miljö och risk", lead: K.has(.miljo)
                ? "Buller, luft, vatten och mark vid adresspunkten. Värdena är beräknade, inte uppmätta på plats. Normer och riktvärden visas som jämförelse."
                : "Vatten och mark vid adresspunkten, så långt \(K.org) har öppna data.")
            if let m = model.meta, let r = model.row {
                if K.has(.miljo) { full(EnvTexts(meta: m, row: r)) } else { lite(r, K) }
            } else if model.loading {
                Card { ProgressView().frame(maxWidth: .infinity) }
            } else {
                Notice(text: "Miljödata kunde inte hämtas. Kontrollera anslutningen och öppna adressen igen.")
            }
        }
    }

    @ViewBuilder private func full(_ t: EnvTexts) -> some View {
        Card {
            HStack { Text("Trafikbuller runt huset").font(BCFont.serif(20)); Spacer(); Text("dBA, beräknat").font(BCFont.caption).foregroundStyle(Theme.muted) }
            noiseRow("Ekvivalent ljudnivå", "2023", t.leq, t.leqLow, "60 vid fasad (småhus), 50 vid uteplats")
            Hairline()
            noiseRow("Maximal ljudnivå", "2021", t.max, t.maxLow, "70 vid uteplats")
            SourceText("Nivåerna gäller marken inom 25 m från adresspunkten. Högsta värdet ligger oftast mot gatan och lägsta på den skyddade sidan. Riktvärdena kommer från förordning 2015:216 och gäller när nya bostäder byggs. Källa: Göteborgs Stad, miljöförvaltningens trafikbullerberäkningar 2021 och 2023.")
            Hairline()
            FactRow(title: "Flyg och försvar",
                    text: [t.flyg, t.fm].compactMap { $0 }.joined(separator: " ").nonEmpty ?? "Inom 2 km finns varken område med tillstånd för civilt flyg eller Försvarsmaktens påverkansområde för buller.",
                    source: "översiktsplanens kartlager.")
        }
        Card {
            HStack { Text("Luftkvalitet").font(BCFont.serif(20)); Spacer(); Text("µg/m³, årsmedel 2023").font(BCFont.caption).foregroundStyle(Theme.muted) }
            airRow("Kvävedioxid", t.no2, norm: 40)
            airRow("Partiklar PM10", t.pm10, norm: 40)
            SourceText("Stapeln visar värdet som andel av miljökvalitetsnormen. Källa: Göteborgs Stad, miljöförvaltningen, spridningsberäkningar 2023.")
        }
        Card {
            Text("Vatten och mark").font(BCFont.serif(20))
            FactRow(title: "Skyfall", text: t.sky, source: "översiktsplanen, skyfallsleder.")
            Hairline()
            FactRow(title: "Översvämning och höga vattenstånd", text: t.flood, source: "översiktsplanen, översvämning och höga vattenstånd.")
            Hairline()
            FactRow(title: "Förorenad mark", text: t.foro, source: "översiktsplanens tematiska tillägg om förorenade områden.")
            Hairline()
            FactRow(title: "Markradon", text: (t.radon ?? "Ingen uppgift") + ". Radonhalten inomhus beror på huset, och bara en mätning visar den faktiska halten.", source: "översiktsplanen, radon.")
            Hairline()
            FactRow(title: "Farligt gods", text: t.fg, source: "översiktsplanen, transportleder för farligt gods.")
            Hairline()
            FactRow(title: "Skred och markförhållanden", text: "Det finns ingen öppen skreddata per adress för hela staden. SGI:s skredriskkartering gäller främst området längs Göta älv. Planbeskrivningen till detaljplanen beskriver ofta markförhållandena.", source: "Statens geotekniska institut.")
        }
    }

    @ViewBuilder private func lite(_ r: EnvRow, _ K: Kommun) -> some View {
        Card {
            Text("Vatten och mark").font(BCFont.serif(20))
            if let g = GeoText(r.geo) {
                FactRow(title: "Geotekniska utredningar", text: g.text, source: "\(K.org), kartlagret geotekniska utredningar. Fråga kommunen om en kopia.")
                Hairline()
            }
            FactRow(title: "Skred och markförhållanden", text: "Det finns ingen öppen skreddata per adress. Planbeskrivningen till detaljplanen beskriver ofta markförhållandena, och länken finns under Fastighet och detaljplan.", source: "Statens geotekniska institut.")
            Hairline()
            FactRow(title: "Markradon", text: "Ingen öppen radonkarta per adress från kommunen. Radonhalten inomhus beror på huset, och bara en mätning visar den faktiska halten.", source: K.org + ".")
        }
        VStack(alignment: .leading, spacing: 10) {
            Notice(text: "Saknas för \(K.namn). \(K.namn) kommun publicerar inte \(K.saknas ?? "miljödata") som öppna data som går att läsa per adress. Uppgifterna kan finnas i kommunens webbkarta eller hos kommunens miljöförvaltning.")
            if let u = K.karta { Link(destination: u) { Label("Öppna kommunens webbkarta", systemImage: "map") }.buttonStyle(PillButtonStyle()) }
        }
    }

    private func noiseRow(_ title: String, _ year: String, _ hi: String?, _ lo: String?, _ ref: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) (\(year))").font(BCFont.semibold(15))
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) { Text("Högsta nära huset").font(BCFont.caption).foregroundStyle(Theme.muted); Text(hi ?? "Ingen beräkning").font(BCFont.serif(18)) }
                VStack(alignment: .leading, spacing: 2) { Text("Lägsta nära huset").font(BCFont.caption).foregroundStyle(Theme.muted); Text(lo ?? "–").font(BCFont.serif(18)) }
            }
            Text("Riktvärde som jämförelse: \(ref).").font(BCFont.small).foregroundStyle(Theme.muted)
        }
    }

    private func airRow(_ name: String, _ v: Double?, norm: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(BCFont.medium(15))
                Spacer()
                if let v { Text("\(Txt.decimal(v)) av normen \(Int(norm))").font(BCFont.medium(15)).monospacedDigit() } else { Text("Utanför beräkningsområdet").font(BCFont.small).foregroundStyle(Theme.muted) }
            }
            if let v {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.subtle)
                        Capsule().fill(Theme.accent).frame(width: g.size.width * min(1, v / norm))
                    }
                }
                .frame(height: 8)
                .accessibilityHidden(true)
            }
        }
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Planer i området

struct AreaSection: View {
    let model: ReportModel
    @Environment(DataStore.self) private var store

    var body: some View {
        let K = store.kommun(model.address)
        let work = model.workItems()
        let fut = model.futureItems(K)
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Planer i området", lead: K.has(.op)
                ? "Pågående planarbete inom 1,5 km och det översiktsplanen pekar ut för framtiden: nya vägar och spår, områden där markanvändningen kan förändras och områden som ska utredas."
                : "Kommunens planerade samhällsbyggnadsprojekt inom 1,5 km från adressen, till exempel nya gång- och cykelvägar och ledningsarbeten.")

            if K.has(.planarbete), let pw = model.work {
                Text("Pågående planarbete").font(BCFont.serif(20)).padding(.top, 4)
                if work.isEmpty {
                    Notice(text: "Staden har inget pågående planarbete eller byggprojekt registrerat inom 1,5 km från adressen.")
                } else {
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(work.enumerated()), id: \.element.id) { i, x in
                                if i > 0 { Hairline() }
                                PlanWorkRow(item: x, phases: pw.phases)
                            }
                        }
                    }
                }
                SourceText("Stapeln visar skedet: tidigt skede, samråd, granskning, antagande, laga kraft och byggande. Avstånd fågelvägen till projektets mittpunkt. Källa: Göteborgs Stad, databasen för plan- och byggprojekt.\(pw.updated.map { " Uppgifterna hämtades \($0)." } ?? "")")
            }

            if K.has(.op) { Text("Utpekat i översiktsplanen").font(BCFont.serif(20)).padding(.top, 4) }
            if let data = model.future {
                if fut.isEmpty {
                    Notice(text: K.has(.op) ? "Översiktsplanen pekar inte ut några nya vägar, spår eller förändringsområden inom 1,5 km från adressen." : "\(K.org) har inga samhällsbyggnadsprojekt i kartlagret inom 1,5 km från adressen.")
                } else {
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(fut.enumerated()), id: \.element.id) { i, x in
                                if i > 0 { Hairline() }
                                FutureRow(item: x, data: data, kommun: K)
                            }
                        }
                    }
                }
                SourceText("Källa: \(data.src). Sträckningar och gränser är ungefärliga.")
            } else if model.loading {
                Card { ProgressView().frame(maxWidth: .infinity) }
            }

            if !K.has(.planarbete) {
                VStack(alignment: .leading, spacing: 10) {
                    Notice(text: "Pågående detaljplaner finns inte som öppna kartdata från \(K.org). Kommunen listar dem på sin webbplats.")
                    if let u = K.plansida { Link(destination: u) { Label("Pågående detaljplanering", systemImage: "arrow.up.right.square") }.buttonStyle(PillButtonStyle()) }
                }
            }
        }
    }
}

struct PlanWorkRow: View {
    let item: PlanWorkItem
    let phases: [String: String]
    var compact = false
    @State private var open: Bool

    init(item: PlanWorkItem, phases: [String: String], startOpen: Bool = false, compact: Bool = false) {
        self.item = item; self.phases = phases; self.compact = compact
        _open = State(initialValue: startOpen)
    }

    var body: some View {
        let w = item.work
        let sy = item.synpunkter()
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Circle().fill(item.isBuilding ? Theme.accent : Theme.future).frame(width: 9, height: 9)
                        Text(w.namn).font(BCFont.semibold(15)).foregroundStyle(Theme.text).multilineTextAlignment(.leading)
                        Spacer()
                        Text(Txt.dist(item.m)).font(BCFont.small).foregroundStyle(Theme.muted)
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint).rotationEffect(.degrees(open ? 180 : 0))
                    }
                    if let i = item.stepIndex { Stepper6(index: i) }
                    Text("\(w.slag) · \(phases[w.fas] ?? w.fas)\(sy?.open == true ? " · synpunkter kan lämnas nu" : "")")
                        .font(BCFont.small).foregroundStyle(Theme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 8) {
                    detail("Typ", w.slag)
                    detail("Skede", w.steg.isEmpty ? (phases[w.fas] ?? w.fas) : w.steg)
                    if let sy { detail("Synpunkter", sy.text) }
                    detail("Avstånd", "\(Txt.dist(item.m)) från adresspunkten" + (w.ungefar ? ". Läget är ungefärligt, uppskattat från en gatuadress i projektets namn" : ""))
                    if let u = w.lank { Link(destination: u) { Label("Projektsidan på goteborg.se", systemImage: "arrow.up.right.square") }.font(BCFont.semibold(14)) }
                }
                .transition(.opacity)
            }
        }
        .padding(compact ? 0 : 16)
    }

    private func detail(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(BCFont.caption).foregroundStyle(Theme.muted)
            Text(v).font(BCFont.body(15)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Sex steg från tidigt skede till byggande.
struct Stepper6: View {
    let index: Int
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<6, id: \.self) { j in
                Capsule().fill(j < index ? Theme.accent.opacity(0.55) : j == index ? Theme.accent : Theme.subtle2).frame(height: 5)
            }
        }
        .frame(maxWidth: 180)
        .accessibilityLabel("Steg \(index + 1) av 6")
    }
}

struct FutureRow: View {
    let item: FutureItem
    let data: FutureData
    let kommun: Kommun
    var compact = false
    @State private var open: Bool

    init(item: FutureItem, data: FutureData, kommun: Kommun, startOpen: Bool = false, compact: Bool = false) {
        self.item = item; self.data = data; self.kommun = kommun; self.compact = compact
        _open = State(initialValue: startOpen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.future, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).frame(width: 10, height: 10)
                        Text(item.feature.title).font(BCFont.semibold(15)).foregroundStyle(Theme.text).multilineTextAlignment(.leading)
                        Spacer()
                        Text(item.distanceText).font(BCFont.small).foregroundStyle(Theme.muted)
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint).rotationEffect(.degrees(open ? 180 : 0))
                    }
                    Text(item.summary).font(BCFont.small).foregroundStyle(Theme.muted).multilineTextAlignment(.leading).lineLimit(open ? nil : 3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(item.details(data, kommun: kommun).enumerated()), id: \.offset) { _, row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.0).font(BCFont.caption).foregroundStyle(Theme.muted)
                            Text(row.1).font(BCFont.body(15)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if kommun.has(.op) {
                        Link(destination: URL(string: data.url ?? "https://oversiktsplan.goteborg.se/")!) { Label("Digitala översiktsplanen", systemImage: "arrow.up.right.square") }
                        Text("Översiktsplanen öppnas på startsidan. Sök på ”\(item.feature.title)” i planen. Staden har inga direktlänkar till enskilda objekt.").font(BCFont.caption).foregroundStyle(Theme.faint)
                    } else if let u = kommun.karta {
                        Link(destination: u) { Label("Kommunens karta", systemImage: "arrow.up.right.square") }
                    }
                    ForEach(Array(item.links.enumerated()), id: \.offset) { _, l in Link(destination: l.1) { Label(l.0, systemImage: "arrow.up.right.square") } }
                }
                .font(BCFont.semibold(14))
                .transition(.opacity)
            }
        }
        .padding(compact ? 0 : 16)
    }
}

// MARK: - Närservice

struct ServiceSection: View {
    let address: Address
    @Environment(DataStore.self) private var store

    var body: some View {
        let a = address
        let K = store.kommun(a)
        let S = store.service(a)
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Närservice", lead: "Avstånd fågelvägen från adresspunkten.")
            if K.has(.stops) {
                category("Kollektivtrafik", "bus", store.nearby(S.stops, to: a, limit: 5), source: "Källa: Västtrafiks hållplatslägen och linjesträckningar via Trafikkontorets öppna geodata. Linjerna är de vars sträckning går förbi hållplatsen. Tidtabell och vilka turer som stannar finns hos Västtrafik.") { x in
                    LineChips(lines: x.place.lines.compactMap { S.lines.indices.contains($0) ? S.lines[$0] : nil })
                }
            } else {
                Card {
                    header("Kollektivtrafik", "bus")
                    Text("Hållplatser för \(K.namn) finns inte i underlaget. Västtrafiks öppna hållplatsdata kräver en API-nyckel, och kommunen publicerar inga egna hållplatslägen.").font(BCFont.small).foregroundStyle(Theme.muted)
                    Link("Sök resor hos Västtrafik", destination: URL(string: "https://www.vasttrafik.se/")!).font(BCFont.semibold(14))
                }
            }
            category("Grundskolor", "graduationcap", store.nearby(S.schools, to: a, limit: 5) { $0.level == "gr" },
                     source: "Källa: Skolverkets skolenhetsregister. Vilken skola barnet får plats i avgörs av \(K.has(.miljo) ? "staden" : "kommunen").") { x in
                meta(x.place.address + (x.place.grades.isEmpty ? "" : " · årskurs \(x.place.grades)") + inOther(x.place, K))
            }
            category("Förskolor", "figure.and.child.holdinghands", store.nearby(S.preschools, to: a, limit: 5),
                     source: K.has(.miljo) ? "Källa: Göteborgs Stad, Hitta förskolor. Plats söks hos staden och styrs inte av avståndet." : "Källa: \(K.org)s karta över förskolor och Göteborgs Stads förskolelista för förskolor nära gränsen. Plats söks hos kommunen där barnet bor.") { x in
                meta(x.place.address + (x.place.subtype.isEmpty ? "" : " · " + x.place.subtype.lowercased()) + inOther(x.place, K))
            }
            category("Gymnasieskolor", "building.columns", store.nearby(S.schools, to: a, limit: 3) { $0.level == "gy" }, source: "Källa: Skolverkets skolenhetsregister.") { x in
                meta(x.place.address + inOther(x.place, K))
            }
            if K.has(.shops) {
                category("Livsmedelsbutiker", "cart", store.nearby(S.shops, to: a, limit: 5), source: "Källa: Göteborgs Stad, miljöförvaltningens register över livsmedelsverksamheter (typ livsmedelsbutik).") { x in meta(x.place.address) }
                category("Apotek", "cross.case", store.nearby(S.pharmacies, to: a, limit: 3), source: "Källa: samma register, verksamheter av typen apotek.") { x in meta(x.place.address) }
            }
        }
    }

    private func inOther(_ p: Place, _ K: Kommun) -> String { !K.has(.miljo) && p.kommunName == "Göteborg" ? " · Göteborg" : "" }

    private func meta(_ s: String) -> some View { Text(s).font(BCFont.small).foregroundStyle(Theme.muted) }

    private func header(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32).background(Theme.accentSoft, in: Circle())
            Text(title).font(BCFont.serif(20)).foregroundStyle(Theme.text)
        }
    }

    private func category<M: View>(_ title: String, _ icon: String, _ items: [Nearby], source: String, @ViewBuilder meta: @escaping (Nearby) -> M) -> some View {
        Card {
            header(title, icon)
            if items.isEmpty {
                Text("Inget i underlaget i närheten.").font(BCFont.small).foregroundStyle(Theme.muted)
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { i, x in
                if i > 0 { Hairline() }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(x.place.name).font(BCFont.medium(15)).foregroundStyle(Theme.text)
                        Spacer()
                        Text(Txt.dist(x.m)).font(BCFont.medium(14)).foregroundStyle(Theme.text).monospacedDigit()
                    }
                    DistanceBar(m: x.m)
                    meta(x)
                }
            }
            SourceText(source)
        }
    }
}

struct DistanceBar: View {
    let m: Int
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.subtle)
                Capsule().fill(Theme.accent.opacity(0.6)).frame(width: max(4, g.size.width * min(1, Double(m) / 2000)))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

struct LineChips: View {
    let lines: [Line]
    private static let order = ["Spårvagn": 0, "Buss": 1, "Båt": 2, "Tåg": 3, "Flygbuss": 4]

    var body: some View {
        let sorted = lines.sorted { a, b in
            let oa = LineChips.order[a.type] ?? 9, ob = LineChips.order[b.type] ?? 9
            if oa != ob { return oa < ob }
            let na = Int(a.name) ?? 999, nb = Int(b.name) ?? 999
            if na != nb { return na < nb }
            return a.name < b.name
        }
        if sorted.isEmpty {
            Text("Hållplats").font(BCFont.small).foregroundStyle(Theme.muted)
        } else {
            FlowLayout(spacing: 4) {
                ForEach(Array(sorted.enumerated()), id: \.offset) { _, l in
                    Text(l.name).font(BCFont.semibold(12, .caption)).monospacedDigit()
                        .foregroundStyle(l.type == "Spårvagn" ? Color.white : Theme.text)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(l.type == "Spårvagn" ? Theme.stop : Theme.subtle, in: RoundedRectangle(cornerRadius: 6))
                        .accessibilityLabel("\(l.type) \(l.name)")
                }
            }
        }
    }
}

// MARK: - Frågor till visningen

struct QuestionsSection: View {
    let model: ReportModel
    let plans: [PlanInfo]
    @Environment(DataStore.self) private var store
    @Environment(UserStore.self) private var user

    var body: some View {
        let a = model.address
        let K = store.kommun(a)
        let form = user.form(a.key)
        let qs = Question.build(address: a, store: store, plans: plans, meta: model.meta, row: model.row,
                                future: model.futureItems(K), work: model.workItems(), form: form)
        let done = qs.filter { user.isChecked(a.key, $0.id) }.count
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Frågor till visningen", lead: "En checklista att ta med, utifrån planerna, miljön och området. Bocka av när du har fått svar. Det sparas bara i telefonen.")
            VStack(alignment: .leading, spacing: 8) {
                Text("Vad gäller visningen?").font(BCFont.medium(14)).foregroundStyle(Theme.muted)
                FlowLayout(spacing: 8) {
                    ForEach(Boendeform.allCases) { f in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { user.setForm(form == f ? nil : f, for: a.key) }
                        } label: {
                            Text(f.short)
                                .font(BCFont.medium(14))
                                .foregroundStyle(form == f ? Color.white : Theme.text)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(form == f ? Theme.accent : Theme.card, in: Capsule())
                                .overlay(Capsule().strokeBorder(form == f ? Color.clear : Theme.line))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(form == f ? .isSelected : [])
                    }
                }
                if form == nil {
                    Text("Välj boendeform så anpassas frågorna. Nedan visas frågorna om platsen.")
                        .font(BCFont.small).foregroundStyle(Theme.faint)
                }
            }
            Card {
                HStack {
                    Text("\(done) av \(qs.count)").font(BCFont.semibold(15)).monospacedDigit()
                    Spacer()
                }
                ProgressView(value: Double(done), total: Double(max(qs.count, 1))).tint(Theme.accent)
                ForEach(qs) { q in
                    Hairline()
                    Button { user.toggleChecked(a.key, q.id) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: user.isChecked(a.key, q.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20)).foregroundStyle(user.isChecked(a.key, q.id) ? Theme.accent : Theme.faint)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(q.text).font(BCFont.medium(15)).foregroundStyle(Theme.text).multilineTextAlignment(.leading)
                                if !q.detail.isEmpty { Text(q.detail).font(BCFont.small).foregroundStyle(Theme.muted).multilineTextAlignment(.leading) }
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(user.isChecked(a.key, q.id) ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Källor

struct SourcesSection: View {
    let kommun: Kommun

    var body: some View {
        let rows: [(String, String, String)] = kommun.id == "goteborg" ? [
            ("Adresser", "Göteborgs Stad, adressregistret (adresser-v1)", "2026-11-25"),
            ("Gällande planer", "Göteborgs Stad, stadsbyggnadskontoret (planer-v3), med länk till varje plans PDF", "2026-11-25"),
            ("Hållplatser och linjer", "Västtrafik via Trafikkontorets öppna geodata", "2026-11-27"),
            ("Pågående planarbeten", "Göteborgs Stad, databasen för plan- och byggprojekt (planobygg)", "Varje morgon"),
            ("Skolor", "Skolverkets skolenhetsregister", "2026-11-25"),
            ("Förskolor", "Göteborgs Stad, Hitta förskolor", "2026-11-25"),
            ("Fastighetsbeteckning och area", "Göteborgs Stad, fastighetskartan (sbf-extern-fastighetsgrans-v1)", "2026-11-25"),
            ("Trafikbuller", "Miljöförvaltningen, trafikbullerberäkningar 2023 och 2021", "2026-11-25"),
            ("Luftkvalitet", "Miljöförvaltningen, spridningsberäkningar 2023", "2026-11-25"),
            ("Skyfall, översvämning, radon, förorenad mark, farligt gods, flyg", "Göteborgs Stad, översiktsplanen (oversiktsplan-v4)", "2026-11-25"),
            ("Planerat i området", "Göteborgs Stad, översiktsplanen", "2026-11-25"),
            ("Livsmedelsbutiker och apotek", "Miljöförvaltningens register över livsmedelsverksamheter", "2026-11-25"),
            ("Karta", "Apple Maps", "Löpande"),
        ] : [
            ("Adresser", "Partille kommun, adresser (geodata.partille.se)", "2026-11-27"),
            ("Gällande detaljplaner", "Partille kommun, gällande detaljplaner, med länk till plankarta och planbeskrivning", "2026-11-27"),
            ("Fastighetsbeteckning och area", "Partille kommun, fastighetsgränser", "2026-11-27"),
            ("Skolor", "Skolverkets skolenhetsregister, Partille och Göteborg nära gränsen", "2026-11-27"),
            ("Förskolor", "Partille kommun, förskolor, och Göteborgs Stad nära gränsen", "2026-11-27"),
            ("Geotekniska utredningar", "Partille kommun, geotekniska utredningar", "2026-11-27"),
            ("Planerat i området", "Partille kommun, samhällsbyggnadsprojekt", "2026-11-27"),
            ("Karta", "Apple Maps", "Löpande"),
        ]
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Källor", lead: "Varje uppgift med källa och datum. Uppgifterna är förberäknade från öppna data och visas utan värdering.")
            Card {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                    if i > 0 { Hairline() }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(r.0).font(BCFont.semibold(14)).foregroundStyle(Theme.text)
                            Spacer()
                            Text(r.2).font(BCFont.caption).foregroundStyle(Theme.faint).monospacedDigit()
                        }
                        Text(r.1).font(BCFont.small).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
