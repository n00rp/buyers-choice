import SwiftUI

@main
struct BuyersChoiceApp: App {
    @State private var store = DataStore()
    @State private var user = UserStore()

    init() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = UIColor(Theme.bg)
        nav.titleTextAttributes = [.font: UIFont(name: "Inter-SemiBold", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold), .foregroundColor: UIColor(Theme.text)]
        nav.largeTitleTextAttributes = [.font: UIFont(name: "Fraunces-SemiBold", size: 34) ?? .systemFont(ofSize: 34, weight: .bold), .foregroundColor: UIColor(Theme.text)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(Theme.accent)

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.backgroundColor = UIColor(Theme.bg).withAlphaComponent(0.92)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(user)
                .preferredColorScheme(.light)
                .tint(Theme.accent)
                .task { await store.load() }
        }
    }
}

struct RootView: View {
    @Environment(DataStore.self) private var store
    @State private var tab = Tab.search
    @State private var searchPath = NavigationPath()
    @State private var savedPath = NavigationPath()

    enum Tab { case search, saved, about }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $searchPath) {
                SearchView { searchPath.append(AddressRoute(id: $0.id)) }
                    .navigationDestination(for: AddressRoute.self) { ReportView(addressID: $0.id) }
            }
            .tabItem { Label("Sök", systemImage: "magnifyingglass") }
            .tag(Tab.search)

            NavigationStack(path: $savedPath) {
                SavedView()
                    .navigationDestination(for: AddressRoute.self) { ReportView(addressID: $0.id) }
            }
            .tabItem { Label("Sparade", systemImage: "bookmark") }
            .tag(Tab.saved)

            NavigationStack {
                AboutView()
            }
            .tabItem { Label("Om", systemImage: "info.circle") }
            .tag(Tab.about)
        }
        .onChange(of: store.isReady) { _, ready in
            // Används av skärmbildsskriptet i molnbygget: -uiOpen "Linnégatan 20" -uiSection miljo
            guard ready, let key = UserDefaults.standard.string(forKey: "uiOpen"), let a = store.address(key: key) else { return }
            searchPath.append(AddressRoute(id: a.id))
        }
        .onOpenURL { url in
            // buyerschoice://a<nummer> eller portalens #a<nummer>
            let s = url.absoluteString
            if let r = s.range(of: #"a(\d+)$"#, options: .regularExpression), let n = Int(s[r].dropFirst()), store.addresses.indices.contains(n) {
                tab = .search
                searchPath.append(AddressRoute(id: n))
            }
        }
    }
}

struct AddressRoute: Hashable { let id: Int }
