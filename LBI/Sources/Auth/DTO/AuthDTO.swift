import Foundation

/// Payload sent to `POST /auth/apple`. The backend only requires the Apple
/// identity token; it verifies the token and creates the user on first login.
struct AppleSignInRequest: Encodable {
    let identityToken: String
}

/// Response from `POST /auth/apple`: an opaque session token (UUID, valid 30
/// days) plus the authenticated user.
struct AuthSessionResponse: Decodable {
    let sessionToken: String
    let user: UserProfileDTO
}
