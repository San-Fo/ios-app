import Foundation

/// Filters for discovery/search.
struct BusinessQuery: Equatable {
    var text: String = ""
    var categories: Set<BusinessCategory> = []
    var districts: Set<District> = []
    var fundingKinds: Set<FundingKind> = []
}

/// Provides business discovery, search and detail.
protocol BusinessRepository: Sendable {
    func recommended(for profile: UserProfile?) async throws -> [Business]
    func list(query: BusinessQuery) async throws -> [Business]
    func detail(id: String) async throws -> BusinessDetail
}

// MARK: - Live (placeholder)

/// Live implementation. Wire the real endpoints in `BusinessEndpoints` and map
/// the DTOs to domain models here once the backend is ready.
final class LiveBusinessRepository: BusinessRepository, @unchecked Sendable {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func recommended(for profile: UserProfile?) async throws -> [Business] {
        let dtos = try await client.send(BusinessEndpoints.recommended())
        return dtos.map { $0.toSummary() }
    }

    func list(query: BusinessQuery) async throws -> [Business] {
        let dtos = try await client.send(BusinessEndpoints.search(query: query))
        return dtos.map { $0.toSummary() }
    }

    func detail(id: String) async throws -> BusinessDetail {
        let dto = try await client.send(BusinessEndpoints.detail(id: id))
        return dto.toDetail()
    }
}

// MARK: - Mock

/// ⚠️ MOCK — in-memory business data (see `SampleData`). No backend.
/// Active only when `APIConfiguration.useMockData == true`.
final class MockBusinessRepository: BusinessRepository, @unchecked Sendable {
    init() { MockMarker.hit(.mock, "MockBusinessRepository", "discover/search/detail use SampleData") }

    func recommended(for profile: UserProfile?) async throws -> [Business] {
        MockMarker.hit(.mock, "MockBusinessRepository.recommended")
        let all = SampleData.summaries
        guard let profile, !profile.interests.isEmpty || !profile.districts.isEmpty else {
            return all
        }
        // Preferences only affect RANKING — no business is ever filtered out.
        // Enumerate to keep a stable order for equally-scored businesses.
        let ranked = all.enumerated().sorted { lhs, rhs in
            let lScore = score(lhs.element, profile)
            let rScore = score(rhs.element, profile)
            if lScore != rScore { return lScore > rScore }
            return lhs.offset < rhs.offset
        }
        return ranked.map(\.element)
    }

    func list(query: BusinessQuery) async throws -> [Business] {
        MockMarker.hit(.mock, "MockBusinessRepository.list")
        return SampleData.summaries.filter { business in
            let matchesText = query.text.isEmpty
                || business.name.localizedCaseInsensitiveContains(query.text)
                || business.storyHeadline.localizedCaseInsensitiveContains(query.text)
            let matchesCategory = query.categories.isEmpty || query.categories.contains(business.category)
            let matchesDistrict = query.districts.isEmpty || query.districts.contains(business.district)
            let matchesFunding = query.fundingKinds.isEmpty
                || !business.fundingOptions.isDisjoint(with: query.fundingKinds)
            return matchesText && matchesCategory && matchesDistrict && matchesFunding
        }
    }

    func detail(id: String) async throws -> BusinessDetail {
        MockMarker.hit(.mock, "MockBusinessRepository.detail")
        guard let detail = SampleData.detail(for: id) else { throw APIError.notFound }
        return detail
    }

    private func score(_ business: Business, _ profile: UserProfile) -> Int {
        var score = 0
        if profile.interests.contains(business.category) { score += 2 }
        if profile.districts.contains(business.district) { score += 1 }
        return score
    }
}
