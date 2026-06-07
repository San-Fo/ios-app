import Foundation

/// A typed description of a single API request.
///
/// Concrete endpoints are declared in `Sources/Networking/Endpoints/` per
/// domain. This is the single place to plug in the real backend contract:
/// set `path`, `method`, `query` and `body` and the client handles the rest.
struct Endpoint<Response: Decodable> {
    var path: String
    var method: HTTPMethod
    var query: [URLQueryItem]
    var body: Data?
    var headers: [String: String]
    /// Whether the request must carry the auth bearer token.
    var requiresAuth: Bool

    init(
        path: String,
        method: HTTPMethod = .get,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        headers: [String: String] = [:],
        requiresAuth: Bool = true
    ) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
        self.headers = headers
        self.requiresAuth = requiresAuth
    }
}

extension Endpoint {
    /// Convenience for endpoints that send a Codable JSON body.
    static func json<Body: Encodable>(
        path: String,
        method: HTTPMethod,
        body: Body,
        requiresAuth: Bool = true,
        encoder: JSONEncoder = .lbiDefault
    ) throws -> Endpoint<Response> {
        let data: Data
        do {
            data = try encoder.encode(body)
        } catch {
            throw APIError.invalidRequest("Failed to encode request body: \(error)")
        }
        return Endpoint(
            path: path,
            method: method,
            body: data,
            headers: ["Content-Type": "application/json"],
            requiresAuth: requiresAuth
        )
    }
}
