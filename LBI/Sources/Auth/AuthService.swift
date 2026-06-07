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
    /// Dev-only sign in (`POST /auth/dev`, backend must run with `DEV_AUTH=1`).
    /// Lets us obtain a session — optionally with a forced investor status —
    /// without a real Apple token, for testing against the live server.
    func signInDev(subject: String?, investorStatus: String?, name: String?) async throws -> AuthenticatedUser
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

    func signInDev(subject: String?, investorStatus: String?, name: String?) async throws -> AuthenticatedUser {
        let request = DevSignInRequest(
            subject: subject,
            investorStatus: investorStatus,
            verificationState: nil,
            name: name
        )
        let response = try await client.send(try AuthEndpoints.signInDev(request))
        tokenStore.save(token: response.sessionToken)
        return AuthenticatedUser(
            id: response.user.id,
            displayName: response.user.displayName ?? name,
            email: response.user.email
        )
    }

    func restoreSession() async throws -> AuthenticatedUser? {
        guard tokenStore.currentToken() != nil else { return nil }
        do {
            // `GET /me` returns the full user profile DTO.
            let dto = try await client.send(ProfileEndpoints.me())
            return AuthenticatedUser(id: dto.id, displayName: dto.displayName, email: dto.email)
        } catch let error as APIError {
            // A stale/invalid token (rejected, forbidden, or a response we can no
            // longer decode, e.g. after a backend change) must not strand the
            // user in a signed-in-but-broken state: clear it and fall back to the
            // sign-in screen. Transport/offline errors are NOT the token's fault,
            // so keep it and let the caller treat launch as signed-out for now.
            switch error {
            case .unauthorized, .forbidden, .decoding, .server, .notFound:
                tokenStore.clear()
                return nil
            case .transport, .invalidRequest, .unknown:
                throw error
            }
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

    func signInDev(subject: String?, investorStatus: String?, name: String?) async throws -> AuthenticatedUser {
        MockMarker.hit(.mock, "MockAuthService.signInDev", "stub dev session")
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
