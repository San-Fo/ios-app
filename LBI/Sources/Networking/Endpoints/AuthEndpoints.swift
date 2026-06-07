import Foundation

/// API endpoints for authentication.
///
/// Backend contract:
/// - `POST /auth/apple` → `{ sessionToken, user }` (no auth)
/// - `POST /auth/logout` → `{ ok: true }` (auth)
/// The current user is fetched via `GET /me` (see `ProfileEndpoints`).
enum AuthEndpoints {
    /// Exchanges an Apple identity token for a backend session.
    static func signInWithApple(_ body: AppleSignInRequest) throws -> Endpoint<AuthSessionResponse> {
        try .json(
            path: "auth/apple",
            method: .post,
            body: body,
            requiresAuth: false
        )
    }

    /// Dev-only login (backend must run with `DEV_AUTH=1`). Returns the same
    /// `{ sessionToken, user }` as `/auth/apple`, with optional status overrides.
    static func signInDev(_ body: DevSignInRequest) throws -> Endpoint<AuthSessionResponse> {
        try .json(path: "auth/dev", method: .post, body: body, requiresAuth: false)
    }

    /// Ends the current session server-side.
    static func logout() -> Endpoint<EmptyResponse> {
        Endpoint(path: "auth/logout", method: .post)
    }
}
