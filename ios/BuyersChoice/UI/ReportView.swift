import SwiftUI

@MainActor
@Observable
final class ReportModel {
    let address: Address
    var meta: EnvMeta?
    var row: EnvRow?
    var future: FutureData?
    var work: PlanWorkData?
    var loading = true
    var failed = false

    init(address: Address) { self.address = address }

    func load(_ store: DataStore) async {
        loading = true
        failed = false
        // Hämtas i tur och ordning. async let med try? kraschade i Swift-körtiden (swift_task_dealloc).
        let e = try? await store.env(for: address)
        let f = try? await store.future(for: address)
        let pw: PlanWorkData? = store.kommun(address).has(.planarbete) ? await store.planWork() : nil
        meta = e?.0
        row = e?.1
        future = f
        work = pw
        failed = e == nil
        loading = false
    }

    func futureItems(_ K: Kommun) -> [FutureItem] {
        guard let row, let future else { return [] }
        return FutureItem.list(row: row, data: future, kommun: K)
    }

    func workItems() -> [PlanWorkItem] { PlanWorkItem.near(address, data: work) }
}

enum ReportSection: String, CaseIterable, Identifiable {
    case oversikt, fastighet, miljo, omradet, service, fragor, kallor
    var id: String { rawValue }
    var title: String {
        switch self {
        case .oversikt: return "Översikt"
        case .fastighet: return "Fastighet och plan"
        case .miljo: return "Miljö och risk"
        case .omradet: return "Planer i området"
        case .service: return "Närservice"
        case .fragor: return "Frågor till visningen"
        case .kallor: return "Källor"
        }
    }
}

struct ReportView: View {
    let addressID: Int
    @Environment(DataStore.self) private var store
    @Environment(UserStore.self) private var user
    @State private var model: ReportModel?
    @State private var showMap = false
    @State private var safari: URL?
    @State private var reportInfo = false

    var body: some View {
        Group {
            if store.addresses.indices.contains(addressID), let model {
                content(model)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
            }
        }
        .task(id: "\(addressID)-\(store.isReady)") {
            await store.load()
            guard store.isReady, store.addresses.indices.contains(addressID), model?.address.id != addressID else { return }
            let m = ReportModel(address: store.addresses[addressID])
            model = m
            user.visited(m.address.key)
            Log.write("Rapport: laddar \(m.address.label)")
            await m.load(store)
            Log.write("Rapport: laddad, miljö \(m.row != nil ? "ok" : "saknas")")
        }
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "https" { safari = url; return .handled }
            return .systemAction
        })
        .sheet(item: $safari) { SafariView(url: $0).ignoresSafeArea() }
    }

    private func content(_ model: ReportModel) -> some View {
        let a = model.address
        let K = store.kommun(a)
        let plans = store.plans(for: a)
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ReportMapView(model: model, interactive: false)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            Button { showMap = true } label: {
                                Label("Visa karta", systemImage: "arrow.up.left.and.arrow.down.right")
                                    .font(BCFont.semibold(14))
                            }
                            .buttonStyle(PillButtonStyle())
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                            .padding(12)
                        }
                        .onTapGesture { showMap = true }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Karta runt \(a.label)")
                        .accessibilityAddTraits(.isButton)

                    header(model, K)
                    sectionBar(proxy)

                    AdCard(address: a)

                    OverviewSection(model: model, plans: plans)
                        .id(ReportSection.oversikt)
                    PropertySection(model: model, plans: plans)
                        .id(ReportSection.fastighet)
                    EnvironmentSection(model: model)
                        .id(ReportSection.miljo)
                    AreaSection(model: model)
                        .id(ReportSection.omradet)
                    ServiceSection(address: a)
                        .id(ReportSection.service)
                    QuestionsSection(model: model, plans: plans)
                        .id(ReportSection.fragor)
                    SourcesSection(kommun: K)
                        .id(ReportSection.kallor)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(Theme.bg)
            .task(id: model.loading) {
                // Skärmbildsskriptet kan be om ett visst avsnitt: -uiSection miljo
                if !model.loading { Log.write("Rapport: visas") }
                if !model.loading, UserDefaults.standard.string(forKey: "uiMap") != nil { showMap = true }
                guard !model.loading, let s = UserDefaults.standard.string(forKey: "uiSection").flatMap(ReportSection.init(rawValue:)) else { return }
                try? await Task.sleep(for: .milliseconds(400))
                proxy.scrollTo(s, anchor: .top)
            }
        }
        .navigationTitle(a.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    user.toggleSaved(a.key)
                } label: {
                    Image(systemName: user.isSaved(a.key) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(user.isSaved(a.key) ? "Ta bort från sparade" : "Spara adressen")
                ShareLink(item: URL(string: AppConfig.portal.absoluteString + "#a\(a.id)")!,
                          subject: Text(a.label),
                          message: Text("\(a.label), \(K.namn). Detaljplaner, miljö och närservice i Buyers Choice.")) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Dela")
            }
        }
        .fullScreenCover(isPresented: $showMap) {
            FullMapView(model: model)
        }
    }

    private func header(_ model: ReportModel, _ K: Kommun) -> some View {
        let a = model.address
        let po = store.street(a).postort
        return VStack(alignment: .leading, spacing: 10) {
            Eyebrow((po != K.namn ? po + ", " : "") + K.namn)
            FitText(a.label, sizes: [34, 30, 26, 22]) { BCFont.display($0, .largeTitle) }
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { reportInfo.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text("Grundrapport")
                        Image(systemName: reportInfo ? "questionmark.circle.fill" : "questionmark.circle")
                    }
                    .font(BCFont.medium(12, .caption)).foregroundStyle(Theme.muted)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.subtle, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Förklarar vad en grundrapport är")
                if let f = model.row?.fastighet { Tag(text: f, fill: Theme.accentSoft, fg: Theme.accent) }
            }
            if reportInfo {
                Notice(text: "Grundrapporten finns för alla adresser och bygger på öppna data om platsen: gällande planer, miljö, planer i området och närservice. Det som saknas är en tolkning av detaljplanens bestämmelser för just din fastighet, till exempel byggrätt, högsta höjd och prickmark. Bestämmelserna står i plankartan som PDF och tolkas i dag för hand, så det finns bara för exempeladressen i portalen. Tills vidare når du plankartan under Fastighet och detaljplan.")
                    .transition(.opacity)
            }
        }
    }

    private func sectionBar(_ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ReportSection.allCases.dropFirst()) { s in
                    Button(s.title) {
                        withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(s, anchor: .top) }
                    }
                    .font(BCFont.medium(14))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Theme.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.line))
                }
            }
        }
        .scrollClipDisabled()
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
