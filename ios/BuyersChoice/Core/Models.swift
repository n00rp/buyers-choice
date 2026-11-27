import Foundation
import CoreLocation

// MARK: - Kommuner

/// Motsvarar `KOM` i portal/index.html. Ordningen är densamma, så adressnumren blir lika.
struct Kommun: Identifiable, Hashable {
    enum Feature: String { case vagar, miljo, op, stops, shops, planarbete, geoteknik, projekt }

    let id: String
    let namn: String
    let dir: String
    let org: String
    let hamtad: String
    let har: Set<Feature>
    var karta: URL? = nil
    var plansida: URL? = nil
    var saknas: String? = nil

    func has(_ f: Feature) -> Bool { har.contains(f) }

    /// "stadens" för Göteborg, "kommunens" för övriga.
    var genitiv: String { has(.miljo) ? "stadens" : "kommunens" }

    static let all: [Kommun] = [
        Kommun(id: "goteborg", namn: "Göteborg", dir: "", org: "Göteborgs Stad", hamtad: "2026-11-25",
               har: [.vagar, .miljo, .op, .stops, .shops, .planarbete]),
        Kommun(id: "partille", namn: "Partille", dir: "k/partille/", org: "Partille kommun", hamtad: "2026-11-27",
               har: [.vagar, .geoteknik, .projekt],
               karta: URL(string: "https://geodata.partille.se/portal/apps/experiencebuilder/experience/?id=474d7df7acca4470aa21f7092a467c70"),
               plansida: URL(string: "https://www.partille.se/bygga-bo--miljo/samhallsplanering/pagaende-detaljplanering/"),
               saknas: "trafikbuller, luftkvalitet, skyfall, översvämning, markradon och förorenad mark"),
    ]
}

// MARK: - Adresser

struct Street {
    let name: String
    let folded: String
    let first: Int
    let count: Int
    let kommun: Int
    let postort: String
}

struct Address: Identifiable, Hashable {
    let id: Int          // plats i den sammanslagna listan, samma som #a<nummer> i portalen
    let label: String
    let street: Int
    let kommun: Int
    let local: Int       // plats inom kommunens lista, används för miljödatafilerna
    let nr: String
    let e: Double
    let n: Double
    let plans: [Int]

    var coordinate: CLLocationCoordinate2D { Sweref.toWGS84(e: e, n: n) }

    /// Nyckel som inte ändras när datan byggs om, för sparade adresser och anteckningar.
    var key: String { kommun == 0 ? label : "\(Kommun.all[kommun].namn):\(label)" }

    static func == (l: Address, r: Address) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

// MARK: - Planer

struct PlanRecord {
    let bet: String
    let typ: String
    let name: String
    let url: String
    let besk: String
    let lk: String
}

struct PlanInfo: Identifiable {
    enum Group: Int, CaseIterable {
        case plan, fast, omr
        var title: String {
            switch self {
            case .plan: return "Detaljplaner"
            case .fast: return "Fastighetsindelning"
            case .omr: return "Områdesbestämmelser"
            }
        }
    }

    var id: String { bet }
    let bet: String
    let typ: String
    let name: String
    let url: URL?
    let besk: URL?
    let lagaKraft: String
    let group: Group
    let about: String

    var title: String { name.isEmpty ? typ : name }

    static let types: [String: (Group, String)] = [
        "Detaljplan": (.plan, "Bestämmer hur mark och byggnader får användas, till exempel vad som får byggas, hur högt och var."),
        "Stadsplan": (.plan, "Äldre plantyp från tiden före 1987. Gäller i dag som detaljplan."),
        "Byggnadsplan": (.plan, "Äldre plantyp för områden utanför stadskärnan. Gäller i dag som detaljplan."),
        "Detaljplan ändring": (.plan, "Ändrar eller kompletterar en tidigare plan på en eller flera punkter."),
        "Generalplan": (.plan, "Äldre översiktlig plan från tiden före plan- och bygglagen."),
        "Tomtindelning": (.fast, "Äldre beslut om hur kvarteret delas in i tomter. Gäller som fastighetsindelningsbestämmelse."),
        "Fastighetsplan": (.fast, "Beslut om hur marken delas in i fastigheter. Gäller som fastighetsindelningsbestämmelse."),
        "Avstyckningsplan": (.fast, "Äldre plan för hur marken delas in i tomter."),
        "Områdesbestämmelse": (.omr, "Enklare bestämmelser för ett område utan detaljplan, till exempel om kulturmiljö."),
        "Områdesbestämmelse ändring": (.omr, "Ändrar tidigare områdesbestämmelser."),
        "Enkelt planförfarande": (.plan, "Detaljplan som tagits fram med enkelt planförfarande. Gäller som andra detaljplaner."),
        "Bestämmelser": (.plan, "Särskilda bestämmelser som kompletterar en detaljplan. Plankartan visar vad de gäller."),
        "Gatuhöjder": (.plan, "Äldre beslut om gatornas höjdläge."),
    ]
}

// MARK: - Service

struct Line {
    let name: String
    let type: String
    let desc: String
}

/// En plats i närheten: hållplats, skola, förskola, butik eller apotek.
struct Place: Identifiable {
    enum Kind { case stop, school, preschool, shop, pharmacy }
    let id: String
    let kind: Kind
    let name: String
    let e: Double
    let n: Double
    var lines: [Int] = []
    var level: String = ""      // "gr" eller "gy" för skolor
    var grades: String = ""
    var address: String = ""
    var code: String = ""       // förskolans id hos Göteborgs Stad
    var subtype: String = ""
    var kommunName: String = "" // skolor och förskolor nära kommungränsen

    var coordinate: CLLocationCoordinate2D { Sweref.toWGS84(e: e, n: n) }
}

struct Service {
    var stops: [Place] = []
    var schools: [Place] = []
    var preschools: [Place] = []
    var shops: [Place] = []
    var pharmacies: [Place] = []
    var lines: [Line] = []
}

struct Nearby: Identifiable {
    let place: Place
    let m: Int
    var id: String { place.id }
}

// MARK: - Miljö per adress

struct EnvMeta {
    let leqBands: [[Int]]
    let maxBands: [[Int]]
    let radon: [String]
    let block: Int
}

enum GeoInfo {
    case covered(count: Int, latest: String?, earliest: String?)
    case nearest(Int?)
}

struct EnvRow {
    var leq: Int?
    var lmax: Int?
    var no2: Double?
    var pm10x10: Double?
    var radon: Int?
    var skyfall: Int?
    var flood: Int?
    var foro: Int?
    var flyg: Int?
    var fm: Int?
    var farligtGods: Int?
    var framtid: [(id: Int, m: Int)] = []
    var fastighet: String?
    var area: Int?
    var leqLow: Int?
    var lmaxLow: Int?
    var geo: GeoInfo?
}

// MARK: - Framtid (översiktsplan eller samhällsbyggnadsprojekt)

enum Geometry {
    case point([Double])
    case line([[Double]])
    case multiLine([[[Double]]])
    case polygon([[[Double]]])
    case multiPolygon([[[[Double]]]])
}

struct FutureFeature {
    let n: String
    let k: String
    let t: String
    let r: String
    let b: String
    let u: String
    let gb: String
    let c: String
    let a: String
    let links: [(String, String)]
    let geometry: Geometry?

    var title: String { n.isEmpty ? k : n }
}

struct FutureData {
    let src: String
    let url: String?
    let beslut: String?
    let features: [FutureFeature]
}

// MARK: - Pågående planarbete

struct PlanWork: Identifiable {
    var id: String { namn + "|\(e)|\(n)" }
    let namn: String
    let slag: String
    let steg: String
    let fas: String
    let e: Double
    let n: Double
    let lank: URL?
    let syn: (String?, String?)
    let ungefar: Bool
}

struct PlanWorkData {
    let updated: String?
    let phases: [String: String]
    let items: [PlanWork]
}
