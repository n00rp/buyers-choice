import Foundation
import Observation

enum AppConfig {
    /// Portalens adress. Appen läser samma förberäknade JSON-filer som portalen.
    static let dataBase = URL(string: "https://n00rp.github.io/buyers-choice/")!
    static let portal = URL(string: "https://n00rp.github.io/buyers-choice/")!
}

/// Hämtar filer från portalen. Svaren sparas i URLCache, så appen fungerar utan nät när filerna har hämtats en gång.
actor Remote {
    static let shared = Remote()

    private let session: URLSession
    private var inflight: [String: Task<Data, Error>] = [:]

    init() {
        let cache = URLCache(memoryCapacity: 32 << 20, diskCapacity: 300 << 20, directory: nil)
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = cache
        cfg.requestCachePolicy = .useProtocolCachePolicy
        cfg.timeoutIntervalForRequest = 20
        session = URLSession(configuration: cfg)
    }

    func data(_ path: String) async throws -> Data {
        if let t = inflight[path] { return try await t.value }
        let session = self.session
        let t = Task<Data, Error> {
            let url = AppConfig.dataBase.appendingPathComponent(path)
            do {
                let (d, resp) = try await session.data(from: url)
                if let h = resp as? HTTPURLResponse, h.statusCode != 200 { throw DataError.http(path, h.statusCode) }
                return d
            } catch {
                // Utan nät: använd senast hämtade version om den finns.
                var req = URLRequest(url: url)
                req.cachePolicy = .returnCacheDataDontLoad
                if let cached = session.configuration.urlCache?.cachedResponse(for: req) { return cached.data }
                throw error
            }
        }
        inflight[path] = t
        defer { inflight[path] = nil }
        return try await t.value
    }
}

@MainActor
@Observable
final class DataStore {
    enum State: Equatable { case idle, loading, ready, failed(String) }

    var state: State = .idle
    private(set) var addresses: [Address] = []
    private(set) var streets: [Street] = []
    private(set) var streetMap: [String: [Int]] = [:]
    private(set) var kommuner: [Parse.KommunData] = []

    @ObservationIgnored private var envMetaCache: [Int: EnvMeta] = [:]
    @ObservationIgnored private var shardCache: [String: [Any]] = [:]
    @ObservationIgnored private var futureCache: [Int: FutureData] = [:]
    @ObservationIgnored private var planWorkCache: PlanWorkData?

    var isReady: Bool { state == .ready }
    var totalCount: Int { addresses.count }

    func load() async {
        if state == .ready || state == .loading { return }
        state = .loading
        do {
            let files: [(adresser: Data, planer: Data, service: Data)] = try await withThrowingTaskGroup(of: (Int, Data, Data, Data).self) { g in
                for (i, K) in Kommun.all.enumerated() {
                    g.addTask {
                        async let a = Remote.shared.data(K.dir + "adresser.json")
                        async let p = Remote.shared.data(K.dir + "planer.json")
                        async let s = Remote.shared.data(K.dir + "service.json")
                        return try await (i, a, p, s)
                    }
                }
                var out: [(Int, Data, Data, Data)] = []
                for try await r in g { out.append(r) }
                return out.sorted { $0.0 < $1.0 }.map { (adresser: $0.1, planer: $0.2, service: $0.3) }
            }
            let ds = try await Task.detached(priority: .userInitiated) { try Parse.dataset(files: files) }.value
            addresses = ds.addresses
            streets = ds.streets
            streetMap = ds.streetMap
            kommuner = ds.kommuner
            state = .ready
        } catch {
            state = .failed("Adresserna kunde inte hämtas. Kontrollera att du är ansluten till internet och försök igen.")
        }
    }

    func retry() async {
        state = .idle
        await load()
    }

    // MARK: Uppslag

    func kommun(_ a: Address) -> Kommun { Kommun.all[a.kommun] }
    func street(_ a: Address) -> Street { streets[a.street] }
    func service(_ a: Address) -> Service { kommuner[a.kommun].service }

    func address(key: String) -> Address? {
        var km = 0
        var label = key
        if let colon = key.firstIndex(of: ":"), let i = Kommun.all.firstIndex(where: { $0.namn == String(key[..<colon]) }) {
            km = i
            label = String(key[key.index(after: colon)...])
        }
        guard kommuner.indices.contains(km) else { return nil }
        let K = kommuner[km]
        return addresses[K.base..<(K.base + K.count)].first { $0.label == label }
    }

    func plans(for a: Address) -> [PlanInfo] {
        let K = kommuner[a.kommun]
        return a.plans.compactMap { i -> PlanInfo? in
            guard K.plans.indices.contains(i) else { return nil }
            let r = K.plans[i]
            let t = PlanInfo.types[r.typ] ?? (.plan, "")
            let url = r.url.isEmpty ? nil : URL(string: r.url.hasPrefix("http") ? r.url : K.pfx + r.url)
            return PlanInfo(bet: r.bet, typ: r.typ, name: Txt.prettyName(r.name),
                            url: url.flatMap { $0.scheme == "https" ? $0 : nil },
                            besk: URL(string: r.besk).flatMap { $0.scheme == "https" ? $0 : nil },
                            lagaKraft: r.lk, group: t.0, about: t.1)
        }
        .sorted { $0.group.rawValue < $1.group.rawValue }
    }

    func nearby(_ places: [Place], to a: Address, limit: Int, within: Int? = nil, where f: ((Place) -> Bool)? = nil) -> [Nearby] {
        var out = places.lazy.filter { f?($0) ?? true }.map { Nearby(place: $0, m: Int(hypot($0.e - a.e, $0.n - a.n).rounded())) }
            .filter { within == nil || $0.m <= within! }
            .sorted { $0.m < $1.m }
        if out.count > limit { out = Array(out.prefix(limit)) }
        return out
    }

    /// Närmaste adress till en punkt, för "Adressen här".
    func nearestAddress(e: Double, n: Double, maxMeters: Double = 300) -> Address? {
        var best: Address?
        var bestD = maxMeters * maxMeters
        for a in addresses {
            let dx = a.e - e, dy = a.n - n
            let d = dx * dx + dy * dy
            if d < bestD { bestD = d; best = a }
        }
        return best
    }

    // MARK: Data per adress

    func env(for a: Address) async throws -> (EnvMeta, EnvRow) {
        let K = Kommun.all[a.kommun]
        let meta: EnvMeta
        if let m = envMetaCache[a.kommun] { meta = m } else {
            meta = try Parse.envMeta(try await Remote.shared.data(K.dir + "miljo-meta.json"))
            envMetaCache[a.kommun] = meta
        }
        let path = K.dir + "m/\(a.local / meta.block).json"
        let rows: [Any]
        if let r = shardCache[path] { rows = r } else {
            let d = try await Remote.shared.data(path)
            rows = try await Task.detached { try Parse.json(d) as? [Any] ?? [] }.value
            if shardCache.count > 6 { shardCache.removeAll() }
            shardCache[path] = rows
        }
        let i = a.local % meta.block
        return (meta, Parse.envRow(i < rows.count ? rows[i] : nil))
    }

    func future(for a: Address) async throws -> FutureData {
        if let f = futureCache[a.kommun] { return f }
        let d = try await Remote.shared.data(Kommun.all[a.kommun].dir + "framtid.json")
        let f = try await Task.detached { try Parse.future(d) }.value
        futureCache[a.kommun] = f
        return f
    }

    func planWork() async -> PlanWorkData? {
        if let p = planWorkCache { return p }
        guard let d = try? await Remote.shared.data("bevakning/planarbete.json"), let p = try? Parse.planWork(d) else { return nil }
        planWorkCache = p
        return p
    }
}
