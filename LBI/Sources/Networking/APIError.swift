import Foundation

/// Errors surfaced by the networking layer.
enum APIError: Error, Equatable {
    /// The request could not be constructed (bad URL, encoding failure, ...).
    case invalidRequest(String)
    /// The transport failed (no connection, timeout, ...).
    case transport(String)
    /// The server returned a non-2xx status code.
    case server(status: Int, message: String?)
    /// The response body could not be decoded into the expected type.
    case decoding(String)
    /// Authentication is required or the session expired (401).
    case unauthorized
    /// The user is authenticated but not allowed (403).
    case forbidden
    /// The requested resource was not found (404).
    case notFound
    /// Any other unexpected condition.
    case unknown

    /// A friendly, user-presentable message for each error case. The raw
    /// associated values (URLs, decoding details) are intentionally not shown
    /// to users and are kept only for logging/diagnostics.
    var userMessage: String {
        switch self {
        case .invalidRequest:
            return "Something went wrong preparing your request."
        case .transport:
            return "We couldn't reach the server. Please check your connection."
        case let .server(_, message):
            return message ?? "The server ran into a problem. Please try again."
        case .decoding:
            return "We received an unexpected response from the server."
        case .unauthorized:
            return "Please sign in to continue."
        case .forbidden:
            return "You don't have access to this."
        case .notFound:
            return "We couldn't find what you were looking for."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}
