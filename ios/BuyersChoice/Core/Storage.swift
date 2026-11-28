import Foundation
import Observation

/// Det användaren sparar: adresser, senaste sökningar, annonslänkar och bockade frågor.
/// Allt ligger bara på telefonen (UserDefaults) och skickas ingenstans.
@MainActor
@Observable
final class UserStore {
    private let d = UserDefaults.standard

    private(set) var saved: [String] = []
    private(set) var recent: [String] = []
    private var ads: [String: String] = [:]
    private var checked: Set<String> = []
    private var forms: [String: String] = [:]

    init() {
        saved = d.stringArray(forKey: "bc-saved") ?? []
        recent = d.stringArray(forKey: "bc-recent") ?? []
        ads = d.dictionary(forKey: "bc-ads") as? [String: String] ?? [:]
        checked = Set(d.stringArray(forKey: "bc-q") ?? [])
        forms = d.dictionary(forKey: "bc-form") as? [String: String] ?? [:]
    }

    // MARK: Sparade

    func isSaved(_ key: String) -> Bool { saved.contains(key) }

    func toggleSaved(_ key: String) {
        if let i = saved.firstIndex(of: key) { saved.remove(at: i) } else { saved.insert(key, at: 0) }
        d.set(saved, forKey: "bc-saved")
    }

    func removeSaved(at offsets: IndexSet) {
        saved.remove(atOffsets: offsets)
        d.set(saved, forKey: "bc-saved")
    }

    // MARK: Senaste

    func visited(_ key: String) {
        recent.removeAll { $0 == key }
        recent.insert(key, at: 0)
        if recent.count > 8 { recent = Array(recent.prefix(8)) }
        d.set(recent, forKey: "bc-recent")
    }

    func clearRecent() {
        recent = []
        d.removeObject(forKey: "bc-recent")
    }

    // MARK: Annonser

    func ad(for key: String) -> AdLink? { ads[key].flatMap(AdLink.parse) }

    func setAd(_ link: AdLink?, for key: String) {
        ads[key] = link?.url.absoluteString
        d.set(ads, forKey: "bc-ads")
    }

    // MARK: Frågor till visningen

    func isChecked(_ key: String, _ q: String) -> Bool { checked.contains(key + "|" + q) }

    func toggleChecked(_ key: String, _ q: String) {
        let k = key + "|" + q
        if checked.contains(k) { checked.remove(k) } else { checked.insert(k) }
        d.set(Array(checked), forKey: "bc-q")
    }

    // MARK: Boendeform

    func form(_ key: String) -> Boendeform? {
        // Skärmbildsskriptet kan välja boendeform: -uiForm bostadsratt
        (forms[key] ?? d.string(forKey: "uiForm")).flatMap(Boendeform.init(rawValue:))
    }

    func setForm(_ f: Boendeform?, for key: String) {
        forms[key] = f?.rawValue
        d.set(forms, forKey: "bc-form")
    }
}

/// Vilken sorts bostad det gäller. Adressdatan säger inte det, så användaren väljer.
enum Boendeform: String, CaseIterable, Identifiable {
    case villa, bostadsratt, hyresratt
    var id: String { rawValue }
    var title: String {
        switch self {
        case .villa: return "Villa eller radhus"
        case .bostadsratt: return "Bostadsrätt"
        case .hyresratt: return "Hyresrätt"
        }
    }
    var short: String {
        switch self {
        case .villa: return "Villa/radhus"
        case .bostadsratt: return "Bostadsrätt"
        case .hyresratt: return "Hyresrätt"
        }
    }
}
