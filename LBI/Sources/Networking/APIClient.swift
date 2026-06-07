import Foundation

/// Performs typed API requests.
protocol APIClient: Sendable {
    func send<Response: Decodable>(_ endpoint: Endpoint<Response>) async throws -> Response
}

extension APIClient {
    /// For endpoints with no meaningful response body.
    func send(_ endpoint: Endpoint<EmptyResponse>) async throws {
        _ = try await send(endpoint) as EmptyResponse
    }
}

/// Represents an empty/ignored response body.
struct EmptyResponse: Decodable {}

/// Live URLSession-based client. This is the production path.
final class LiveAPIClient: APIClient, @unchecked Sendable {
    private let configuration: APIConfiguration
    private let session: URLSession
    private let tokenStore: TokenStore
    private let decoder: JSONDecoder

    init(
        configuration: APIConfiguration,
        tokenStore: TokenStore,
        session: URLSession = .shared,
        decoder: JSONDecoder = .lbiDefault
    ) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.session = session
        self.decoder = decoder
    }

    func send<Response: Decodable>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let request = try makeRequest(for: endpoint)

        AuthInterceptor.logOutgoing(request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.transport(error.localizedDescription)
        } catch {
            throw APIError.unknown
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        try validate(status: http.statusCode, data: data)

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func makeRequest<Response>(for endpoint: Endpoint<Response>) throws -> URLRequest {
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        )
        if !endpoint.query.isEmpty {
            components?.queryItems = endpoint.query
        }
        guard let url = components?.url else {
            throw APIError.invalidRequest("Could not build URL for path \(endpoint.path)")
        }

        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if endpoint.requiresAuth {
            try AuthInterceptor.authorize(&request, tokenStore: tokenStore)
        }
        return request
    }

    private func validate(status: Int, data: Data) throws {
        switch status {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        default:
            // The backend returns `{ "error": "<message>" }` for handled
            // errors; framework-level rejections (e.g. 422 for malformed
            // bodies) may not carry this shape, hence the optional decode.
            let message = (try? decoder.decode(ServerErrorBody.self, from: data))?.error
            throw APIError.server(status: status, message: message)
        }
    }
}

/// Standard error envelope returned by the backend: `{ "error": "<message>" }`.
private struct ServerErrorBody: Decodable {
    let error: String?
}
