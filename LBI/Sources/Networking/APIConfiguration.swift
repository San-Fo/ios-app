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

        /// Base URLs. Local dev points at the backend's default bind
        /// (`0.0.0.0:3000`). Staging/production hosts are placeholders until
        /// the backend team provides them.
        var baseURL: URL {
            switch self {
            case .development:
                return URL(string: "http://localhost:3000/api/v1")!
            case .staging:
                return URL(string: "https://staging.api.sanfo.example/api/v1")!
            case .production:
                return URL(string: "https://api.sanfo.example/api/v1")!
            }
        }
    }

    /// The active environment.
    var environment: Environment

    /// When `true`, repositories use in-memory mock implementations instead of
    /// hitting the network. This exists ONLY for development, SwiftUI previews
    /// and tests. The production path never enables this.
    var useMockData: Bool

    /// Default request timeout in seconds.
    var timeout: TimeInterval

    var baseURL: URL { environment.baseURL }

    static let live = APIConfiguration(
        environment: .development,
        useMockData: true, // TODO(API): flip to `false` once real endpoints exist.
        timeout: 30
    )

    /// Configuration used by previews and unit tests.
    static let preview = APIConfiguration(
        environment: .development,
        useMockData: true,
        timeout: 30
    )
}
