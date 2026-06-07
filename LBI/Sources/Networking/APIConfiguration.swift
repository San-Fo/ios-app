import Foundation

/// Runtime configuration for the networking layer.
///
/// The real backend is provided by another team. When their endpoints are
/// ready, set the `baseURL` for each environment below — no other change in
/// the networking layer should be required.
struct APIConfiguration {
    enum Environment {
        case development
        case staging
        case production

        /// Base URLs. Development points at the hosted backend behind the proxy.
        /// (Spec: base URL is `<host>/api/v1`.)
        var baseURL: URL {
            switch self {
            case .development:
                return URL(string: "https://lbi.proxied.zone/api/v1")!
            case .staging:
                return URL(string: "https://lbi.proxied.zone/api/v1")!
            case .production:
                return URL(string: "https://lbi.proxied.zone/api/v1")!
            }
        }
    }

    /// The active environment.
    var environment: Environment

    /// ⚠️ MASTER MOCK SWITCH.
    /// When `true`, EVERY repository uses in-memory mock data (see the `Mock*`
    /// classes) and NOTHING hits the backend. Flip to `false` to use the real
    /// API. While `true`, the app prints a loud banner at launch and each mock
    /// path logs via `MockMarker`. The production build must ship with `false`.
    var useMockData: Bool

    /// Default request timeout in seconds.
    var timeout: TimeInterval

    var baseURL: URL { environment.baseURL }

    static let live = APIConfiguration(
        environment: .development,
        // ⚠️ MOCK MODE IS ON. The app is running entirely on in-memory sample
        // data — no request reaches the backend. Set this to `false` to switch
        // every repository to the real API (`LiveAPIClient` + `Live*Repository`).
        useMockData: true,
        timeout: 30
    )

    /// Configuration used by previews and unit tests.
    static let preview = APIConfiguration(
        environment: .development,
        useMockData: true,
        timeout: 30
    )
}
