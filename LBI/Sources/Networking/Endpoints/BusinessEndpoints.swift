import Foundation

/// API endpoints for business discovery, search and detail.
///
/// The backend returns the same `Business` shape (with `sale` folded in and
/// confidential fields redacted per viewer) for list/search/detail/saved.
enum BusinessEndpoints {
    /// Verified businesses matching the user's followed categories/intents,
    /// ranked by proximity then popularity. Excludes the caller's own listings.
    static func recommended(limit: Int = 20) -> Endpoint<[BusinessDTO]> {
        Endpoint(
            path: "businesses/recommended",
            method: .get,
            query: [URLQueryItem(name: "limit", value: String(limit))]
        )
    }

    /// Public full-text search + filters. Verified listings only.
    /// Supported params: `q`, `category` (single), `lat`/`lng`, `radius`, `limit`.
    static func search(query: BusinessQuery, limit: Int = 20) -> Endpoint<[BusinessDTO]> {
        var items: [URLQueryItem] = []
        if !query.text.isEmpty {
            items.append(URLQueryItem(name: "q", value: query.text))
        }
        // The backend accepts a single category filter; send the first selected.
        if let category = query.categories.first {
            items.append(URLQueryItem(name: "category", value: category.serverValue))
        }
        items.append(URLQueryItem(name: "limit", value: String(limit)))
        return Endpoint(path: "businesses/search", method: .get, query: items, requiresAuth: false)
    }

    /// Business detail (auth optional). Increments the view count for non-owners.
    static func detail(id: String) -> Endpoint<BusinessDTO> {
        Endpoint(path: "businesses/\(id)", method: .get)
    }

    /// The caller's own listings (all statuses).
    static func mine() -> Endpoint<[BusinessDTO]> {
        Endpoint(path: "me/businesses", method: .get)
    }

    /// Owner edit of limited fields (`PATCH /businesses/{id}`). Only the
    /// non-critical `description` is editable from the app.
    static func update(id: String, description: String) throws -> Endpoint<BusinessDTO> {
        try .json(path: "businesses/\(id)", method: .patch, body: UpdateBody(description: description))
    }

    /// Increments the like count (not allowed on your own business).
    static func like(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "businesses/\(id)/like", method: .post)
    }

    private struct UpdateBody: Encodable {
        let description: String
    }
}
