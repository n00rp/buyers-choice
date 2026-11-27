import SwiftUI
import CoreLocation

struct SearchView: View {
    var openAddress: (Address) -> Void
    @Environment(DataStore.self) private var store
    @Environment(UserStore.self) private var user
    @State private var query = ""
    @State private var message: String?
    @State private var pendingAd: AdLink?
    @State private var locating = false
    @FocusState private var focused: Bool
    @State private var location = LocationFetcher()

    private let examples = ["Linnégatan 20", "Eriksbergstorget 1", "Saltholmsgatan 20A", "Partille:Fröjas backe 10"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                searchBox
                if !focused || query.isEmpty { quickActions }
                if query.isEmpty {
                    if !user.recent.isEmpty { recentList }
                    examplesList
                    steps
                    SourceText("Uppgifterna är förberäknade från kommunernas, Västtrafiks, Skolverkets och Skatteverkets öppna data, hämtade 2026-11-25 (Göteborg) och 2026-11-27 (Partille). Vad som finns per adress beror på vad kommunen publicerar. Pågående planarbete i Göteborg uppdateras varje morgon.")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Delar

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(store.isReady ? "Göteborg och Partille · \(Txt.num(store.totalCount)) adresser" : "Göteborg och Partille")
            Text("Vad gäller kring adressen?")
                .font(BCFont.display(36, .largeTitle))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("Sök en adress och se gällande detaljplaner, miljö och risker, vad som planeras runt omkring och service i närheten.")
                .font(BCFont.body(16))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 24)
    }

    private var searchBox: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("Adress, t.ex. Linnégatan 20", text: $query)
                    .font(BCFont.body(17))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                    .onSubmit(submit)
                    .onChange(of: query) { message = nil }
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.faint) }
                        .accessibilityLabel("Rensa")
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 15)

            if let message {
                Hairline()
                Text(message).font(BCFont.body(15)).foregroundStyle(Theme.muted)
                    .padding(18).fixedSize(horizontal: false, vertical: true)
            } else if !query.isEmpty {
                suggestions
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(focused ? Theme.accent.opacity(0.5) : Theme.line, lineWidth: focused ? 1.5 : 1))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
    }

    @ViewBuilder private var suggestions: some View {
        switch store.state {
        case .ready:
            if AdLink.looksLikeURL(query) {
                Hairline()
                row(title: "Koppla annonslänken", sub: "Tryck på sök så letar vi upp adressen i länken.", icon: "link") { submit() }
            } else {
                let hits = AddressSearch.search(query, streets: store.streets, addresses: store.addresses)
                if hits.isEmpty, Txt.fold(query).count >= 2 {
                    Hairline()
                    Text("Ingen adress i Göteborg eller Partille matchar. Prova gatunamn och nummer, t.ex. Linnégatan 20.")
                        .font(BCFont.body(15)).foregroundStyle(Theme.muted).padding(18)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(hits) { hit in
                    Hairline()
                    switch hit {
                    case .address(let k):
                        let a = store.addresses[k]
                        row(title: a.label, sub: store.street(a).postort, icon: "mappin") { open(a) }
                    case .street(let si):
                        let st = store.streets[si]
                        row(title: st.name, sub: "\(st.count) adresser · \(st.postort)", icon: "road.lanes") { query = st.name + " " }
                    }
                }
            }
        case .failed(let msg):
            Hairline()
            failure(msg)
        default:
            Hairline()
            HStack(spacing: 10) { ProgressView(); Text("Laddar adresserna …").font(BCFont.body(15)).foregroundStyle(Theme.muted) }.padding(18)
        }
    }

    private func row(title: String, sub: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.accent)
                    .frame(width: 30, height: 30).background(Theme.accentSoft, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(BCFont.medium(16)).foregroundStyle(Theme.text)
                    Text(sub).font(BCFont.small).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 18).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func failure(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(msg).font(BCFont.body(15)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            Button("Försök igen") { Task { await store.retry() } }.buttonStyle(PillButtonStyle())
        }
        .padding(18)
    }

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    Task { await locate() }
                } label: {
                    HStack(spacing: 6) {
                        if locating { ProgressView().controlSize(.small) } else { Image(systemName: "location.fill") }
                        Text("Adressen där jag är")
                    }
                }
                .buttonStyle(PillButtonStyle())
                .disabled(locating)

                PasteButton(payloadType: String.self) { items in
                    guard let s = items.first else { return }
                    Task { @MainActor in handlePasted(s) }
                }
                .buttonBorderShape(.capsule)
                .labelStyle(.titleAndIcon)
                .tint(Theme.accent)
            }
        }
        .scrollClipDisabled()
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow("Senast visade")
                Spacer()
                Button("Rensa") { user.clearRecent() }.font(BCFont.medium(13)).foregroundStyle(Theme.muted)
            }
            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(user.recent.enumerated()), id: \.element) { i, key in
                        if let a = store.address(key: key) {
                            if i > 0 { Hairline() }
                            row(title: a.label, sub: "\(store.street(a).postort)\(store.street(a).postort == store.kommun(a).namn ? "" : ", " + store.kommun(a).namn)", icon: "clock") { open(a) }
                        }
                    }
                }
            }
        }
    }

    private var examplesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Prova")
            FlowLayout(spacing: 8) {
                ForEach(examples, id: \.self) { key in
                    Button {
                        if let a = store.address(key: key) { open(a) }
                    } label: {
                        Text(key.split(separator: ":").last.map(String.init) ?? key)
                    }
                    .buttonStyle(PillButtonStyle())
                    .disabled(!store.isReady)
                }
            }
        }
    }

    private var steps: some View {
        VStack(spacing: 12) {
            step(1, "Sök adressen", "Alla adresser i Göteborg och Partille går att söka, oavsett om bostaden är till salu eller inte.")
            step(2, "Läs rapporten", "Fastighet och planer, buller, luft, skyfall och radon, vad som planeras i närheten och avstånd till hållplatser, skolor och butiker.")
            step(3, "Koppla annonsen", "Klistra in länken från Hemnet eller Booli så visas annonsen ihop med rapporten. Vi hämtar inget från annonsen.")
        }
    }

    private func step(_ n: Int, _ title: String, _ text: String) -> some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                Text("\(n)").font(BCFont.display(20)).foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36).background(Theme.accentSoft, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(BCFont.serif(19)).foregroundStyle(Theme.text)
                    Text(text).font(BCFont.body(15)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Handlingar

    private func open(_ a: Address) {
        if let ad = pendingAd { user.setAd(ad, for: a.key); pendingAd = nil }
        query = ""
        focused = false
        openAddress(a)
    }

    private func submit() {
        guard store.isReady else { return }
        if AdLink.looksLikeURL(query) { handlePasted(query); return }
        if let first = AddressSearch.search(query, streets: store.streets, addresses: store.addresses).first {
            switch first {
            case .address(let k): open(store.addresses[k])
            case .street(let si): query = store.streets[si].name + " "
            }
        }
    }

    private func handlePasted(_ s: String) {
        guard let ad = AdLink.parse(s) else {
            if AdLink.looksLikeURL(s) {
                message = "Bara länkar till hemnet.se eller booli.se kan kopplas, och de ska börja med https://."
            } else {
                query = s
            }
            return
        }
        guard store.isReady else { message = "Adresserna laddas fortfarande. Försök igen om en stund."; return }
        if let a = ad.address(in: store) {
            user.setAd(ad, for: a.key)
            open(a)
        } else {
            pendingAd = ad
            query = ""
            message = "Annonslänken till \(ad.site) är sparad. Adressen går inte att läsa ur länken, så sök fram adressen här så kopplas annonsen till den."
            focused = true
        }
    }

    private func locate() async {
        guard store.isReady else { return }
        locating = true
        defer { locating = false }
        do {
            let c = try await location.current()
            let p = Sweref.fromWGS84(c)
            if let a = store.nearestAddress(e: p.e, n: p.n) {
                open(a)
            } else {
                message = "Vi hittade ingen adress i Göteborg eller Partille inom 300 meter från dig."
            }
        } catch {
            message = "Din position gick inte att hämta. Tillåt platstjänster för Buyers Choice i Inställningar, eller sök på adressen."
        }
    }
}

/// Hämtar positionen en gång. Positionen sparas inte.
@MainActor
final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var cont: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func current() async throws -> CLLocationCoordinate2D {
        cont?.resume(throwing: CancellationError())
        return try await withCheckedThrowingContinuation { c in
            cont = c
            switch manager.authorizationStatus {
            case .notDetermined: manager.requestWhenInUseAuthorization()
            case .denied, .restricted: finish(.failure(CLError(.denied)))
            default: manager.requestLocation()
            }
        }
    }

    private func finish(_ r: Result<CLLocationCoordinate2D, Error>) {
        guard let c = cont else { return }
        cont = nil
        c.resume(with: r)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        Task { @MainActor in
            guard self.cont != nil else { return }
            switch m.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways: m.requestLocation()
            case .denied, .restricted: self.finish(.failure(CLError(.denied)))
            default: break
            }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        Task { @MainActor in self.finish(.success(c)) }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(.failure(error)) }
    }
}

/// Radbrytande rad med knappar.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > w { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: min(maxX, w), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
