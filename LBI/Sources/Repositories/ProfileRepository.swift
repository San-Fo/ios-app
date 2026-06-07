import Foundation

/// Manages the signed-in user's profile and preferences.
protocol ProfileRepository: Sendable {
    func loadProfile(user: AuthenticatedUser) async throws -> UserProfile
    func save(_ profile: UserProfile) async throws
    func setSaved(businessId: String, saved: Bool) async throws
}

// MARK: - Live (placeholder)

final class LiveProfileRepository: ProfileRepository, @unchecked Sendable {
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    func loadProfile(user: AuthenticatedUser) async throws -> UserProfile {
        let dto = try await client.send(ProfileEndpoints.me())
        return dto.toDomain(fallback: user)
    }

    func save(_ profile: UserProfile) async throws {
        // Scalar fields go via PATCH /me; followed categories and financial
        // intents have dedicated replace endpoints on the backend.
        let patch = UserPatchDTO(
            name: profile.displayName,
            language: profile.language.serverValue,
            districts: profile.districts.map(\.rawValue),
            hasCompletedOnboarding: profile.hasCompletedOnboarding
        )
        _ = try await client.send(try ProfileEndpoints.patch(patch))
        _ = try await client.send(try ProfileEndpoints.setCategories(profile.interests.map(\.serverValue)))
        _ = try await client.send(try ProfileEndpoints.setFinancialIntents(profile.intents.compactMap(\.serverIntent)))
    }

    func setSaved(businessId: String, saved: Bool) async throws {
        if saved {
            try await client.send(ProfileEndpoints.save(businessId: businessId))
        } else {
            try await client.send(ProfileEndpoints.unsave(businessId: businessId))
        }
    }
}

// MARK: - Mock

/// In-memory mock that persists changes for the lifetime of the app session.
final class MockProfileRepository: ProfileRepository, @unchecked Sendable {
    private let mutex = Mutex()
    private var stored: UserProfile?

    func loadProfile(user: AuthenticatedUser) async throws -> UserProfile {
        mutex.withLock {
            if let stored { return stored }
            let profile = UserProfile.empty(
                id: user.id,
                displayName: user.displayName ?? "Friend",
                email: user.email
            )
            stored = profile
            return profile
        }
    }

    func save(_ profile: UserProfile) async throws {
        mutex.withLock { stored = profile }
    }

    func setSaved(businessId: String, saved: Bool) async throws {
        mutex.withLock {
            guard var profile = stored else { return }
            if saved { profile.savedBusinessIds.insert(businessId) }
            else { profile.savedBusinessIds.remove(businessId) }
            stored = profile
        }
    }
}
