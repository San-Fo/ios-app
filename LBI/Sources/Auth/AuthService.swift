import Foundation

/// The authenticated user in the domain layer.
struct AuthenticatedUser: Equatable, Identifiable {
    let id: String
    var displayName: String?
    var email: String?
}

/// Handles session lifecycle: sign in via Apple, restore, and sign out.
protocol AuthService: Sendable {
    /// Exchanges an Apple credential for a backend session and stores the token.
    func signInWithApple(_ credential: AppleCredential) async throws -> AuthenticatedUser
    /// Returns the current user if a stored token is still valid.
    func restoreSession() async throws -> AuthenticatedUser?
    /// Clears the session locally (and server-side when possible).
    func signOut() async
}

/// Live implementation backed by the API client + keychain token store.
final class LiveAuthService: AuthService, @unchecked Sendable {
    private let client: APIClient
    private let tokenStore: TokenStore

    init(client: APIClient, tokenStore: TokenStore) {
        self.client = client
        self.tokenStore = tokenStore
    }

    func signInWithApple(_ credential: AppleCredential) async throws -> AuthenticatedUser {
        // The backend only needs the Apple identity token; it verifies it and
        // returns an opaque session token plus the user.
        let request = AppleSignInRequest(identityToken: credential.identityToken)
        let endpoint = try AuthEndpoints.signInWithApple(request)
        let response = try await client.send(endpoint)
        tokenStore.save(token: response.sessionToken)
        return AuthenticatedUser(
            id: response.user.id,
            displayName: response.user.displayName ?? credential.fullName,
            email: response.user.email ?? credential.email
        )
    }

    func restoreSession() async throws -> AuthenticatedUser? {
        guard tokenStore.currentToken() != nil else { return nil }
        do {
            // `GET /me` returns the full user profile DTO.
            let dto = try await client.send(ProfileEndpoints.me())
            return AuthenticatedUser(id: dto.id, displayName: dto.displayName, email: dto.email)
        } catch APIError.unauthorized {
            tokenStore.clear()
            return nil
        }
    }

    func signOut() async {
        _ = try? await client.send(AuthEndpoints.logout())
        tokenStore.clear()
    }
}

/// ⚠️ MOCK — no network, no Apple verification. Returns a stubbed user.
/// Active only when `APIConfiguration.useMockData == true`.
final class MockAuthService: AuthService, @unchecked Sendable {
    private let tokenStore: TokenStore
    var stubbedUser: AuthenticatedUser

    init(
        tokenStore: TokenStore = InMemoryTokenStore(),
        stubbedUser: AuthenticatedUser = AuthenticatedUser(id: "mock-user", displayName: "Ah Ming", email: "ming@example.hk")
    ) {
        self.tokenStore = tokenStore
        self.stubbedUser = stubbedUser
    }

    func signInWithApple(_ credential: AppleCredential) async throws -> AuthenticatedUser {
        MockMarker.hit(.mock, "MockAuthService.signInWithApple", "no Apple verification; stub token + user")
        tokenStore.save(token: "mock-token")
        return stubbedUser
    }

    func restoreSession() async throws -> AuthenticatedUser? {
        MockMarker.hit(.mock, "MockAuthService.restoreSession")
        return tokenStore.currentToken() != nil ? stubbedUser : nil
    }

    func signOut() async {
        tokenStore.clear()
    }
}
