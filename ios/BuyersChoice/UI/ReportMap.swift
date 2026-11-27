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
        let polygons: [[CLLocationCoordinate2D]]
        let lines: [[CLLocationCoordinate2D]]
        let points: [CLLocationCoordinate2D]
    }

    var points: [Point] = []
    var shapes: [Shape] = []

    @MainActor
    init(model: ReportModel, store: DataStore) {
        let a = model.address
        let K = store.kommun(a)
        let S = store.service(a)
        func add(_ list: [Nearby], _ sub: (Place) -> String) {
            points += list.map { Point(id: $0.place.id, name: $0.place.name, sub: sub($0.place), m: $0.m, kind: $0.place.kind, coordinate: $0.place.coordinate) }
        }
        add(store.nearby(S.shops, to: a, limit: 12, within: 1100)) { _ in "Livsmedelsbutik" }
        add(store.nearby(S.preschools, to: a, limit: 40, within: 1100)) { _ in "Förskola" }
        add(store.nearby(S.schools, to: a, limit: 40, within: 1100) { $0.level == "gr" }) { "Grundskola" + ($0.grades.isEmpty ? "" : " " + $0.grades) }
        if K.has(.stops) { add(store.nearby(S.stops, to: a, limit: 40, within: 1100)) { _ in "Hållplats" } }

        guard let row = model.row, let fut = model.future else { return }
        let conv: ([Double]) -> CLLocationCoordinate2D = { Sweref.toWGS84(e: $0.first ?? 0, n: $0.count > 1 ? $0[1] : 0) }
        for (i, (id, _)) in row.framtid.enumerated() where fut.features.indices.contains(id) {
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
            shapes.append(Shape(id: "\(id)-\(i)", title: f.title, polygons: polys, lines: lines, points: pts))
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
        Map(position: $position, interactionModes: interactive ? .all : [], selection: $selected) {
            if let layers {
                ForEach(layers.shapes) { s in
                    ForEach(Array(s.polygons.enumerated()), id: \.offset) { _, p in
                        MapPolygon(coordinates: p)
                            .foregroundStyle(Theme.future.opacity(0.10))
                            .stroke(Theme.future, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                    ForEach(Array(s.lines.enumerated()), id: \.offset) { _, l in
                        MapPolyline(coordinates: l)
                            .stroke(Theme.future, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 5]))
                    }
                    ForEach(Array(s.points.enumerated()), id: \.offset) { _, c in
                        Annotation(s.title, coordinate: c) {
                            Rectangle().fill(.white).frame(width: 10, height: 10)
                                .overlay(Rectangle().strokeBorder(Theme.future, lineWidth: 2))
                                .rotationEffect(.degrees(45))
                        }
                        .annotationTitles(.hidden)
                    }
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
            layers = MapLayers(model: model, store: store)
        }
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
            item(kommun.has(.op) ? "Planerat enligt översiktsplanen" : "Samhällsbyggnadsprojekt",
                 RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.future, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).frame(width: 12, height: 12))
        }
    }

    private func item<V: View>(_ t: String, _ v: V) -> some View {
        HStack(spacing: 6) { v; Text(t).font(BCFont.small).foregroundStyle(Theme.muted) }
    }
}

struct FullMapView: View {
    let model: ReportModel
    @Environment(\.dismiss) private var dismiss
    @Environment(DataStore.self) private var store
    @State private var selected: String?

    var body: some View {
        let layers = MapLayers(model: model, store: store)
        let sel = layers.points.first { $0.id == selected }
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
                MapLegend(kommun: store.kommun(model.address))
                SourceText("Karta från Apple Maps. Avstånd fågelvägen från adresspunkten. Streckade ytor och linjer är ungefärliga.")
            }
            .padding(16)
            .background(Theme.card.opacity(0.96), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
    }
}
