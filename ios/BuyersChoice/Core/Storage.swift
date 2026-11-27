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

    init() {
        saved = d.stringArray(forKey: "bc-saved") ?? []
        recent = d.stringArray(forKey: "bc-recent") ?? []
        ads = d.dictionary(forKey: "bc-ads") as? [String: String] ?? [:]
        checked = Set(d.stringArray(forKey: "bc-q") ?? [])
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
}
