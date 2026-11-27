import SwiftUI
import SafariServices

/// Kort för annonsen. Annonsbilder visas inte, bara en platshållare och länk till annonsören.
struct AdCard: View {
    let address: Address
    @Environment(DataStore.self) private var store
    @Environment(UserStore.self) private var user
    @State private var input = ""
    @State private var error: String?
    @State private var editing = false

    var body: some View {
        if let ad = user.ad(for: address.key) {
            Card(padding: 0) {
                Link(destination: ad.url) {
                    ZStack {
                        LinearGradient(colors: [Theme.subtle, Theme.subtle2], startPoint: .topLeading, endPoint: .bottomTrailing)
                        VStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle").font(.system(size: 26)).foregroundStyle(Theme.faint)
                            Text("Bilderna finns i annonsen hos \(ad.site)").font(BCFont.small).foregroundStyle(Theme.muted)
                        }
                    }
                    .frame(height: 130)
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.radius, topTrailingRadius: Theme.radius, style: .continuous))
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Kopplad annons · \(ad.site)")
                    Text("Pris, bilder och beskrivning finns i annonsen. Vi läser inte av annonsen, den öppnas hos \(ad.site).")
                        .font(BCFont.body(15)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Link(destination: ad.url) { Label("Se annonsen", systemImage: "arrow.up.right") }.buttonStyle(PillButtonStyle(primary: true))
                        Spacer()
                        Button("Ta bort") { user.setAd(nil, for: address.key) }.font(BCFont.medium(14)).foregroundStyle(Theme.muted)
                    }
                    SourceText("Kopplingen sparas bara i telefonen.")
                }
                .padding(18)
            }
        } else {
            Card(padding: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "link").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.accent)
                        .frame(width: 32, height: 32).background(Theme.accentSoft, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Är bostaden till salu?").font(BCFont.semibold(15)).foregroundStyle(Theme.text)
                        Text("Klistra in länken till annonsen på Hemnet eller Booli så visas den här.").font(BCFont.small).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 8) {
                    PasteButton(payloadType: String.self) { items in
                        guard let s = items.first else { return }
                        Task { @MainActor in link(s) }
                    }
                    .buttonBorderShape(.capsule)
                    .tint(Theme.accent)
                    Button(editing ? "Avbryt" : "Skriv in länk") { editing.toggle() }
                        .buttonStyle(PillButtonStyle())
                }
                if editing {
                    HStack {
                        TextField("https://www.hemnet.se/bostad/…", text: $input)
                            .font(BCFont.body(15)).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .submitLabel(.done).onSubmit { link(input) }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Theme.subtle, in: Capsule())
                        Button("Koppla") { link(input) }.buttonStyle(PillButtonStyle(primary: true))
                    }
                }
                if let error { Text(error).font(BCFont.small).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true) }
            }
        }
    }

    private func link(_ s: String) {
        guard let ad = AdLink.parse(s) else {
            error = "Länken måste gå till hemnet.se eller booli.se och börja med https://."
            return
        }
        if let other = ad.address(in: store), other.id != address.id {
            error = "Länken verkar gälla \(other.label), inte \(address.label). Den har inte kopplats."
            return
        }
        error = nil
        input = ""
        editing = false
        user.setAd(ad, for: address.key)
    }
}

/// Öppnar länkar (planer som PDF, projektsidor, annonser) i appen.
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let c = SFSafariViewController(url: url)
        c.preferredControlTintColor = UIColor(Theme.accent)
        c.dismissButtonStyle = .close
        return c
    }
    func updateUIViewController(_ c: SFSafariViewController, context: Context) {}
}

// MARK: - Sparade

struct SavedView: View {
    @Environment(DataStore.self) private var store
    @Environment(UserStore.self) private var user

    var body: some View {
        Group {
            if user.saved.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sparade adresser").font(BCFont.display(32, .largeTitle)).foregroundStyle(Theme.text)
                    Text("Tryck på bokmärket i en rapport för att spara adressen här. Sparade adresser ligger bara i telefonen.")
                        .font(BCFont.body(16)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(20)
                .padding(.top, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                List {
                    Section {
                        ForEach(user.saved, id: \.self) { key in
                            if let a = store.address(key: key) {
                                NavigationLink(value: AddressRoute(id: a.id)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(a.label).font(BCFont.medium(16)).foregroundStyle(Theme.text)
                                        Text(store.street(a).postort == store.kommun(a).namn ? store.kommun(a).namn : "\(store.street(a).postort), \(store.kommun(a).namn)")
                                            .font(BCFont.small).foregroundStyle(Theme.muted)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(Theme.card)
                            } else if store.isReady {
                                Text(key).font(BCFont.body(15)).foregroundStyle(Theme.faint)
                            }
                        }
                        .onDelete { user.removeSaved(at: $0) }
                    } header: {
                        Text("Sparade adresser").font(BCFont.display(30, .largeTitle)).foregroundStyle(Theme.text).textCase(nil)
                            .padding(.bottom, 8)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Om

struct AboutView: View {
    @State private var safari: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Om Buyers Choice").font(BCFont.display(32, .largeTitle)).foregroundStyle(Theme.text).padding(.top, 24)
                Text("Buyers Choice samlar det en bostadsköpare behöver veta om platsen inför visning och budgivning: gällande detaljplan, vad kommunen planerar runt omkring, miljö och risker samt närservice.")
                    .font(BCFont.body(16)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
                Card {
                    FactRow(title: "Neutral information", text: "Appen visar uppgifter med källa. Den betygsätter inte bostäder eller områden.")
                    Hairline()
                    FactRow(title: "Öppna data", text: "Uppgifterna kommer från kommunernas, Västtrafiks, Skolverkets och Skatteverkets öppna data. De är förberäknade per adress och visar läget när de hämtades. Kontrollera alltid viktiga uppgifter hos kommunen eller mäklaren.")
                    Hairline()
                    FactRow(title: "Annonser", text: "Appen läser inte av annonser och visar inga annonsbilder. En kopplad annons öppnas hos Hemnet eller Booli.")
                    Hairline()
                    FactRow(title: "Din integritet", text: "Sparade adresser, kopplade annonser och checklistor ligger bara i telefonen. Din position används bara när du ber om adressen där du är, och den sparas inte.")
                }
                Card {
                    FactRow(title: "Kommuner", text: "Göteborg och Partille. Fler kommuner läggs till när de har öppna data.")
                    Hairline()
                    FactRow(title: "Typsnitt", text: "Fraunces och Inter, under SIL Open Font License 1.1.")
                    Hairline()
                    FactRow(title: "Version", text: Bundle.main.versionText)
                }
                Button { safari = AppConfig.portal } label: { Label("Öppna webbportalen", systemImage: "safari") }
                    .buttonStyle(PillButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $safari) { SafariView(url: $0).ignoresSafeArea() }
    }
}

extension Bundle {
    var versionText: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(v) (\(b))"
    }
}
