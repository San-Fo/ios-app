import Foundation
import os

/// Central, loud marker for any code path that returns MOCK / PLACEHOLDER /
/// DERIVED data instead of real backend data.
///
/// Why this exists: the app must be trivially auditable for "is this real data
/// or not". Every mock/stub/derived value funnels through `MockMarker`, which:
/// - logs a 🟠 warning to the unified log (subsystem `dev.tuist.LBI`,
///   category `mock`) the first time each unique site fires, and
/// - exposes `firedSites` so a debug overlay / test can assert nothing mock
///   ran during a "real data" session.
///
/// When `APIConfiguration.useMockData == false` and the backend is fully wired,
/// **no `MockMarker` site for network data should ever fire.** The remaining
/// allowed sites are `.derived` (client-derived display fields the backend
/// intentionally does not provide) — those are expected and clearly tagged.
enum MockMarker {
    enum Kind: String {
        /// In-memory fake data with no backend behind it.
        case mock = "MOCK"
        /// A hard-coded stand-in awaiting a real backend field/endpoint.
        case placeholder = "PLACEHOLDER"
        /// A value computed on the client because the backend does not (and
        /// will not) provide it. Expected even on the real-data path.
        case derived = "DERIVED"
        /// A feature with no backend endpoint yet; the call is a no-op/echo.
        case noBackend = "NO_BACKEND"
    }

    private static let logger = Logger(subsystem: "dev.tuist.LBI", category: "mock")
    private static let lock = NSLock()
    private static var seen = Set<String>()
    /// All marker sites that have fired this session (for debug/tests).
    private(set) static var firedSites: [String] = []

    /// Records that a mock/placeholder/derived site executed. Logs once per
    /// unique `site` so the console isn't flooded.
    @discardableResult
    static func hit(_ kind: Kind, _ site: String, _ detail: String = "") -> Bool {
        lock.lock()
        let isNew = seen.insert(site).inserted
        if isNew { firedSites.append(site) }
        lock.unlock()

        if isNew {
            let suffix = detail.isEmpty ? "" : " — \(detail)"
            logger.warning("🟠 \(kind.rawValue, privacy: .public) [\(site, privacy: .public)]\(suffix, privacy: .public)")
        }
        return isNew
    }

    /// Returns `value` after marking the site. Use to wrap a single placeholder
    /// expression inline, e.g. `MockMarker.value(0, .derived, "Sale.fundingRaised")`.
    static func value<T>(_ value: T, _ kind: Kind, _ site: String, _ detail: String = "") -> T {
        hit(kind, site, detail)
        return value
    }

    /// Test/debug helper: clears recorded sites.
    static func reset() {
        lock.lock(); defer { lock.unlock() }
        seen.removeAll()
        firedSites.removeAll()
    }
}
