import Foundation

/// Filters for discovery/search.
struct BusinessQuery: Equatable {
    var text: String = ""
    var categories: Set<BusinessCategory> = []
    var districts: Set<District> = []
    var fundingKinds: Set<FundingKind> = []

    /// Whether a business satisfies every selected filter dimension. Empty
    /// dimensions match everything. Used to honour filters the backend search
    /// endpoint ignores (districts, funding routes, multiple categories).
    func matches(_ business: Business) -> Bool {
        let matchesText = text.isEmpty
            || business.name.localizedCaseInsensitiveContains(text)
            || business.storyHeadline.localizedCaseInsensitiveContains(text)
        let matchesCategory = categories.isEmpty || categories.contains(business.category)
        let matchesDistrict = districts.isEmpty || districts.contains(business.district)
        let matchesFunding = fundingKinds.isEmpty
            || !business.fundingOptions.isDisjoint(with: fundingKinds)
        return matchesText && matchesCategory && matchesDistrict && matchesFunding
    }
}

/// Provides business discovery, search and detail.
protocol BusinessRepository: Sendable {
    func recommended(for profile: UserProfile?) async throws -> [Business]
    func list(query: BusinessQuery) async throws -> [Business]
    func detail(id: String) async throws -> BusinessDetail
    /// The signed-in user's own listings (all statuses).
    func myBusinesses() async throws -> [Business]
    /// Owner edits limited, non-critical fields of their own listing.
    func updateBusiness(id: String, description: String) async throws -> BusinessDetail
    /// A normal user adds a community memory under a business page.
    func addMemory(businessId: String, author: String, text: String) async throws -> CommunityMemory
    /// Posts a public question to the business owner.
    func askQuestion(businessId: String, question: String) async throws
    /// Uploads a listing photo and returns its hosted URL.
    func uploadPhoto(_ jpeg: Data) async throws -> String
}

// MARK: - Live (placeholder)

/// Live implementation. Wire the real endpoints in `BusinessEndpoints` and map
/// the DTOs to domain models here once the backend is ready.
final class LiveBusinessRepository: BusinessRepository, @unchecked Sendable {
    private let client: APIClient
    private let imageUploader: ImageUploader

    init(client: APIClient, imageUploader: ImageUploader) {
        self.client = client
        self.imageUploader = imageUploader
    }

    func recommended(for profile: UserProfile?) async throws -> [Business] {
        let dtos = try await client.send(BusinessEndpoints.recommended())
        return dtos.map { $0.toSummary() }
    }

    func list(query: BusinessQuery) async throws -> [Business] {
        let dtos = try await client.send(BusinessEndpoints.search(query: query))
        // The backend search only honours `q` and a single `category`, so apply
        // the remaining selected filters (extra categories, districts, funding
        // routes) client-side — otherwise those chips would change the UI badge
        // but not the results.
        return dtos.map { $0.toSummary() }.filter { query.matches($0) }
    }

    func detail(id: String) async throws -> BusinessDetail {
        let dto = try await client.send(BusinessEndpoints.detail(id: id))
        return dto.toDetail()
    }

    func myBusinesses() async throws -> [Business] {
        let dtos = try await client.send(BusinessEndpoints.mine())
        return dtos.map { $0.toSummary() }
    }

    func updateBusiness(id: String, description: String) async throws -> BusinessDetail {
        let dto = try await client.send(try BusinessEndpoints.update(id: id, description: description))
        return dto.toDetail()
    }

    func addMemory(businessId: String, author: String, text: String) async throws -> CommunityMemory {
        // The author is set server-side from the session token; `author` is
        // ignored here. The endpoint returns the full updated business, so we
        // pull the matching new memory back out (falling back to a local model
        // if the server shape ever changes).
        let dto = try await client.send(try BusinessEndpoints.addMemory(id: businessId, body: text))
        if let created = dto.memories?.last(where: { $0.body == text }) ?? dto.memories?.last {
            return created.toDomain()
        }
        return CommunityMemory(id: UUID().uuidString, author: author, text: text)
    }

    func askQuestion(businessId: String, question: String) async throws {
        _ = try await client.send(try BusinessEndpoints.askQuestion(id: businessId, question: question))
    }

    func uploadPhoto(_ jpeg: Data) async throws -> String {
        try await imageUploader.upload(jpeg)
    }
}

// MARK: - Mock

/// ⚠️ MOCK — in-memory business data (see `SampleData`). No backend.
/// Used as the active repo in mock mode, and as the sample-data source for
/// `FallbackBusinessRepository` when live discovery reads fail.
final class MockBusinessRepository: BusinessRepository, @unchecked Sendable {
    init() {}

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
        return SampleData.summaries.filter { query.matches($0) }
    }

    func detail(id: String) async throws -> BusinessDetail {
        MockMarker.hit(.mock, "MockBusinessRepository.detail")
        guard let detail = SampleData.detail(for: id) else { throw APIError.notFound }
        return detail
    }

    func myBusinesses() async throws -> [Business] {
        MockMarker.hit(.mock, "MockBusinessRepository.myBusinesses", "empty mock list")
        return []
    }

    func updateBusiness(id: String, description: String) async throws -> BusinessDetail {
        MockMarker.hit(.mock, "MockBusinessRepository.updateBusiness")
        guard var detail = SampleData.detail(for: id) else { throw APIError.notFound }
        detail.summary.storyHeadline = description
        detail.tagline = description
        return detail
    }

    func addMemory(businessId: String, author: String, text: String) async throws -> CommunityMemory {
        MockMarker.hit(.mock, "MockBusinessRepository.addMemory")
        return CommunityMemory(id: UUID().uuidString, author: author, text: text)
    }

    func askQuestion(businessId: String, question: String) async throws {
        MockMarker.hit(.mock, "MockBusinessRepository.askQuestion")
    }

    func uploadPhoto(_ jpeg: Data) async throws -> String {
        MockMarker.hit(.mock, "MockBusinessRepository.uploadPhoto")
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }

    private func score(_ business: Business, _ profile: UserProfile) -> Int {
        var score = 0
        if profile.interests.contains(business.category) { score += 2 }
        if profile.districts.contains(business.district) { score += 1 }
        return score
    }
}
