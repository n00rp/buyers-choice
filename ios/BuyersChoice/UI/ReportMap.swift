import SwiftUI
import MapKit

/// Det som ritas på kartan runt adressen: närservice och det som planeras.
struct MapLayers {
    struct Point: Identifiable {
        let id: String
        let name: String
        let sub: String
        let m: Int
        let kind: Place.Kind
        let coordinate: CLLocationCoordinate2D
    }
    struct Shape: Identifiable {
        let id: String
        let title: String
        let item: FutureItem
        let polygons: [[CLLocationCoordinate2D]]
        let lines: [[CLLocationCoordinate2D]]
        let points: [CLLocationCoordinate2D]

        /// Ett ställe att sätta en tryckbar markering: mitten av ytan, linjen eller punkten.
        var anchor: CLLocationCoordinate2D? {
            if let p = polygons.first, !p.isEmpty {
                let lat = p.map(\.latitude).reduce(0, +) / Double(p.count)
                let lon = p.map(\.longitude).reduce(0, +) / Double(p.count)
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            if let l = lines.max(by: { $0.count < $1.count }), !l.isEmpty { return l[l.count / 2] }
            return points.first
        }
    }
    /// Pågående planarbete (Göteborgs projektdatabas), som en punkt.
    struct Work: Identifiable {
        var id: String { "w:" + item.id }
        let item: PlanWorkItem
        let coordinate: CLLocationCoordinate2D
    }

    var points: [Point] = []
    var shapes: [Shape] = []
    var works: [Work] = []

    @MainActor
    init(model: ReportModel, store: DataStore, compact: Bool = false) {
        // Den lilla kartan i rapporten visar bara det närmaste, så att den inte blir plottrig.
        let lim = compact ? 6 : 40, r = compact ? 650 : 1100
        let a = model.address
        let K = store.kommun(a)
        let S = store.service(a)
        func add(_ list: [Nearby], _ sub: (Place) -> String) {
            points += list.map { Point(id: $0.place.id, name: $0.place.name, sub: sub($0.place), m: $0.m, kind: $0.place.kind, coordinate: $0.place.coordinate) }
        }
        add(store.nearby(S.shops, to: a, limit: compact ? 4 : 12, within: r)) { _ in "Livsmedelsbutik" }
        add(store.nearby(S.preschools, to: a, limit: lim, within: r)) { _ in "Förskola" }
        add(store.nearby(S.schools, to: a, limit: lim, within: r) { $0.level == "gr" }) { "Grundskola" + ($0.grades.isEmpty ? "" : " " + $0.grades) }
        if K.has(.stops) { add(store.nearby(S.stops, to: a, limit: lim, within: r)) { _ in "Hållplats" } }
        if !compact {
            works = model.workItems().filter { $0.m <= r }.map { Work(item: $0, coordinate: Sweref.toWGS84(e: $0.work.e, n: $0.work.n)) }
        }

        guard let row = model.row, let fut = model.future else { return }
        let conv: ([Double]) -> CLLocationCoordinate2D = { Sweref.toWGS84(e: $0.first ?? 0, n: $0.count > 1 ? $0[1] : 0) }
        for (i, (id, m)) in row.framtid.enumerated() where fut.features.indices.contains(id) {
            let f = fut.features[id]
            guard let g = f.geometry else { continue }
            var polys: [[CLLocationCoordinate2D]] = [], lines: [[CLLocationCoordinate2D]] = [], pts: [CLLocationCoordinate2D] = []
            switch g {
            case .point(let p): pts = [conv(p)]
            case .line(let l): lines = [l.map(conv)]
            case .multiLine(let ls): lines = ls.map { $0.map(conv) }
            case .polygon(let rings): polys = rings.prefix(1).map { $0.map(conv) }
            case .multiPolygon(let ps): polys = ps.compactMap { $0.first?.map(conv) }
            }
            let item = FutureItem(id: "\(id)-\(i)", feature: f, m: m, isProject: !K.has(.op))
            shapes.append(Shape(id: "f:\(id)-\(i)", title: f.title, item: item, polygons: polys, lines: lines, points: pts))
        }
    }

    static func color(_ k: Place.Kind) -> Color {
        switch k {
        case .stop: return Theme.stop
        case .school: return Theme.school
        case .preschool: return Theme.preschool
        case .shop, .pharmacy: return Theme.shop
        }
    }
}

struct ReportMapView: View {
    let model: ReportModel
    var interactive: Bool
    @Binding var selected: String?
    @Environment(DataStore.self) private var store
    @State private var layers: MapLayers?
    @State private var position: MapCameraPosition = .automatic

    init(model: ReportModel, interactive: Bool, selected: Binding<String?> = .constant(nil)) {
        self.model = model
        self.interactive = interactive
        self._selected = selected
        let c = model.address.coordinate
        _position = State(initialValue: .region(MKCoordinateRegion(center: c, latitudinalMeters: interactive ? 2000 : 1500, longitudinalMeters: interactive ? 2000 : 1500)))
    }

    var body: some View {
        MapReader { proxy in
            map
                .onTapGesture(coordinateSpace: .local) { pt in
                    guard interactive, let layers, let hit = hitShape(at: pt, layers: layers, proxy: proxy) else { return }
                    withAnimation(.easeOut(duration: 0.2)) { selected = hit }
                }
        }
    }

    private var map: some View {
        Map(position: $position, interactionModes: interactive ? .all : [], selection: $selected) {
            if let layers {
                ForEach(layers.shapes) { s in
                    let on = selected == s.id
                    ForEach(Array(s.polygons.enumerated()), id: \.offset) { _, p in
                        MapPolygon(coordinates: p)
                            .foregroundStyle(Theme.future.opacity(on ? 0.28 : 0.10))
                            .stroke(Theme.future, style: StrokeStyle(lineWidth: on ? 3 : 1.5, dash: on ? [] : [5, 4]))
                    }
                    ForEach(Array(s.lines.enumerated()), id: \.offset) { _, l in
                        MapPolyline(coordinates: l)
                            .stroke(Theme.future, style: StrokeStyle(lineWidth: on ? 5 : 3, lineCap: .round, dash: on ? [] : [6, 5]))
                    }
                    if interactive, s.points.isEmpty, let c = s.anchor {
                        Annotation(s.title, coordinate: c, anchor: .center) {
                            PlanBadge(selected: on)
                        }
                        .annotationTitles(on ? .visible : .hidden)
                        .tag(s.id)
                    }
                    ForEach(Array(s.points.enumerated()), id: \.offset) { _, c in
                        Annotation(s.title, coordinate: c) {
                            Rectangle().fill(.white).frame(width: on ? 14 : 10, height: on ? 14 : 10)
                                .overlay(Rectangle().strokeBorder(Theme.future, lineWidth: 2))
                                .rotationEffect(.degrees(45))
                        }
                        .annotationTitles(on ? .visible : .hidden)
                        .tag(s.id)
                    }
                }
                ForEach(layers.works) { w in
                    Annotation(w.item.work.namn, coordinate: w.coordinate, anchor: .center) {
                        WorkBadge(building: w.item.isBuilding, selected: selected == w.id)
                    }
                    .annotationTitles(selected == w.id ? .visible : .hidden)
                    .tag(w.id)
                }
                ForEach(layers.points) { p in
                    Annotation(p.name, coordinate: p.coordinate, anchor: .center) {
                        PoiDot(kind: p.kind, selected: selected == p.id)
                    }
                    .annotationTitles(interactive && selected == p.id ? .visible : .hidden)
                    .tag(p.id)
                }
            }
            Annotation(model.address.label, coordinate: model.address.coordinate, anchor: .center) {
                ZStack {
                    Circle().fill(Theme.dark.opacity(0.10)).frame(width: 34, height: 34)
                    Circle().fill(Theme.dark).frame(width: 16, height: 16).overlay(Circle().stroke(.white, lineWidth: 2.5))
                }
            }
            .annotationTitles(.visible)
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .task(id: "\(model.address.id)-\(model.loading)") {
            layers = MapLayers(model: model, store: store, compact: !interactive)
        }
        .onChange(of: selected) { _, id in
            // Flytta kartan så att det valda hamnar ovanför rutan med sammanfattningen.
            guard interactive, let id, let layers else { return }
            let c = layers.shapes.first { $0.id == id }.flatMap { $0.points.first ?? $0.anchor } ?? layers.works.first { $0.id == id }?.coordinate
            guard let c else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: c.latitude - 0.0045, longitude: c.longitude),
                                                      latitudinalMeters: 1800, longitudinalMeters: 1800))
            }
        }
    }

    /// Vilken planerad yta eller linje som ligger under en tryckning, om ingen markering ligger närmare.
    private func hitShape(at pt: CGPoint, layers: MapLayers, proxy: MapProxy) -> String? {
        func screen(_ c: CLLocationCoordinate2D) -> CGPoint? { proxy.convert(c, to: .local) }
        func near(_ c: CLLocationCoordinate2D, _ d: CGFloat) -> Bool {
            guard let p = screen(c) else { return false }
            return hypot(p.x - pt.x, p.y - pt.y) < d
        }
        // Tryck på en markering hanteras av kartan själv.
        if layers.points.contains(where: { near($0.coordinate, 22) }) || layers.works.contains(where: { near($0.coordinate, 22) })
            || layers.shapes.contains(where: { s in (s.points.first ?? (s.points.isEmpty ? s.anchor : nil)).map { near($0, 22) } ?? false }) {
            return nil
        }
        // Linjer först (de ligger ofta ovanpå ytor), inom 16 punkter.
        for s in layers.shapes {
            for l in s.lines {
                let ps = l.compactMap(screen)
                for i in ps.indices.dropFirst() where segmentDistance(pt, ps[i - 1], ps[i]) < 16 { return s.id }
            }
        }
        // Minsta ytan som innehåller punkten, så att en liten yta inuti en stor går att välja.
        var best: (String, CGFloat)?
        for s in layers.shapes {
            for poly in s.polygons {
                let ps = poly.compactMap(screen)
                guard ps.count > 2 else { continue }
                var path = Path(); path.addLines(ps); path.closeSubpath()
                if path.contains(pt) {
                    let b = path.boundingRect, area = b.width * b.height
                    if best == nil || area < best!.1 { best = (s.id, area) }
                }
            }
        }
        return best?.0
    }

    private func segmentDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        guard len2 > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}

/// Tryckbar markering mitt i en planerad yta eller linje.
struct PlanBadge: View {
    var selected = false
    var body: some View {
        Image(systemName: "square.dashed")
            .font(.system(size: selected ? 13 : 11, weight: .bold))
            .foregroundStyle(selected ? Color.white : Theme.future)
            .frame(width: selected ? 28 : 22, height: selected ? 28 : 22)
            .background(selected ? Theme.future : Color.white, in: Circle())
            .overlay(Circle().stroke(Theme.future, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .accessibilityLabel("Planerat område")
    }
}

/// Markering för pågående planarbete eller bygge.
struct WorkBadge: View {
    let building: Bool
    var selected = false
    var body: some View {
        let c = building ? Theme.accent : Theme.ongoing
        Image(systemName: building ? "hammer.fill" : "doc.text.fill")
            .font(.system(size: selected ? 12 : 10, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: selected ? 28 : 22, height: selected ? 28 : 22)
            .background(c, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 1.6))
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .accessibilityLabel(building ? "Bygge" : "Pågående planarbete")
    }
}

struct PoiDot: View {
    let kind: Place.Kind
    var selected = false
    var body: some View {
        let c = MapLayers.color(kind)
        Group {
            if kind == .stop {
                RoundedRectangle(cornerRadius: 2.5).fill(c).frame(width: 11, height: 11)
                    .overlay(RoundedRectangle(cornerRadius: 2.5).stroke(.white, lineWidth: 1.6))
            } else {
                Circle().fill(c).frame(width: 11, height: 11).overlay(Circle().stroke(.white, lineWidth: 1.6))
            }
        }
        .scaleEffect(selected ? 1.6 : 1)
        .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
    }
}

struct MapLegend: View {
    let kommun: Kommun
    var body: some View {
        FlowLayout(spacing: 12) {
            if kommun.has(.stops) { item("Hållplats", PoiDot(kind: .stop)) }
            item("Grundskola", PoiDot(kind: .school))
            item("Förskola", PoiDot(kind: .preschool))
            if kommun.has(.shops) { item("Livsmedelsbutik", PoiDot(kind: .shop)) }
            if kommun.has(.planarbete) { item("Pågående planarbete", WorkBadge(building: false).scaleEffect(0.7).frame(width: 16, height: 16)) }
            item(kommun.has(.op) ? "Planerat enligt översiktsplanen" : "Samhällsbyggnadsprojekt",
                 RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.future, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).frame(width: 12, height: 12))
        }
    }

    private func item<V: View>(_ t: String, _ v: V) -> some View {
        HStack(spacing: 6) { v; Text(t).font(BCFont.small).foregroundStyle(Theme.muted) }
    }
}

/// Visar innehållet i sin hela höjd om det får plats, annars i en rullbar ruta på högst 230 punkter.
struct Capped<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 0

    var body: some View {
        ScrollView {
            content.background(GeometryReader { g in Color.clear.preference(key: HeightKey.self, value: g.size.height) })
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(max(height, 1), 230))
        .onPreferenceChange(HeightKey.self) { height = $0 }
    }
}

private struct HeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct FullMapView: View {
    let model: ReportModel
    @Environment(\.dismiss) private var dismiss
    @Environment(DataStore.self) private var store
    @State private var selected: String?

    var body: some View {
        let layers = MapLayers(model: model, store: store)
        let K = store.kommun(model.address)
        let sel = layers.points.first { $0.id == selected }
        let selShape = layers.shapes.first { $0.id == selected }
        let selWork = layers.works.first { $0.id == selected }
        ZStack(alignment: .top) {
            ReportMapView(model: model, interactive: true, selected: $selected)
                .ignoresSafeArea()
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                        .frame(width: 40, height: 40).background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("Stäng kartan")
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                if let sel {
                    HStack {
                        PoiDot(kind: sel.kind)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sel.name).font(BCFont.semibold(16)).foregroundStyle(Theme.text)
                            Text("\(sel.sub) · \(Txt.dist(sel.m)) från adressen").font(BCFont.small).foregroundStyle(Theme.muted)
                        }
                    }
                    Hairline()
                }
                if let s = selShape, let data = model.future {
                    Capped { FutureRow(item: s.item, data: data, kommun: K, compact: true).id(s.id) }
                    Hairline()
                } else if let w = selWork {
                    Capped { PlanWorkRow(item: w.item, phases: model.work?.phases ?? [:], compact: true).id(w.id) }
                    Hairline()
                } else if sel == nil, !layers.shapes.isEmpty || !layers.works.isEmpty {
                    Text("Tryck på ett planerat område eller en markering för att läsa mer.")
                        .font(BCFont.small).foregroundStyle(Theme.muted)
                }
                if selShape == nil && selWork == nil { MapLegend(kommun: K) }
                SourceText("Karta från Apple Maps. Avstånd fågelvägen från adresspunkten. Streckade ytor och linjer är ungefärliga.")
            }
            .padding(16)
            .background(Theme.card.opacity(0.96), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .task {
            // Skärmbildsskriptet kan välja en plan på kartan: -uiMap shape eller -uiMap work
            guard let m = UserDefaults.standard.string(forKey: "uiMap") else { return }
            try? await Task.sleep(for: .milliseconds(600))
            let layers = MapLayers(model: model, store: store)
            selected = m == "work" ? layers.works.first?.id : layers.shapes.first?.id
        }
    }
}

/// Gatubild från Apple Look Around nära adressen. Visas bara där Apple har gatubilder.
struct StreetView: View {
    let coordinate: CLLocationCoordinate2D
    let label: String
    @State private var scene: MKLookAroundScene?
    @State private var checked = false

    var body: some View {
        // En tom Group får ingen .task, så platshållaren måste finnas även utan bild.
        VStack(alignment: .leading, spacing: 0) {
            if let scene {
                VStack(alignment: .leading, spacing: 8) {
                    LookAroundPreview(initialScene: scene, allowsNavigation: true, showsRoadLabels: true, pointsOfInterest: .excludingAll)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                        .accessibilityLabel("Gatubild nära \(label)")
                    SourceText("Gatubild från Apple Look Around, tagen från gatan närmast adressen. Tryck för att se i helskärm och se dig omkring. Bilden kan vara några år gammal.")
                }
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .task(id: "\(coordinate.latitude),\(coordinate.longitude)") {
            let req = MKLookAroundSceneRequest(coordinate: coordinate)
            scene = try? await req.scene
            checked = true
            Log.write("Gatubild: \(scene == nil ? "saknas" : "finns")")
        }
    }
}
