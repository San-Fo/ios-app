import Foundation
import os

/// Cross-cutting request concerns: attaching the bearer token and logging.
enum AuthInterceptor {
    /// Attaches the session bearer token to an authenticated request.
    /// Throws `.unauthorized` if no token is available.
    static func authorize(_ request: inout URLRequest, tokenStore: TokenStore) throws {
        guard let token = tokenStore.currentToken() else {
            throw APIError.unauthorized
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private static let logger = Logger(subsystem: "dev.tuist.LBI", category: "network")

    static func logOutgoing(_ request: URLRequest) {
        #if DEBUG
        logger.debug("→ \(request.httpMethod ?? "?", privacy: .public) \(request.url?.absoluteString ?? "?", privacy: .public)")
        #endif
    }
}
