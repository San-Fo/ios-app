import Foundation

/// API endpoints for business discovery, search and detail.
///
/// TODO(API): confirm paths, query params and pagination with the backend team.
/// This is the single place to wire the business contract.
enum BusinessEndpoints {
    static func recommended() -> Endpoint<[BusinessDTO]> {
        Endpoint(path: "businesses/recommended", method: .get)
    }

    static func list(query: BusinessQuery) -> Endpoint<[BusinessDTO]> {
        var items: [URLQueryItem] = []
        if !query.text.isEmpty {
            items.append(URLQueryItem(name: "q", value: query.text))
        }
        for category in query.categories {
            items.append(URLQueryItem(name: "category", value: category.rawValue))
        }
        for district in query.districts {
            items.append(URLQueryItem(name: "district", value: district.rawValue))
        }
        for kind in query.fundingKinds {
            items.append(URLQueryItem(name: "funding", value: kind.rawValue))
        }
        return Endpoint(path: "businesses", method: .get, query: items)
    }

    static func detail(id: String) -> Endpoint<BusinessDetailDTO> {
        Endpoint(path: "businesses/\(id)", method: .get)
    }
}
