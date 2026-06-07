import Foundation

/// Device-local, durable store for bookmarked (saved) business ids.
///
/// Bookmarking must work regardless of session state — including the offline
/// local-only guest and when the backend save endpoint is unavailable — so the
/// set of saved ids is persisted in `UserDefaults` and used as the source of
/// truth for the UI. When a real backend session exists, `ProfileStore` also
/// best-effort mirrors changes to the server, but the local store is what makes
/// saves survive relaunches in every case.
struct LocalBookmarkStore {
    private let defaults: UserDefaults
    private let key = "lbi.savedBusinessIds"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// All currently-saved business ids.
    func all() -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    func contains(_ id: String) -> Bool {
        all().contains(id)
    }

    /// Adds or removes an id and returns the new saved state (`true` = saved).
    @discardableResult
    func toggle(_ id: String) -> Bool {
        var ids = all()
        let nowSaved: Bool
        if ids.contains(id) {
            ids.remove(id)
            nowSaved = false
        } else {
            ids.insert(id)
            nowSaved = true
        }
        save(ids)
        return nowSaved
    }

    /// Merges additional ids (e.g. from the server) into the local set.
    func merge(_ ids: Set<String>) {
        save(all().union(ids))
    }

    private func save(_ ids: Set<String>) {
        defaults.set(Array(ids), forKey: key)
    }
}
